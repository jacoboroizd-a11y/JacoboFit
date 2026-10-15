import Foundation
import SwiftData
import NutritionCore

@Model final class UserProfile {
    var name: String = "Jacobo"
    var currentWeightLB: Double = 236
    var targetWeightLB: Double = 220
    /// Explicit user estimate. Zero means unknown, rather than inventing a basal rate.
    var restingEnergyEstimate: Double = 0
    init() {}
}

@Model final class NutritionGoal {
    var calories: Double = 1800
    var protein: Double = 170
    var waterOunces: Double = 96
    init() {}
}

@Model final class FoodProduct {
    var name: String
    var brand: String
    var portion: String
    var nutritionData: Data
    init(component: FoodComponent) throws {
        name = component.name; brand = component.brand; portion = component.unit
        nutritionData = try JSONEncoder().encode(component.perUnit)
    }
}

@Model final class Meal {
    var id: UUID = UUID()
    var date: Date
    var category: String
    var name: String
    @Attribute(.externalStorage) var photo: Data?
    var originalAnalysis: Data
    var finalAnalysis: Data
    @Relationship(deleteRule: .cascade, inverse: \MealItem.meal) var items: [MealItem] = []
    @Relationship(deleteRule: .cascade, inverse: \AIAnalysis.meal) var analysisHistory: [AIAnalysis] = []
    init(date: Date = .now, category: String, photo: Data?, original: MealAnalysis, final: MealAnalysis) throws {
        try final.validate()
        self.date = date; self.category = category; self.photo = photo; name = final.mealName
        originalAnalysis = try JSONEncoder().encode(original)
        finalAnalysis = try JSONEncoder().encode(final)
        items = try final.items.map { try MealItem(component: $0) }
        analysisHistory = [AIAnalysis(payload: originalAnalysis, kind: "original"), AIAnalysis(payload: finalAnalysis, kind: "corregido")]
    }
    var analysis: MealAnalysis? { try? MealAnalysis.decodeValidated(finalAnalysis) }
    var total: Nutrients { analysis?.total ?? .zero }
}

@Model final class MealItem {
    var componentData: Data
    var meal: Meal?
    init(component: FoodComponent) throws { componentData = try JSONEncoder().encode(component) }
}

@Model final class Recipe {
    var id: UUID
    var name: String
    var symbol: String
    var servings: Int
    var minutes: Int
    var difficulty: String
    var nutritionData: Data
    var steps: [String]
    var favorite: Bool = false
    var inFoodList: Bool = false
    var shoppingServings: Int = 1
    var isDraft: Bool = false
    var sourcesData: Data?
    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe) var ingredients: [RecipeIngredient] = []
    init(_ data: RecipeData) throws {
        id = data.id; name = data.name; symbol = data.symbol; servings = data.servings
        minutes = data.minutes; difficulty = data.difficulty; steps = data.steps
        sourcesData = try JSONEncoder().encode(data.sources)
        nutritionData = try JSONEncoder().encode(data.nutrition)
        ingredients = data.ingredients.map { RecipeIngredient($0) }
    }
    func value() throws -> RecipeData {
        .init(id: id, name: name, symbol: symbol, servings: servings, minutes: minutes,
              difficulty: difficulty, nutrition: try JSONDecoder().decode(Nutrients.self, from: nutritionData),
              ingredients: ingredients.map(\.value), steps: steps,
              sources: sourcesData.flatMap { try? JSONDecoder().decode([RecipeSource].self, from: $0) })
    }
}

@Model final class RecipeIngredient {
    var name: String
    var quantity: Double
    var unit: String
    var category: String
    var recipe: Recipe?
    init(_ item: Ingredient) { name = item.name; quantity = item.quantity; unit = item.unit; category = item.category }
    var value: Ingredient { .init(name: name, quantity: quantity, unit: unit, category: category) }
}

@Model final class CalendarDay {
    var date: Date
    var workout: String = "Descanso"
    @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.day) var meals: [PlannedMeal] = []
    @Relationship(deleteRule: .cascade, inverse: \WorkoutInfo.day) var workouts: [WorkoutInfo] = []
    init(date: Date) { self.date = date }
}

@Model final class PlannedMeal {
    var category: String
    var portions: Int
    /// A snapshot keeps a planned meal usable even if the source recipe is deleted.
    var recipeSnapshot: Data
    var day: CalendarDay?
    init(category: String, portions: Int, recipe: RecipeData) throws {
        self.category = category; self.portions = portions
        recipeSnapshot = try JSONEncoder().encode(recipe)
    }
    var recipe: RecipeData? { try? JSONDecoder().decode(RecipeData.self, from: recipeSnapshot) }
}

@Model final class WorkoutInfo {
    var name: String
    var minutes: Double
    var activeCalories: Double
    var day: CalendarDay?
    init(name: String, minutes: Double, activeCalories: Double) {
        self.name = name; self.minutes = minutes; self.activeCalories = activeCalories
    }
}

@Model final class WaterEntry {
    var date: Date
    var ounces: Double
    init(ounces: Double, date: Date = .now) { self.ounces = ounces; self.date = date }
}

@Model final class WeightEntry {
    var date: Date
    var pounds: Double
    init(pounds: Double, date: Date = .now) { self.pounds = pounds; self.date = date }
}

@Model final class AIAnalysis {
    var date: Date = Date.now
    var payload: Data
    var kind: String
    var meal: Meal?
    init(payload: Data, kind: String) { self.payload = payload; self.kind = kind }
}

@Model final class FrequentMeal {
    var name: String
    var recipeSnapshot: Data
    var useCount: Int = 1
    init(name: String, recipe: RecipeData) throws {
        self.name = name; recipeSnapshot = try JSONEncoder().encode(recipe)
    }
}

@Model final class GroceryCheck {
    var key: String
    init(key: String) { self.key = key }
}
