# Validación de esta entrega

Ejecutada en el entorno Linux de desarrollo. Esta entrega no está publicada ni enviada a GitHub.

| Comprobación | Resultado |
| --- | --- |
| Compilación del paquete NutritionCore con Swift 6.0.3 | Pasó |
| XCTest del núcleo y datos demo | 16 ejecutadas, 16 pasaron, 0 fallaron |
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
| OpenAI y backend real | Fase 2, no implementados ni validados |

La comprobación de sintaxis no verifica tipos de SwiftUI/SwiftData/HealthKit ni sustituye la compilación con Xcode. El parser del proyecto valida su estructura, no que Xcode pueda construirlo. No se afirma que las comprobaciones pendientes hayan pasado.

Para completar la validación en tu Mac:

```bash
bash scripts/test-ios.sh
```

Para la revisión manual: abrir el proyecto, seleccionar un simulador iPhone y ejecutar ⌘R; recorrer Registro → análisis demo → editar → guardar → Hoy. Cargar recetas de ejemplo, planificar una receta para dos porciones y comprobar cantidades en la lista del súper. Cerrar/abrir y verificar persistencia. Probar cámara y HealthKit por separado con permisos concedidos, denegados y datos ausentes.

La línea final del runner de Swift Testing que indica cero pruebas pertenece a ese runner alternativo. Las **16 pruebas XCTest sí se ejecutaron**, como informa su suite `All tests`.
