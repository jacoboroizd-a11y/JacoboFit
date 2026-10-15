import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var selection = 0
    @State private var error: String?
    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { DashboardView(openLogging: { selection = 1 }) }
                .tabItem { Label("Hoy", systemImage: "square.grid.2x2.fill") }.tag(0)
            NavigationStack { MealLoggingView() }
                .tabItem { Label("Registro", systemImage: "camera.fill") }.tag(1)
            NavigationStack { WeekView() }
                .tabItem { Label("Calendario", systemImage: "calendar") }.tag(2)
            NavigationStack { RecipesView() }
                .tabItem { Label("Recetas", systemImage: "book.closed.fill") }.tag(3)
        }
        .task {
            do {
                if try context.fetchCount(FetchDescriptor<UserProfile>()) == 0 { context.insert(UserProfile()) }
                if try context.fetchCount(FetchDescriptor<NutritionGoal>()) == 0 { context.insert(NutritionGoal()) }
                try context.save()
            } catch { self.error = error.localizedDescription }
        }
        .alert("No se pudieron guardar los ajustes", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Cerrar") { error = nil }
        } message: { Text(error ?? "") }
    }
}
