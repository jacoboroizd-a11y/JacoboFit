import XCTest
@testable import NutritionCore

final class PlanningTests: XCTestCase {
    private func recipe() -> RecipeData {
        .init(name: "Pollo para dos", servings: 2, nutrition: .init(calories: 800, protein: 100, carbs: 20, fat: 24),
              ingredients: [.init(name: "Pollo", quantity: 400, unit: "g", category: "proteínas"),
                            .init(name: "Tomate", quantity: 2, unit: "unidad", category: "vegetales")], steps: ["Cocinar"])
    }
    func testScalingRecipePreservesPerServingNutrition() throws {
        let original = recipe()
        let scaled = try original.scaled(to: 3)
        XCTAssertEqual(scaled.nutrition.calories, 1200)
        XCTAssertEqual(scaled.nutrition.protein, 150)
        XCTAssertEqual(scaled.nutrition.carbs, 30)
        XCTAssertEqual(scaled.nutrition.fat, 36)
        XCTAssertEqual(scaled.ingredients[0].quantity, 600)
        XCTAssertEqual(original.ingredients[0].quantity, 400)
        XCTAssertEqual(try scaled.scaled(to: 1).nutrition.calories, 400)
        XCTAssertThrowsError(try original.scaled(to: 0))
        var invalid = original; invalid.servings = 0
        XCTAssertThrowsError(try invalid.scaled(to: 2))
    }
    func testGroceryConsolidatesAcrossRepeatedMealsAndPortions() throws {
        let list = try GroceryService.list(for: [.init(recipe: recipe(), portions: 1), .init(recipe: recipe(), portions: 3)])
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.first { $0.name == "pollo" }?.quantity, 800)
        XCTAssertEqual(list.first { $0.name == "tomate" }?.quantity, 4)
    }
    func testGroceryKeepsIncompatibleUnitsSeparateAndNormalizesCase() {
        let list = GroceryService.consolidate([
            .init(name: " Atún ", quantity: 2, unit: " LATA ", category: "Proteínas"),
            .init(name: "atún", quantity: 1, unit: "lata", category: "proteínas"),
            .init(name: "atún", quantity: 100, unit: "g", category: "proteínas")])
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.first { $0.unit == "lata" }?.quantity, 3)
        XCTAssertEqual(Set(list.map(\.id)).count, 2)
    }
    func testMalformedPlannedRecipeFailsRatherThanSilentlyOmittingIngredients() {
        var invalid = recipe(); invalid.ingredients[0].quantity = -2
        XCTAssertThrowsError(try GroceryService.list(for: [.init(recipe: invalid, portions: 2)]))
    }
    func testEditableDemoRecipesDecodeAndValidate() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("JacoboFit/Resources/DemoRecipes.json")
        let recipes = try JSONDecoder().decode([RecipeData].self, from: Data(contentsOf: url))
        XCTAssertEqual(recipes.count, 9)
        XCTAssertEqual(Set(recipes.map(\.id)).count, recipes.count)
        for recipe in recipes {
            try recipe.validate()
            let scaled = try recipe.scaled(to: 2)
            XCTAssertEqual(scaled.nutrition.calories, recipe.nutrition.calories * 2 / Double(recipe.servings))
        }
    }
    func testEmptyPlanHasEmptyGroceryList() throws { XCTAssertTrue(try GroceryService.list(for: []).isEmpty) }
}

final class AIServiceTests: XCTestCase {
    func testMockWorksWithoutPhotoKeyOrBackendAndDisclosesDemo() async throws {
        let result = try await MockAIService().analyzeMealPhoto(nil, description: "")
        try result.validate()
        XCTAssertEqual(result.total.calories, 470)
        XCTAssertTrue(result.uncertainties.contains { $0.contains("Modo demo") })
        XCTAssertFalse(result.followUpQuestions.isEmpty)
    }
    func testRemoteRejectsInsecureEndpoint() {
        XCTAssertThrowsError(try RemoteAIService(endpoint: URL(string: "http://example.com")!, sessionToken: "session"))
    }
    func testMockDoesNotPretendToGenerateRecipes() async {
        do { _ = try await MockAIService().generateRecipes(prompt: "pollo"); XCTFail("Should report unavailable") }
        catch { XCTAssertTrue(error is AIServiceError) }
    }
}
