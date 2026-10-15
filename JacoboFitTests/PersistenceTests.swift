import XCTest
import SwiftData
import NutritionCore
@testable import JacoboFit

@MainActor final class PersistenceTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Meal.self, MealItem.self, AIAnalysis.self,
            Recipe.self, RecipeIngredient.self, CalendarDay.self, PlannedMeal.self, WorkoutInfo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    func testMealPersistsOriginalAndCorrectionsAndCascadesOnDelete() throws {
        let container = try container()
        let context = ModelContext(container)
        let original = MealAnalysis(mealName: "Tacos", items: [.init(name: "Tortilla", quantity: 3, perUnit: .init(calories: 35))])
        var corrected = original
        corrected.items[0].quantity = 2
        let meal = try Meal(category: "Cena", photo: Data([1, 2, 3]), original: original, final: corrected)
        context.insert(meal); try context.save()
        let reader = ModelContext(container)
        let saved = try XCTUnwrap(reader.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertEqual(saved.total.calories, 70)
        XCTAssertEqual(try MealAnalysis.decodeValidated(saved.originalAnalysis).total.calories, 105)
        XCTAssertEqual(saved.items.count, 1)
        XCTAssertEqual(saved.analysisHistory.count, 2)
        XCTAssertEqual(saved.items.first?.meal?.id, saved.id)
        XCTAssertEqual(saved.photo, Data([1, 2, 3]))
        context.delete(meal); try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealItem>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AIAnalysis>()), 0)
    }
    func testFoodListDraftFlagsSourcesAndIngredientsSurvivePersistence() throws {
        let container = try container()
        let context = ModelContext(container)
        let data = RecipeData(name: "Pollo cocido", servings: 2, nutrition: .zero,
            ingredients: [.init(name: "Pollo", quantity: 300, unit: "g", category: "proteínas")],
            steps: ["Borrador pendiente"], sources: [.init(title: "MyPlate", url: URL(string: "https://www.myplate.gov/recipes")!)])
        let recipe = try Recipe(data)
        recipe.inFoodList = true; recipe.shoppingServings = 4; recipe.isDraft = true
        context.insert(recipe); try context.save()
        let reader = ModelContext(container)
        let saved = try XCTUnwrap(reader.fetch(FetchDescriptor<Recipe>()).first)
        XCTAssertTrue(saved.inFoodList); XCTAssertTrue(saved.isDraft)
        XCTAssertEqual(saved.shoppingServings, 4)
        XCTAssertEqual(try saved.value().sources?.first?.url.host, "www.myplate.gov")
        let shopping = try GroceryService.list(for: [.init(recipe: saved.value(), portions: saved.shoppingServings)])
        XCTAssertEqual(shopping[0].quantity, 600)
    }
    func testCalendarSnapshotSurvivesDeletingSourceRecipe() throws {
        let container = try container()
        let context = ModelContext(container)
        let data = RecipeData(name: "Pollo", servings: 2, nutrition: .init(calories: 800, protein: 100),
            ingredients: [.init(name: "Pollo", quantity: 400, unit: "g", category: "proteínas")], steps: ["Cocinar"])
        let recipe = try Recipe(data)
        let day = CalendarDay(date: .now)
        day.meals = [try PlannedMeal(category: "Almuerzo", portions: 3, recipe: data)]
        context.insert(recipe); context.insert(day); try context.save()
        context.delete(recipe); try context.save()
        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<CalendarDay>()).first)
        let snapshot = try XCTUnwrap(saved.meals.first?.recipe)
        XCTAssertEqual(snapshot.name, "Pollo")
        let list = try GroceryService.list(for: [.init(recipe: snapshot, portions: saved.meals[0].portions)])
        XCTAssertEqual(list[0].quantity, 600)
        context.delete(saved); try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlannedMeal>()), 0)
    }
}
