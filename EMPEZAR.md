# Actualizar y probar en tu Mac

1. Descargá de nuevo la rama `codex/jacobofit-mvp` desde GitHub: Code → Download ZIP.
2. Descomprimí en una carpeta nueva. Cerrá el proyecto anterior en Xcode y abrí **JacoboFit.xcodeproj** de la carpeta nueva.
3. Elegí un simulador iPhone y presioná **⌘R**.

## Diseño de vidrio

Con Xcode 16.4 funciona la alternativa de materiales translúcidos. El efecto **Liquid Glass nativo de Apple** se activa al compilar con **Xcode 26 o posterior** y ejecutar en **iOS 26 o posterior**. Instalar solo iOS 26 en un teléfono no habilita la API al compilar con Xcode 16.4. Los ajustes de contraste y reducción de transparencia de Accesibilidad se respetan.

## Comida y lista del súper

En **Comida → Agregar a mis comidas**, escribí el nombre de cada plato y sus ingredientes con cantidades **totales** para las porciones indicadas. Se crea automáticamente un borrador en Recetas. También podés añadir una receta existente a tu lista desde su detalle.

Tocá **Lista del súper** para abrir el checklist consolidado por ingrediente/unidad. Las marcas se guardan; si cambia la cantidad de un producto de esta lista vuelve a quedar pendiente. Quitar un plato de la lista conserva su receta.

Los borradores no muestran cero calorías como si fueran datos reales y no permiten registrar una comida hasta completar preparación y estimaciones.

## Calendario

Elegí Mes o Semana. Tocá una casilla para ver sus comidas y entrenamiento debajo de la cuadrícula. Los puntos verdes indican comidas y los naranjas entrenamiento. La lista del súper corresponde a la semana del día seleccionado.

## Recetas con tu cliente de ChatGPT

1. En **Recetas**, el pedido se prepara automáticamente con tu lista de Comida. También podés escribir otro pedido, como “voy a comer pollo cocido”. Elegí porciones y tiempo.
2. Tocá **Copiar pedido y abrir ChatGPT**. Se copia un pedido completo al portapapeles y se abre chatgpt.com, que puede abrir tu cliente instalado si el sistema lo permite. Si se abre el navegador, iniciá sesión con tu cuenta habitual. JacoboFit no inicia sesión por vos.
3. **Pegá y enviá el pedido en ChatGPT**. La app no lo envía automáticamente. El pedido explica el formato JSON que necesitamos y que debe respetar que el pollo ya está cocido.
4. Copiá la respuesta usando el botón de copiar del bloque de código de ChatGPT.
5. Volvé a JacoboFit y pegala en **Pegá tu receta**. Si el chat está en tu Mac y la app en el simulador, usá Edit → Paste en el simulador o el pegado de texto del sistema. El portapapeles del Mac y del simulador debe estar compartido (Simulator → Edit → Automatically Sync Pasteboard, si aparece).
6. Tocá **Revisar recetas**. Revisá ingredientes, pasos y estimaciones nutricionales; guardá, planificá o registrá la propuesta.

No necesitás una API key, Node.js ni servidor. Usás tu cuenta de ChatGPT y los límites de tu plan. El intercambio es manual: JacoboFit no lee tu cuenta ni llama a una API para generar. Si el formato no coincide, se muestra un error y podés corregir el pedido o copiar de nuevo el JSON completo. No se importan valores negativos, cantidades cero ni recetas sin ingredientes/pasos.

El análisis por foto continúa en modo demo. Tus recetas guardadas y el calendario siguen funcionando sin ChatGPT.

## Fuentes de internet

El pedido solicita a ChatGPT consultar fuentes reales cuando su cliente tenga búsqueda habilitada, y devolver sus enlaces. Si no puede consultarlas, debe dejar `sources` vacío. JacoboFit conserva esos enlaces y ofrece búsquedas preparadas en MyPlate y NHS a partir de tus ingredientes. **No realiza por sí misma una búsqueda ni verifica que una receta sea saludable**. Los borradores locales se crean automáticamente; completar recetas y obtener recomendaciones con IA requiere el intercambio manual elegido.
