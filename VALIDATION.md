# Validación de esta entrega

Ejecutada en el entorno Linux de desarrollo. El código se guardó en GitHub en la rama `codex/jacobofit-mvp`. No hay un resultado de CI confirmado ni una versión publicada en App Store.

| Comprobación | Resultado |
| --- | --- |
| Compilación del paquete NutritionCore con Swift 6.0.3 | Pasó |
| XCTest del núcleo y datos demo | 26 ejecutadas, 26 pasaron, 0 fallaron |
| Análisis de sintaxis de archivos Swift de app y pruebas iOS | Pasó con el frontend de Swift 6.0.3 |
| Lectura del proyecto Xcode con un parser OpenStep externo | Pasó |
| Integridad de referencias a objetos y rutas del proyecto | Pasó |
| Lectura de Info.plist, entitlements, privacy manifest y esquema compartido | Pasó |
| Sintaxis del script de pruebas y del generador de proyecto | Pasó |
| Compilación y ejecución de la app iOS con Xcode | Pendiente: no hay Xcode ni SDK de Apple en Linux |
| Pruebas SwiftData en JacoboFitTests | Escritas, no ejecutadas; requieren Xcode |
| Prueba UI en JacoboFitUITests | Escrita, no ejecutada; requiere simulador iOS |
| Cámara, permisos y consultas HealthKit en dispositivo | Pendientes de prueba en Mac/iPhone |
| Revisión visual y accesibilidad en simulador | Pendiente |
| Intercambio manual de recetas con ChatGPT | Pruebas de preparación e importación JSON incluidas en las 26 pruebas del núcleo |
| API / proxy de OpenAI | Fuera del alcance elegido: no se conecta ni se consume desde la app |
| Liquid Glass nativo (SDK/iOS 26) | Código protegido por versión de compilador y runtime; requiere Xcode 26 para compilar/validar |
| Material translúcido y nuevo calendario en simulador | Pendiente de revisión visual en Xcode |

La comprobación de sintaxis no verifica tipos de SwiftUI/SwiftData/HealthKit ni sustituye la compilación con Xcode. El parser del proyecto valida su estructura, no que Xcode pueda construirlo. No se afirma que las comprobaciones pendientes hayan pasado.

Para completar la validación en tu Mac:

```bash
bash scripts/test-ios.sh
```

Para la revisión manual: abrir el proyecto, seleccionar un simulador iPhone y ejecutar ⌘R; recorrer Comida → Registrar comida con foto → análisis demo → editar → guardar → Hoy. Cargar recetas de ejemplo, planificar una receta para dos porciones y comprobar cantidades en la lista del súper. Cerrar/abrir y verificar persistencia. Probar cámara y HealthKit por separado con permisos concedidos, denegados y datos ausentes.

La línea final del runner de Swift Testing que indica cero pruebas pertenece a ese runner alternativo. Las **26 pruebas XCTest sí se ejecutaron**, como informa su suite `All tests`.

Las pruebas de recetas/calendario de interfaz están escritas, pero aún no ejecutadas. El cambio al cliente de ChatGPT retiró la integración del proxy preparada durante el trabajo: no se incluye servidor, llavero ni excepción de HTTP local. El flujo completo de copiar, abrir ChatGPT y pegar su respuesta debe probarse en el Mac del usuario.

Las nuevas pruebas de SwiftData incluyen lista de Comida, marcas de borrador, porciones y enlaces. Su ejecución y la migración desde una instalación anterior deben validarse en Xcode. Las fuentes externas no se recuperaron: el entorno devolvió 403 a la prueba de una fuente pública, por lo que la entrega ofrece enlaces/búsquedas y conserva citas de ChatGPT sin afirmar verificación web.
