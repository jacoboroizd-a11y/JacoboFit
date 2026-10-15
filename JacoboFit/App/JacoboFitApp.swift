import SwiftUI
import SwiftData

@main struct JacoboFitApp: App {
    private let container: ModelContainer?
    private let storageError: String?
    init() {
        do {
            #if DEBUG
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            #else
            let isUITesting = false
            #endif
            container = try ModelContainer(for: UserProfile.self, NutritionGoal.self, FoodProduct.self,
                Meal.self, MealItem.self, Recipe.self, RecipeIngredient.self, CalendarDay.self,
                PlannedMeal.self, WorkoutInfo.self, WaterEntry.self, WeightEntry.self,
                AIAnalysis.self, FrequentMeal.self, GroceryCheck.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: isUITesting))
            storageError = nil
        } catch {
            // Preserve the persistent store if it cannot be opened; never silently replace user data.
            container = nil; storageError = error.localizedDescription
        }
    }
    var body: some Scene {
        WindowGroup {
            if let container { RootView().tint(.teal).modelContainer(container) }
            else {
                ContentUnavailableView("No se pudo abrir tu historial", systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("Tus archivos no se eliminaron. Cerrá y volvé a abrir la app. Detalle: \(storageError ?? "Error de almacenamiento")"))
                    .padding()
            }
        }
    }
}
