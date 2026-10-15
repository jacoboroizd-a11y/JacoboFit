import Foundation
import SwiftData
import NutritionCore

enum DemoData {
    @MainActor static func loadRecipes(into context: ModelContext) throws {
        guard let url = Bundle.main.url(forResource: "DemoRecipes", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        let recipes = try JSONDecoder().decode([RecipeData].self, from: data)
        let existing = Set(try context.fetch(FetchDescriptor<Recipe>()).map(\.id))
        for recipe in recipes where !existing.contains(recipe.id) { context.insert(try Recipe(recipe)) }
        try context.save()
    }
}
