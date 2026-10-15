#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! xcrun --find xcodebuild >/dev/null 2>&1; then
  echo 'Necesitás macOS con Xcode 16.4 y el componente iOS instalado.' >&2
  exit 1
fi
# Choose an installed iPhone rather than assuming a particular simulator model exists.
JACOBOFIT_SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
all_devices=json.load(sys.stdin)["devices"]
devices=[d for runtime,group in all_devices.items() if ".iOS-" in runtime for d in group if d.get("isAvailable") and d["name"].startswith("iPhone")]
devices.sort(key=lambda d: d.get("state") != "Booted")
if not devices:
    sys.exit("Instalá un simulador iOS en Xcode → Settings → Components.")
print(devices[0]["udid"])
')"
swift test --jobs 4
xcodebuild test -project JacoboFit.xcodeproj -scheme JacoboFit \
  -destination "platform=iOS Simulator,id=$JACOBOFIT_SIMULATOR_ID" \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
