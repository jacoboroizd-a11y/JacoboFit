import XCTest

final class RecipeCalendarTests: XCTestCase {
    @MainActor func testCalendarGridOpensSelectedDay() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["Calendario"].tap()
        let today = app.buttons["calendar-today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Agregar comida"].waitForExistence(timeout: 3))
    }
    @MainActor func testRecipeComposerPreparesManualChatGPTExchange() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["Recetas"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "recipe-prompt").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("Voy a comer pollo cocido")
        app.buttons["Listo"].tap()
        let prepare = app.buttons["recipe-open-chatgpt"]
        XCTAssertTrue(prepare.waitForExistence(timeout: 3))
        XCTAssertTrue(prepare.isEnabled)
        // Do not launch an external client or read the user's clipboard in UI tests.
    }
}
