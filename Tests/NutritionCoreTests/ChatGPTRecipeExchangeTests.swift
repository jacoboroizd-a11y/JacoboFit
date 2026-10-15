import XCTest
@testable import NutritionCore

final class ChatGPTRecipeExchangeTests: XCTestCase {
    private let valid = """
    {"recipes":[{"name":"Ensalada de pollo cocido","servings":2,"minutes":15,"difficulty":"Fácil",
    "nutrition":{"calories":800,"protein":90,"carbs":40,"fat":30},
    "ingredients":[{"name":"Pollo cocido","quantity":300,"unit":"g","category":"proteínas"}],
    "steps":["Usá pollo ya cocido y refrigerado adecuadamente.","Mezclá con vegetales. Nutrición aproximada."]}]}
    """
    func testPromptPreservesIdeaAndExplainsWholeRecipeNutritionAndCookedFood() throws {
        let prompt = try ChatGPTRecipeExchange.makePrompt(idea: "Voy a comer pollo cocido", servings: 2, minutes: 20)
        XCTAssertTrue(prompt.contains("Voy a comer pollo cocido"))
        XCTAssertTrue(prompt.contains("YA COCIDO"))
        XCTAssertTrue(prompt.contains("para 2 persona"))
        XCTAssertTrue(prompt.contains("20 minutos"))
        XCTAssertTrue(prompt.contains("TODA la receta"))
        XCTAssertTrue(prompt.contains("SOLO JSON"))
    }
    func testEmptyAndOversizedRequestsAreRejected() {
        XCTAssertThrowsError(try ChatGPTRecipeExchange.makePrompt(idea: " ", servings: 1, minutes: 20))
        XCTAssertThrowsError(try ChatGPTRecipeExchange.makePrompt(idea: String(repeating: "a", count: 2501), servings: 1, minutes: 20))
        XCTAssertThrowsError(try ChatGPTRecipeExchange.makePrompt(idea: "Pollo", servings: 0, minutes: 20))
    }
    func testPlainAndFencedJSONImportWithoutModelInventedUUIDs() throws {
        let plain = try ChatGPTRecipeExchange.importRecipes(valid)
        let fenced = try ChatGPTRecipeExchange.importRecipes("```json\n" + valid + "\n```")
        XCTAssertEqual(plain[0].name, "Ensalada de pollo cocido")
        XCTAssertEqual(plain[0].ingredients[0].name, "Pollo cocido")
        XCTAssertEqual(plain[0].nutrition.calories, 800)
        XCTAssertEqual(try plain[0].scaled(to: 1).nutrition.calories, 400)
        XCTAssertEqual(fenced[0].name, plain[0].name)
        XCTAssertNotEqual(plain[0].id, fenced[0].id)
    }
    func testRejectsProseInvalidNumbersAndMissingNutrition() {
        XCTAssertThrowsError(try ChatGPTRecipeExchange.importRecipes("Esta es una receta deliciosa"))
        XCTAssertThrowsError(try ChatGPTRecipeExchange.importRecipes(valid.replacingOccurrences(of: "\"calories\":800", with: "\"calories\":-1")))
        XCTAssertThrowsError(try ChatGPTRecipeExchange.importRecipes(valid.replacingOccurrences(of: "\"quantity\":300", with: "\"quantity\":0")))
        XCTAssertThrowsError(try ChatGPTRecipeExchange.importRecipes(valid.replacingOccurrences(of: "\"servings\":2", with: "\"servings\":0")))
        XCTAssertThrowsError(try ChatGPTRecipeExchange.importRecipes(valid.replacingOccurrences(of: "\"protein\":90,", with: "")))
        XCTAssertThrowsError(try ChatGPTRecipeExchange.importRecipes("{\"recipes\":[]}"))
    }
    func testImportedSourceIsRetainedAndInsecureSourceIsRejected() throws {
        let withSource = valid.replacingOccurrences(of: "\"steps\":", with: "\"sources\":[{\"title\":\"MyPlate\",\"url\":\"https://www.myplate.gov/recipes\"}],\"steps\":")
        let recipe = try ChatGPTRecipeExchange.importRecipes(withSource)[0]
        XCTAssertEqual(recipe.sources?.first?.url.host, "www.myplate.gov")
        XCTAssertEqual(try recipe.scaled(to: 1).sources?.first?.title, "MyPlate")
        XCTAssertThrowsError(try ChatGPTRecipeExchange.importRecipes(withSource.replacingOccurrences(of: "https://", with: "http://")))
    }
    func testRejectsTooLargeClipboardInput() {
        XCTAssertThrowsError(try ChatGPTRecipeExchange.importRecipes(String(repeating: "x", count: 200001)))
    }
}
