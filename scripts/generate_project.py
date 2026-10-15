#!/usr/bin/env python3
"""Generate a dependency-free Xcode project using native targets and the local Swift package."""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'JacoboFit.xcodeproj'
objects = {}

def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def add(object_key, **fields):
    key = uid(object_key)
    objects[key] = fields
    return key

def serialize(value, level=0):
    indent = '\t' * level
    if isinstance(value, dict):
        return '{\n' + ''.join(indent + '\t' + json.dumps(str(k)) + ' = ' + serialize(v, level + 1) + ';\n' for k, v in value.items()) + indent + '}'
    if isinstance(value, list):
        return '(\n' + ''.join(indent + '\t' + serialize(v, level + 1) + ',\n' for v in value) + indent + ')'
    if isinstance(value, int):
        return str(value)
    return json.dumps(str(value), ensure_ascii=False)

project_id = uid('project')
package = add('package', isa='XCLocalSwiftPackageReference', relativePath='.')
product = add('package-product', isa='XCSwiftPackageProductDependency', package=package, productName='NutritionCore')
products = []
groups = []
targets = []
target_attributes = {}

project_settings = {
    'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES',
    'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'SDKROOT': 'iphoneos',
    'SWIFT_VERSION': '5.0', 'SWIFT_STRICT_CONCURRENCY': 'targeted',
    'ENABLE_USER_SCRIPT_SANDBOXING': 'YES', 'TARGETED_DEVICE_FAMILY': '1',
    'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
}

