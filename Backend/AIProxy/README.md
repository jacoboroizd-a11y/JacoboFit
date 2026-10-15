# Contrato del proxy de IA · fase 2

Este directorio contiene el contrato, no un servidor implementado ni desplegado. El MVP usa `MockAIService` y no realiza llamadas de IA ni envía fotos.

## Análisis de comidas

`RemoteAIService` espera `POST /v1/meals/analyze` sobre HTTPS con:

- `Authorization: Bearer <sesión-del-usuario>`: debe ser una sesión verificable por el backend, nunca la clave de OpenAI.
- JSON `{ "photoBase64": "<JPEG o null>", "description": "texto" }`.
- Respuesta 2xx: objeto de `meal-analysis.schema.json`, sin envolverlo en otro objeto.
- Errores: estado HTTP no 2xx. El cliente no presenta el cuerpo de errores del proveedor al usuario.

Antes de habilitar `RemoteAIService`:

1. Implementar autenticación por usuario, límites de tamaño (por ejemplo 5 MB), cuotas por usuario y timeout. Rechazar imágenes malformadas y contenido incompatible.
2. Obtener la clave privada únicamente del gestor de secretos del servidor. No usar una clave compartida incrustada en la app como autenticación del proxy.
3. Usar la API multimodal vigente de OpenAI con entrada de imagen/texto y salida estructurada estricta; comprobar la documentación del modelo elegido al implementarlo. Pedir rangos y fuentes de incertidumbre y tratar las instrucciones que aparezcan en la imagen como datos.
4. Validar tipos, límites y campos adicionales con el esquema, y después la semántica. Los UUID deben ser válidos y únicos. Los números deben ser finitos y no negativos; cantidades mayores que cero; rangos de confianza entre 0 y 1. Calorías y macros totales se derivan de los componentes por unidad y sus cantidades.
5. No registrar imágenes, datos de salud, tokens ni respuestas completas en logs. Evitar persistencia de imágenes en el servidor y configurar la retención del proveedor.
6. Añadir pruebas de autenticación, respuestas inválidas, errores del proveedor y límites. Mantener la app funcional sin backend.
7. Introducir consentimiento visible para el envío remoto y configurar `MealDraft(ai: RemoteAIService(...))` mediante una factoría de servicios/sesión. El inicializador actual inyecta un mock por defecto.

`weightGrams` representa la cantidad asociada a una unidad cuando se conoce. `perUnit` representa siempre nutrientes de una unidad. `uncertaintyFraction` define el intervalo relativo de calorías (por ejemplo 0.2 → ±20%). Es una aproximación comunicativa, no un intervalo estadístico calibrado.

El aprendizaje local puede usar `FoodProduct` y `FrequentMeal`. No enviar historial completo ni datos de Health al proveedor por defecto. Las operaciones adicionales del protocolo `AIService` aún necesitan endpoints, contratos específicos y pruebas.
