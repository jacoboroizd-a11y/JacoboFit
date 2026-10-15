import XCTest

final class MealFlowTests: XCTestCase {
    @MainActor func testDemoAnalysisCorrectionAndSaveUpdatesHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["Registro"].tap()
        app.buttons["Analizar comida"].tap()
        XCTAssertTrue(app.navigationBars["Revisá tu comida"].waitForExistence(timeout: 10))
        app.swipeUp()
        let tortilla = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Tortilla de maíz")).firstMatch
        XCTAssertTrue(tortilla.waitForExistence(timeout: 3))
        tortilla.tap()
        let decrease = app.buttons["quantity-decrease"]
        XCTAssertTrue(decrease.waitForExistence(timeout: 3))
        decrease.tap()
        decrease.tap() // 3 -> 2 tortillas
        app.navigationBars.buttons["Listo"].tap()
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["~435 kcal"].exists)
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.staticTexts["Tacos de fajita · ejemplo"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Hoy"].tap()
        XCTAssertTrue(app.staticTexts["~435"].waitForExistence(timeout: 5))
    }
}
