# JacoboFit · MVP nativo para iPhone

Copiloto nutricional en SwiftUI, SwiftData y Swift Charts. iOS 17+, Xcode 16.4, Swift 6 para el paquete de cálculos. El registro local/demo funciona sin servidor, sin API key y sin autorizar Apple Health. Las recetas con IA usan un intercambio manual con tu cliente de ChatGPT: preparar pedido, copiar y abrir ChatGPT, pegar la respuesta y revisar.

**Novedades y pasos para actualizar:** [EMPEZAR.md](EMPEZAR.md).

## Abrirlo en tu Mac

1. Descomprimí `JacoboFit-MVP.zip` y entrá en la carpeta `JacoboFit`.
2. Hacé doble clic en **JacoboFit.xcodeproj**. En la pantalla inicial de Xcode también podés elegir **Open Existing Project** y seleccionar ese archivo.
3. En la barra superior elegí el esquema **JacoboFit** y un **iPhone Simulator** (por ejemplo, iPhone 16 con iOS 18.5). No elijas “Any iOS Device”.
4. Presioná **⌘R**. Si falta el simulador, descargá iOS en **Xcode → Settings → Components**.

Para el modo local no hace falta Homebrew, XcodeGen, CocoaPods ni una cuenta de OpenAI. Para recetas podés usar tu cliente y suscripción de ChatGPT sin configurar un backend ni claves de API en JacoboFit. El paquete `NutritionCore` es local; no descarga dependencias externas. Conservá la carpeta completa: abrir solo un archivo Swift o `Package.swift` no ejecuta la app iOS.

Para probar en tu iPhone físico: conectalo, activá Developer Mode cuando iOS lo solicite, agregá tu Apple ID en Xcode → Settings → Accounts y seleccioná tu equipo en **Signing & Capabilities**. Usá un bundle identifier propio si Apple rechaza el predeterminado. La capacidad HealthKit requiere que tu equipo de firma la admita; el simulador permite desarrollar el modo demo sin configurar una cuenta de pago.

## Primera prueba

- En **Comida → Registrar comida con foto**, elegí una foto o tocá **Analizar comida** para usar el ejemplo sin foto.
- El demo devuelve siempre una muestra de tacos, **no analiza la imagen**. Está indicado en la pantalla y en el análisis.
- Tocá una tortilla y cambiá la cantidad; agregá aceite o manteca si corresponde. Se recalculan calorías, macros y rango.
- Guardá. La comida aparece en **Hoy** y en el historial del registro de **Comida**.
- En **Recetas**, cargá los nueve ejemplos editables. Abrí una receta y elegí **Agregar al calendario**.
- En **Calendario**, elegí tu entrenamiento y generá la lista del súper. Marcá los productos comprados.
- Cerrá y abrí la app: los registros se conservan localmente.

En el simulador no hay cámara física: usá **Elegir**. Podés arrastrar una imagen al simulador para agregarla a Fotos. PhotosPicker no solicita acceso completo a la biblioteca. La cámara pide permiso solo al usarla.

## Implementado

- Lista editable de platos en Comida, con ingredientes, cantidades y porciones; borradores automáticos en Recetas.
- Checklist del súper desde la lista de Comida, separado del checklist semanal del calendario.
- Fuentes citadas en recetas importadas y búsquedas por ingredientes en MyPlate/NHS. Los enlaces se conservan sin afirmar que estén verificados.
- Cuatro tabs: Hoy, Comida, Calendario y Recetas.
- Registro por cámara, biblioteca o descripción, análisis mock asíncrono y registro manual.
- Revisión de nombre, categoría, fecha, cantidades, marcas, preparación y nutrición por unidad; altas/bajas de componentes y grasas rápidas con porciones.
- Fotos locales redimensionadas, análisis original y correcciones guardados por separado con SwiftData.
- Historial agrupado por fecha, totales diarios y detalle.
- Dashboard con calorías, progreso de proteína, macros, balance estimado, agua y peso.
- HealthKit opcional: energía activa/en reposo, pasos, distancia, ejercicio, entrenamientos y último peso. No escribe en Health.
- Recetas editables, favoritas, escalado de ingredientes y macros, registro y planificación.
- Calendario mensual/semanal en cuadrícula, marcas de comidas y entrenamientos, detalle del día y copias de recetas planificadas.
- Materiales translúcidos accesibles con Xcode 16.4; Liquid Glass nativo y botones glass al compilar con Xcode 26 y ejecutar en iOS 26.
- Recetas desde un pedido libre, porciones y tiempo: la app prepara un pedido para tu cliente de ChatGPT e importa su respuesta JSON pegada manualmente. No accede a tu cuenta ni consume una API.
- Lista del súper que consolida ingredientes por nombre, categoría y unidad, ajustada a porciones; compras persistentes por semana.
- Productos frecuentes reutilizables al editar un alimento.
- Tendencias de comidas, proteína y pesos de 7/30/90 días. Los días sin datos no se cuentan como cero.
- Eliminación de comida, foto, registros de un día o todos los datos locales.
- Componentes con colores semánticos para light/dark mode y etiquetas de accesibilidad.