def config_list(name, settings):
    configs = []
    for mode in ['Debug', 'Release']:
        current = dict(settings)
        current['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if mode == 'Debug' else '-O'
        current['DEBUG_INFORMATION_FORMAT'] = 'dwarf' if mode == 'Debug' else 'dwarf-with-dsym'
        if mode == 'Debug':
            current['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
            current['ENABLE_TESTABILITY'] = 'YES'
            current['ONLY_ACTIVE_ARCH'] = 'YES'
        configs.append(add(name + '-config-' + mode, isa='XCBuildConfiguration', buildSettings=current, name=mode))
    return add(name + '-configs', isa='XCConfigurationList', buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName='Release')

for name, directory, kind, ext in [
    ('JacoboFit', 'JacoboFit', 'application', 'app'),
    ('JacoboFitTests', 'JacoboFitTests', 'bundle.unit-test', 'xctest'),
    ('JacoboFitUITests', 'JacoboFitUITests', 'bundle.ui-testing', 'xctest'),
]:
    file_refs, sources, resources = [], [], []
    for path in sorted((ROOT / directory).rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT).as_posix()
        filetype = {'.swift': 'sourcecode.swift', '.plist': 'text.plist.xml', '.entitlements': 'text.plist.entitlements',
                    '.json': 'text.json', '.xcprivacy': 'text.xml'}.get(path.suffix, 'text')
        ref = add('file-' + relative, isa='PBXFileReference', lastKnownFileType=filetype,
                  name=path.name, path=relative, sourceTree='SOURCE_ROOT')
        file_refs.append(ref)
        if path.suffix == '.swift':
            sources.append(add('build-' + relative, isa='PBXBuildFile', fileRef=ref))
        elif path.parent.name == 'Resources':
            resources.append(add('build-' + relative, isa='PBXBuildFile', fileRef=ref))
    groups.append(add('group-' + name, isa='PBXGroup', name=name, children=file_refs, sourceTree='<group>'))
    product_ref = add('product-' + name, isa='PBXFileReference', explicitFileType='wrapper.application' if ext == 'app' else 'wrapper.cfbundle',
                      includeInIndex=0, path=name + '.' + ext, sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product_ref)
    phases = [add(name + '-sources', isa='PBXSourcesBuildPhase', buildActionMask=2147483647, files=sources, runOnlyForDeploymentPostprocessing=0)]
    frameworks = []
    if name != 'JacoboFitUITests':
        frameworks.append(add(name + '-core-link', isa='PBXBuildFile', productRef=product))
    phases.append(add(name + '-frameworks', isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=frameworks, runOnlyForDeploymentPostprocessing=0))
    phases.append(add(name + '-resources', isa='PBXResourcesBuildPhase', buildActionMask=2147483647, files=resources, runOnlyForDeploymentPostprocessing=0))
    settings = {'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.jacoboroizd.' + name,
                'CODE_SIGN_STYLE': 'Automatic', 'GENERATE_INFOPLIST_FILE': 'YES', 'SWIFT_EMIT_LOC_STRINGS': 'YES'}
    dependencies = []
    attrs = {'CreatedOnToolsVersion': '16.4'}
    if name == 'JacoboFit':
        settings.update({'GENERATE_INFOPLIST_FILE': 'NO', 'INFOPLIST_FILE': 'JacoboFit/Info.plist',
                         'CODE_SIGN_ENTITLEMENTS': 'JacoboFit/JacoboFit.entitlements', 'ENABLE_PREVIEWS': 'YES',
                         'MARKETING_VERSION': '1.0.0', 'CURRENT_PROJECT_VERSION': '1',
                         'SUPPORTS_MACCATALYST': 'NO', 'SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD': 'NO',
                         'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks'})
        attrs['SystemCapabilities'] = {'com.apple.HealthKit': {'enabled': 1}}
    else:
        proxy = add(name + '-proxy', isa='PBXContainerItemProxy', containerPortal=project_id,
                    proxyType=1, remoteGlobalIDString=uid('target-JacoboFit'), remoteInfo='JacoboFit')
        dependencies = [add(name + '-dependency', isa='PBXTargetDependency', target=uid('target-JacoboFit'), targetProxy=proxy)]
        attrs['TestTargetID'] = uid('target-JacoboFit')
        if name == 'JacoboFitTests':
            settings.update({'BUNDLE_LOADER': '$(TEST_HOST)', 'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/JacoboFit.app/JacoboFit',
                             'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
        else:
            settings['TEST_TARGET_NAME'] = 'JacoboFit'
    target = add('target-' + name, isa='PBXNativeTarget', buildConfigurationList=config_list(name, settings),
                 buildPhases=phases, buildRules=[], dependencies=dependencies, name=name,
                 packageProductDependencies=[product] if name != 'JacoboFitUITests' else [], productName=name,
                 productReference=product_ref, productType='com.apple.product-type.' + kind)
    targets.append(target)
    target_attributes[target] = attrs

products_group = add('group-products', isa='PBXGroup', children=products, name='Products', sourceTree='<group>')
main_group = add('group-main', isa='PBXGroup', children=groups + [products_group], sourceTree='<group>')
add('project', isa='PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '1640', 'TargetAttributes': target_attributes},
    buildConfigurationList=config_list('project', project_settings), compatibilityVersion='Xcode 14.0', developmentRegion='es',
    hasScannedForEncodings=0, knownRegions=['es', 'en', 'Base'], mainGroup=main_group,
    productRefGroup=products_group, projectDirPath='', projectRoot='', packageReferences=[package], targets=targets)
OUT.mkdir(exist_ok=True)
(OUT / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + serialize({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56, 'objects': objects, 'rootObject': project_id}) + '\n')
workspace = OUT / 'project.xcworkspace'
workspace.mkdir(exist_ok=True)
(workspace / 'contents.xcworkspacedata').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0"><FileRef location="self:"/></Workspace>\n')

scheme = ET.Element('Scheme', LastUpgradeVersion='1640', version='1.3')
def build_ref(parent, name, ext):
    ET.SubElement(parent, 'BuildableReference', BuildableIdentifier='primary', BlueprintIdentifier=uid('target-' + name),
                  BuildableName=name + '.' + ext, BlueprintName=name, ReferencedContainer='container:JacoboFit.xcodeproj')
build = ET.SubElement(scheme, 'BuildAction', parallelizeBuildables='YES', buildImplicitDependencies='YES')
entries = ET.SubElement(build, 'BuildActionEntries')
entry = ET.SubElement(entries, 'BuildActionEntry', buildForTesting='YES', buildForRunning='YES', buildForProfiling='YES', buildForArchiving='YES', buildForAnalyzing='YES')
build_ref(entry, 'JacoboFit', 'app')
test = ET.SubElement(scheme, 'TestAction', buildConfiguration='Debug', selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',
                     selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB', shouldUseLaunchSchemeArgsEnv='YES')
testables = ET.SubElement(test, 'Testables')
for name in ['JacoboFitTests', 'JacoboFitUITests']:
    testable = ET.SubElement(testables, 'TestableReference', skipped='NO')
    build_ref(testable, name, 'xctest')
launch = ET.SubElement(scheme, 'LaunchAction', buildConfiguration='Debug', selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',
                       selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB', launchStyle='0', useCustomWorkingDirectory='NO', ignoresPersistentStateOnLaunch='NO', debugDocumentVersioning='YES', debugServiceExtension='internal', allowLocationSimulation='YES')
runnable = ET.SubElement(launch, 'BuildableProductRunnable', runnableDebuggingMode='0')
build_ref(runnable, 'JacoboFit', 'app')
profile = ET.SubElement(scheme, 'ProfileAction', buildConfiguration='Release', shouldUseLaunchSchemeArgsEnv='YES', savedToolIdentifier='', useCustomWorkingDirectory='NO', debugDocumentVersioning='YES')
build_ref(ET.SubElement(profile, 'BuildableProductRunnable', runnableDebuggingMode='0'), 'JacoboFit', 'app')
ET.SubElement(scheme, 'AnalyzeAction', buildConfiguration='Debug')
ET.SubElement(scheme, 'ArchiveAction', buildConfiguration='Release', revealArchiveInOrganizer='YES')
schemes = OUT / 'xcshareddata' / 'xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
ET.indent(scheme)
(schemes / 'JacoboFit.xcscheme').write_bytes(ET.tostring(scheme, encoding='utf-8', xml_declaration=True))
print('Proyecto generado:', OUT)
