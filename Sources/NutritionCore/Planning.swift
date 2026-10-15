import Foundation

public struct Ingredient: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var quantity: Double
    public var unit: String
    public var category: String
    public init(id: UUID = UUID(), name: String, quantity: Double, unit: String, category: String) {
        self.id = id; self.name = name; self.quantity = quantity; self.unit = unit; self.category = category
    }
}

public struct RecipeSource: Codable, Hashable, Sendable {
    public var title: String
    public var url: URL
    public init(title: String, url: URL) { self.title = title; self.url = url }
}

public struct RecipeData: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var symbol: String
    public var servings: Int
    public var minutes: Int
    public var difficulty: String
    /// Nutrition and ingredients for the complete recipe, not one serving.
    public var nutrition: Nutrients
    public var ingredients: [Ingredient]
    public var steps: [String]
    public var sources: [RecipeSource]?
    public init(id: UUID = UUID(), name: String, symbol: String = "fork.knife", servings: Int = 1,
                minutes: Int = 20, difficulty: String = "Fácil", nutrition: Nutrients,
                ingredients: [Ingredient], steps: [String], sources: [RecipeSource]? = nil) {
        self.id = id; self.name = name; self.symbol = symbol; self.servings = servings
        self.minutes = minutes; self.difficulty = difficulty; self.nutrition = nutrition
        self.ingredients = ingredients; self.steps = steps; self.sources = sources
    }
    public func scaled(to newServings: Int) throws -> Self {
        guard servings > 0, newServings > 0 else { throw NutritionError.invalidValue("porciones") }
        let factor = Double(newServings) / Double(servings)
        var copy = self
        copy.servings = newServings
        copy.nutrition = nutrition.scaled(by: factor)
        copy.ingredients = ingredients.map { item in
            var result = item; result.quantity *= factor; return result
        }
        return copy
    }
}

public struct GroceryItem: Identifiable, Equatable, Sendable {
    public var id: String { category + "|" + name + "|" + unit }
    public var name: String
    public var quantity: Double
    public var unit: String
    public var category: String
}

public enum GroceryService {
    /// Normalize spelling/case, but keep incompatible units separate (e.g. g and cans).
    public static func consolidate(_ ingredients: [Ingredient]) -> [GroceryItem] {
        var groups: [String: GroceryItem] = [:]
        for item in ingredients where item.quantity.isFinite && item.quantity > 0 {
            let name = normalize(item.name), unit = normalize(item.unit), category = normalize(item.category)
            let key = category + "|" + name + "|" + unit
            if var previous = groups[key] {
                previous.quantity += item.quantity; groups[key] = previous
            } else {
                groups[key] = .init(name: name, quantity: item.quantity, unit: unit, category: category)
            }
        }
        return groups.values.sorted { ($0.category, $0.name, $0.unit) < ($1.category, $1.name, $1.unit) }
    }
    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension RecipeData {
    public func validate() throws {
        try nutrition.validate()
        guard (sources ?? []).count <= 5, (sources ?? []).allSatisfy({ !$0.title.isEmpty && $0.url.scheme == "https" && $0.url.host != nil && $0.url.user == nil && $0.url.password == nil }) else {
            throw NutritionError.invalidValue("fuente de receta")
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, servings > 0,
              minutes > 0, !ingredients.isEmpty, ingredients.count <= 100, !steps.isEmpty, steps.count <= 30,
              steps.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(ingredients.map(\.id)).count == ingredients.count,
              ingredients.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.unit.isEmpty && $0.quantity.isFinite && $0.quantity > 0 }) else {
            throw NutritionError.invalidValue("receta o ingredientes")
        }
    }
}

public struct RecipePlan: Sendable {
    public let recipe: RecipeData
    public let portions: Int
    public init(recipe: RecipeData, portions: Int) { self.recipe = recipe; self.portions = portions }
}

extension GroceryService {
    public static func list(for plans: [RecipePlan]) throws -> [GroceryItem] {
        let ingredients = try plans.flatMap { plan in
            try plan.recipe.validate()
            return try plan.recipe.scaled(to: plan.portions).ingredients
        }
        return consolidate(ingredients)
    }
}
