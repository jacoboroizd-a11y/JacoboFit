import XCTest
@testable import NutritionCore

final class NutritionTests: XCTestCase {
    func testMealTotalsUseQuantitiesAndAllMacros() throws {
        let analysis = MealAnalysis(mealName: "Tacos", items: [
            .init(name: "Tortilla", quantity: 3, perUnit: .init(calories: 35, protein: 1, carbs: 7, fat: 0.3)),
            .init(name: "Res", perUnit: .init(calories: 330, protein: 42, carbs: 0, fat: 18))
        ])
        try analysis.validate()
        XCTAssertEqual(analysis.total.calories, 435)
        XCTAssertEqual(analysis.total.protein, 45)
        XCTAssertEqual(analysis.total.carbs, 21)
        XCTAssertEqual(analysis.total.fat, 18.9, accuracy: 0.0001)
    }
    func testCorrectionsRecalculateWithoutMutatingOriginal() {
        let original = MealAnalysis(mealName: "Taco", items: [.init(name: "Tortilla", quantity: 3, perUnit: .init(calories: 35))])
        var corrected = original
        corrected.items[0].quantity = 2
        corrected.items.append(.init(name: "Manteca", quantity: 0.5, perUnit: .init(calories: 115, fat: 12.8)))
        XCTAssertEqual(original.total.calories, 105)
        XCTAssertEqual(corrected.total.calories, 127.5)
        XCTAssertEqual(corrected.total.fat, 6.4)
        XCTAssertEqual(corrected.calorieRange.lowerBound, 127.5 * 0.85, accuracy: 0.001)
    }
    func testHealthActiveEnergyAlreadyIncludesWorkout() throws {
        let result = try XCTUnwrap(EstimatedTDEEService.estimate(restingEnergy: 1900, activeEnergy: 831,
            workoutEnergy: 430, manualRestingEstimate: nil, consumed: 1420))
        XCTAssertEqual(result.totalExpenditure, 2731)
        XCTAssertEqual(result.balance, -1311)
    }
    func testFallbackUsesWorkoutOnlyWhenActiveUnavailable() {
        XCTAssertEqual(EstimatedTDEEService.estimate(restingEnergy: nil, activeEnergy: nil, workoutEnergy: 430,
            manualRestingEstimate: 1800, consumed: 2000)?.totalExpenditure, 2230)
        XCTAssertEqual(EstimatedTDEEService.estimate(restingEnergy: 1800, activeEnergy: 0, workoutEnergy: 430,
            manualRestingEstimate: nil, consumed: 2000)?.totalExpenditure, 1800)
    }
    func testUnknownRestingEnergyDoesNotInventDeficit() {
        XCTAssertNil(EstimatedTDEEService.estimate(restingEnergy: nil, activeEnergy: 800, manualRestingEstimate: nil, consumed: 1400))
        XCTAssertNil(EstimatedTDEEService.estimate(restingEnergy: -1, activeEnergy: 800, manualRestingEstimate: nil, consumed: 1400))
        XCTAssertNil(EstimatedTDEEService.estimate(restingEnergy: 1800, activeEnergy: .nan, manualRestingEstimate: nil, consumed: 1400))
    }
    func testStructuredAnalysisRoundTripAndInvalidResponseRejection() throws {
        let analysis = MealAnalysis(mealName: "Comida", items: [.init(name: "Pollo", perUnit: .init(calories: 300, protein: 40))])
        let data = try JSONEncoder().encode(analysis)
        XCTAssertEqual(try MealAnalysis.decodeValidated(data), analysis)
        var invalid = analysis
        invalid.items[0].quantity = -2
        XCTAssertThrowsError(try MealAnalysis.decodeValidated(JSONEncoder().encode(invalid)))
        invalid = analysis; invalid.confidence = 1.2
        XCTAssertThrowsError(try invalid.validate())
        invalid = analysis; invalid.items.append(invalid.items[0])
        XCTAssertThrowsError(try invalid.validate())
        XCTAssertThrowsError(try MealAnalysis.decodeValidated(Data("{\"mealName\":\"bad\"}".utf8)))
        invalid = analysis; invalid.items[0].perUnit.protein = .infinity
        XCTAssertThrowsError(try invalid.validate())
    }
    func testEmptyMealCannotBeSaved() {
        XCTAssertThrowsError(try MealAnalysis(mealName: "", items: []).validate())
    }
}
