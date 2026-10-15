import SwiftUI
import SwiftData
import NutritionCore

struct WeekView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CalendarDay.date) private var days: [CalendarDay]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var weekOffset = 0
    @State private var selectedDay: Date?
    @State private var showGrocery = false
    @State private var showRecipePicker = false
    @State private var recipeToPlan: RecipeData?
    @State private var error: String?
    private var weekStart: Date { WeekDates.monday(containing: Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: .now)!) }
    private var dates: [Date] { (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: weekStart)! } }
    private var weekDays: [CalendarDay] { days.filter { $0.date >= weekStart && $0.date < Calendar.current.date(byAdding: .day, value: 7, to: weekStart)! } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Una semana\na tu ritmo.").font(.largeTitle.bold())
                HStack {
                    Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Semana anterior")
                    Spacer(); Text(weekStart.formatted(.dateTime.day().month(.wide))).font(.headline); Spacer()
                    Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Semana siguiente")
                }
                Button("Crear lista del súper", systemImage: "basket") { showGrocery = true }.buttonStyle(.borderedProminent)
                Text("Planificación manual en modo demo. Elegí tus recetas y entrenamientos; la generación de semanas con IA llegará en la fase 2.").font(.footnote).foregroundStyle(.secondary)
                ForEach(dates, id: \.self) { date in
                    let day = days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
                    Surface {
                        HStack {
                            Text(date.formatted(.dateTime.weekday(.wide).day())).font(.title3.bold())
                            Spacer()
                            if Calendar.current.isDateInToday(date) { Text("HOY").font(.caption.bold()).foregroundStyle(.teal) }
                        }
                        Button { selectedDay = date } label: { Label(day?.workout ?? "Añadir entrenamiento", systemImage: "figure.strengthtraining.traditional") }
                        if let day {
                            ForEach(day.meals.sorted { $0.category < $1.category }) { plan in
                                HStack(alignment: .top) {
                                    Image(systemName: symbol(plan.category)).foregroundStyle(.teal).frame(width: 24)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(plan.category).font(.caption).foregroundStyle(.secondary)
                                        Text(plan.recipe?.name ?? "Receta no disponible").font(.headline)
                                        Text("\(plan.portions) porción(es)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) { context.delete(plan); save() } label: { Image(systemName: "minus.circle") }.accessibilityLabel("Eliminar \(plan.recipe?.name ?? "comida") del plan")
                                }
                            }
                        }
                        Button("Agregar comida", systemImage: "plus") {
                            selectedPlanDate = date; showRecipePicker = true
                        }
                    }
                }
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle("Calendario").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { selectedDay != nil }, set: { if !$0 { selectedDay = nil } })) {
            if let selectedDay { NavigationStack { WorkoutEditorView(date: selectedDay) } }
        }
        .sheet(isPresented: $showGrocery) { NavigationStack { GroceryView(days: weekDays, weekStart: weekStart) } }
        .sheet(isPresented: $showRecipePicker, onDismiss: {
            if pendingRecipe != nil { recipeToPlan = pendingRecipe; pendingRecipe = nil }
        }) {
            NavigationStack {
                List {
                    if recipes.isEmpty { Text("Primero creá o cargá recetas en la pestaña Recetas.").foregroundStyle(.secondary) }
                    ForEach(recipes) { recipe in
                        Button(recipe.name) {
                            do { pendingRecipe = try recipe.value(); showRecipePicker = false }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                }.navigationTitle("Elegí una receta")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { showRecipePicker = false } } }
            }
        }
        .sheet(item: $recipeToPlan) { recipe in NavigationStack { PlanMealView(recipe: recipe, initialDate: selectedPlanDate) } }
        .alert("Calendario", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
    @State private var selectedPlanDate = Date.now
    @State private var pendingRecipe: RecipeData?
    private func symbol(_ category: String) -> String {
        switch category { case "Desayuno": "sun.max"; case "Almuerzo": "fork.knife"; case "Cena": "moon"; default: "carrot" }
    }
    private func save() { do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription } }
}

enum WeekDates {
    static func monday(containing date: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day)!
    }
}

struct PlanMealView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var days: [CalendarDay]
    let recipe: RecipeData
    @State private var date: Date
    @State private var category = "Almuerzo"
    @State private var portions: Int
    @State private var error: String?
    init(recipe: RecipeData, initialDate: Date = .now) {
        self.recipe = recipe; _date = State(initialValue: initialDate)
        _portions = State(initialValue: recipe.servings)
    }
    var body: some View {
        Form {
            Text(recipe.name).font(.headline)
            DatePicker("Día", selection: $date, displayedComponents: .date)
            Picker("Comida", selection: $category) { ForEach(["Desayuno", "Almuerzo", "Cena", "Snack"], id: \.self) { Text($0) } }
            Stepper("Porciones para cocinar: \(portions)", value: $portions, in: 1...12)
            Text("La lista del súper incluye todos los ingredientes para estas porciones.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Planificar comida").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Agregar") {
                do {
                    let day = days.first { Calendar.current.isDate($0.date, inSameDayAs: date) } ?? CalendarDay(date: Calendar.current.startOfDay(for: date))
                    if day.modelContext == nil { context.insert(day) }
                    day.meals.append(try PlannedMeal(category: category, portions: portions, recipe: recipe))
                    try context.save(); dismiss()
                } catch { context.rollback(); self.error = error.localizedDescription }
            }.bold() }
        }
        .alert("No se pudo planificar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
}

struct WorkoutEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var days: [CalendarDay]
    var date: Date
    @State private var workout = "Descanso"
    @State private var error: String?
    var body: some View {
        Form {
            Text(date.formatted(date: .complete, time: .omitted))
            TextField("Entrenamiento: Pull, Piernas, caminar 5K…", text: $workout)
            Text("Es un plan, no calorías gastadas. No lo sumamos al balance del dashboard.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Tu entrenamiento")
        .onAppear { workout = days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.workout ?? "Descanso" }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                let day = days.first { Calendar.current.isDate($0.date, inSameDayAs: date) } ?? CalendarDay(date: Calendar.current.startOfDay(for: date))
                if day.modelContext == nil { context.insert(day) }; day.workout = workout
                do { try context.save(); dismiss() } catch { context.rollback(); self.error = error.localizedDescription }
            } }
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
}