Los números de ejemplos y grasas rápidas son orientativos y editables, no datos de marcas verificados. Las tarjetas sin foto usan símbolos, no fotos de comidas inventadas.

## Cómo calculamos el balance

`balance = consumido − (energía en reposo + energía activa)`.

Un resultado negativo significa déficit estimado. La energía activa de Health ya incluye entrenamientos: no volvemos a sumarlos. Si la energía activa no está disponible, se usa la energía de entrenamientos como respaldo, sin asumir que representa todo el movimiento diario. Sin una base en reposo disponible o introducida por el usuario, no inventamos un gasto ni un déficit.

Las muestras en reposo de Health representan **hoy hasta ahora**: no son una predicción del día completo. Si se usa una base manual diaria se indica que el cálculo usa solo los datos de actividad disponibles. La ausencia de muestras de Health no demuestra permiso denegado: Apple mantiene privados los permisos de lectura.

## Pruebas

En Mac, para ejecutar cálculos, persistencia y prueba UI:

```bash
cd /ruta/a/JacoboFit
bash scripts/test-ios.sh
```

El script usa un iPhone Simulator instalado y mantiene el código de salida de cada comando. También podés usar **⌘U** en Xcode para las pruebas iOS.

Solo el paquete de cálculos (Mac o Linux con Swift 6):

```bash
swift test --jobs 4
```

En Linux con Docker:

```bash
docker run --rm -v "$PWD:/project" -w /project swift:6.0.3 swift test --jobs 4
```

`JacoboFitTests` verifica persistencia, análisis original/corregido, borrado en cascada y supervivencia de la copia planificada al eliminar una receta. `JacoboFitUITests` recorre análisis demo, corrección de cantidad, guardado y dashboard. La prueba UI usa una base temporal en memoria, sin tocar tu historial normal.

**Estado de validación:** ver [VALIDATION.md](VALIDATION.md). La construcción se realizó en Linux; las pruebas iOS y la compilación completa con frameworks Apple requieren ejecutarse en Xcode y todavía no se han comprobado aquí. La configuración de CI para Mac está incluida y el código está en la rama `codex/jacobofit-mvp`; todavía no hay un resultado de CI confirmado.

## Estructura

- `JacoboFit/App`: entrada, almacenamiento y navegación.
- `JacoboFit/Core`: modelos SwiftData y componentes visuales.
- `JacoboFit/Features`: dashboard, registro, recetas, calendario, compras, ajustes y privacidad.
- `JacoboFit/Services`: cámara/fotos, HealthKit y carga de ejemplos.
- `Sources/NutritionCore`: cálculos puros, validación, modelos de intercambio y protocolo de IA.
- `Tests/NutritionCoreTests`: pruebas independientes de Apple.
- `JacoboFitTests`, `JacoboFitUITests`: pruebas para Xcode.
- `JacoboFit/Resources/DemoRecipes.json`: datos iniciales editables; se cargan solo por decisión del usuario. IDs estables evitan duplicados al volver a cargar ejemplos.
- `Backend/AIProxy`: contrato de referencia para una posible fase futura. No se usa para el intercambio manual con ChatGPT.

El proyecto Xcode ya viene generado y versionable. Para regenerarlo después de agregar archivos, ejecutá `python3 scripts/generate_project.py` o agregalos manualmente desde Xcode. El generador reemplaza el proyecto completo: guardá antes cualquier ajuste manual de firma o build.

## Fase 2 pendiente

- Alojamiento HTTPS y autenticación multiusuario para producción; cuotas persistentes y política de retención antes de habilitar envíos de imágenes.
- Escaneo de etiquetas, correcciones conversacionales, reconocimiento de comidas frecuentes y generación de semanas con IA.
- Historial de actividad/balance y frecuencia cardiaca de entrenamientos si el usuario elige compartirla.
- Widgets, App Intents, Apple Watch y Live Activities.
- Revisión visual en simulador/dispositivo, icono definitivo, pruebas de VoiceOver y preparación de App Store.

`ChatGPTRecipeExchange` prepara el pedido y valida la receta JSON pegada desde tu cliente ChatGPT. El intercambio es manual y el usuario controla su cuenta. El análisis de fotos conserva su mock. `RemoteAIService` se mantiene solo como base para otra posible integración: no se activa y no hay backend desplegado. No se guardan claves privadas de OpenAI en el cliente.
