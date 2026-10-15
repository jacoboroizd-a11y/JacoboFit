import Foundation

/// User-mediated exchange with any ChatGPT client; no account access or API calls.
public enum ChatGPTRecipeExchange {
    public enum ExchangeError: Error, LocalizedError {
        case invalidRequest, invalidResponse
        public var errorDescription: String? {
            switch self {
            case .invalidRequest: "Escribí qué querés comer (3 a 2500 caracteres) y revisá las porciones y el tiempo."
            case .invalidResponse: "No pudimos leer la receta. Pegá el JSON completo que devolvió ChatGPT, sin comentarios antes ni después. Podés incluir el bloque ```json."
            }
        }
    }
    public static func makePrompt(idea: String, servings: Int, minutes: Int) throws -> String {
        let trimmed = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...2500).contains(trimmed.count), (1...12).contains(servings), (10...120).contains(minutes) else { throw ExchangeError.invalidRequest }
        let quoted = String(data: try JSONEncoder().encode(trimmed), encoding: .utf8) ?? ""
        return """
        Ayudame a preparar una buena receta para mi app JacoboFit.
        Mi pedido (texto entre comillas): \(quoted)
        Cocinar para \(servings) persona(s). Tengo \(minutes) minutos.

        Proponé de 1 a 3 recetas que encajen con ese pedido, primero la más adecuada. Si hay borradores con nombre, conservá esos nombres al completarlos. Si digo pollo cocido, usalo YA COCIDO, no pollo crudo. Respetá ingredientes, restricciones y tiempo que indiqué. Usá ingredientes accesibles y pasos concretos; tené en cuenta almacenamiento y recalentado seguro de sobras cuando corresponda.
        Si tu cliente permite buscar en internet, consultá fuentes como MyPlate (USDA), NHS o sitios de cocina con autor identificado. Priorizá verduras, legumbres y proteína, respetando lo que tengo. Adjuntá hasta 5 enlaces HTTPS reales por receta en sources. No inventes enlaces ni digas que verificaste una fuente si no pudiste abrirla; en ese caso sources debe ser [].
        Las calorías y macros son estimaciones, no valores médicos exactos. nutrition e ingredients deben corresponder a TODA la receta para sus servings porciones. No inventes valores verificados de marcas.

        Devolvé SOLO JSON válido con esta estructura, reemplazando los valores de ejemplo por tu receta real. No incluyas UUID ni texto fuera del JSON. Todos los campos son obligatorios. Los nombres de campos no se traducen. difficulty: Fácil, Media o Avanzada. category: proteínas, vegetales, carbohidratos u otros. Las cantidades deben ser mayores que cero; los nutrientes, finitos y no negativos. Máximo 3 recetas, 40 ingredientes y 20 pasos por receta.
        {
          "recipes": [{
            "name": "Nombre de tu receta",
            "servings": \(servings),
            "minutes": \(minutes),
            "difficulty": "Fácil",
            "nutrition": {"calories": 500, "protein": 40, "carbs": 30, "fat": 20},
            "ingredients": [{"name": "Ingrediente", "quantity": 100, "unit": "g", "category": "proteínas"}],
            "steps": ["Primer paso concreto.", "Segundo paso. Nutrición aproximada."],
            "sources": []
          }]
        }
        """
    }
    public static func importRecipes(_ text: String) throws -> [RecipeData] {
        guard text.utf8.count <= 200_000 else { throw ExchangeError.invalidResponse }
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```") {
            let lines = clean.components(separatedBy: .newlines)
            guard lines.count >= 3, ["```", "```json"].contains(lines[0].lowercased()), lines.last == "```" else { throw ExchangeError.invalidResponse }
            clean = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: Data(clean.utf8))
            guard (1...3).contains(envelope.recipes.count) else { throw ExchangeError.invalidResponse }
            return try envelope.recipes.map { value in
                guard (1...12).contains(value.servings), (1...240).contains(value.minutes),
                      ["Fácil", "Media", "Avanzada"].contains(value.difficulty),
                      value.ingredients.count <= 40, value.steps.count <= 20,
                      value.ingredients.allSatisfy({ ["proteínas", "vegetales", "carbohidratos", "otros"].contains($0.category) }),
                      [value.nutrition.calories, value.nutrition.protein, value.nutrition.carbs, value.nutrition.fat].allSatisfy({ $0 <= 100_000 }) else {
                    throw ExchangeError.invalidResponse
                }
                let recipe = RecipeData(name: value.name, symbol: "sparkles", servings: value.servings, minutes: value.minutes,
                    difficulty: value.difficulty, nutrition: value.nutrition,
                    ingredients: value.ingredients.map { .init(name: $0.name, quantity: $0.quantity, unit: $0.unit, category: $0.category) }, steps: value.steps, sources: value.sources)
                try recipe.validate()
                return recipe
            }
        } catch { throw ExchangeError.invalidResponse }
    }
    private struct Envelope: Decodable { let recipes: [SharedRecipe] }
    private struct SharedRecipe: Decodable {
        let name: String
        let servings: Int
        let minutes: Int
        let difficulty: String
        let nutrition: Nutrients
        let ingredients: [SharedIngredient]
        let steps: [String]
        let sources: [RecipeSource]?
    }
    private struct SharedIngredient: Decodable {
        let name: String
        let quantity: Double
        let unit: String
        let category: String
    }
}
