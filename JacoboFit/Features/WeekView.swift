import SwiftUI
import SwiftData
import NutritionCore

struct WeekView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CalendarDay.date) private var days: [CalendarDay]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var selectedDate = Calendar.current.startOfDay(for: Date.now)
    @State private var displayedDate = Date.now
    @State private var mode = "Mes"
    @State private var showWorkout = false
    @State private var showGrocery = false
    @State private var showRecipePicker = false
    @State private var recipeToPlan: RecipeData?
    @State private var pendingRecipe: RecipeData?
    @State private var error: String?
    private var dates: [Date] { mode == "Mes" ? CalendarGrid.month(containing: displayedDate) : CalendarGrid.week(containing: displayedDate) }
    private var weekStart: Date { WeekDates.monday(containing: selectedDate) }
    private var weekDays: [CalendarDay] { days.filter { CalendarGrid.week(containing: selectedDate).contains(Calendar.current.startOfDay(for: $0.date)) } }
    private var selectedDay: CalendarDay? { day(for: selectedDate) }
    private var selectedMeals: [PlannedMeal] {
        (selectedDay?.meals ?? []).sorted { categoryOrder($0.category) < categoryOrder($1.category) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Tu semana,\na simple vista.").font(.largeTitle.bold())
                Picker("Vista del calendario", selection: $mode) {
                    Text("Mes").tag("Mes"); Text("Semana").tag("Semana")
                }.pickerStyle(.segmented)
                Surface {
                    HStack {
                        Button { move(-1) } label: { Image(systemName: "chevron.left").padding(10) }
                            .accessibilityLabel("Período anterior")
                        Spacer()
                        Text(displayedDate.formatted(.dateTime.month(.wide).year())).font(.headline).textCase(.uppercase)
                        Spacer()
                        Button { move(1) } label: { Image(systemName: "chevron.right").padding(10) }
                            .accessibilityLabel("Período siguiente")
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                        ForEach(Array(["L", "M", "M", "J", "V", "S", "D"].enumerated()), id: \.offset) { _, name in
                            Text(name).font(.caption.bold()).foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        ForEach(dates, id: \.self) { date in dateCell(date) }
                    }
                    HStack(spacing: 14) {
                        Label("Comidas", systemImage: "circle.fill").foregroundStyle(.teal)
                        Label("Entrenamiento", systemImage: "circle.fill").foregroundStyle(.orange)
                        Spacer()
                        Button("Hoy") { selectedDate = Calendar.current.startOfDay(for: .now); displayedDate = .now }
                    }.font(.caption)
                }
                Surface {
                    HStack {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month())).font(.title3.bold())
                        Spacer()
                        if Calendar.current.isDateInToday(selectedDate) { Text("HOY").font(.caption.bold()).foregroundStyle(.teal) }
                    }
                    Button { showWorkout = true } label: { Label(selectedDay?.workout ?? "Añadir entrenamiento", systemImage: "figure.strengthtraining.traditional") }
                    if selectedMeals.isEmpty {
                        Label("Un día por planear", systemImage: "fork.knife").font(.headline).padding(.top, 8)
                        Text("Elegí una receta para empezar. Las comidas aparecen marcadas en la cuadrícula.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(selectedMeals) { plan in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: symbol(plan.category)).foregroundStyle(.teal).frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.category).font(.caption).foregroundStyle(.secondary)
                                Text(plan.recipe?.name ?? "Receta no disponible").font(.headline)
                                Text("\(plan.portions) porción(es)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { context.delete(plan); save() } label: { Image(systemName: "minus.circle") }
                                .accessibilityLabel("Eliminar \(plan.recipe?.name ?? "comida") del plan")
                        }.padding(.vertical, 6)
                    }
                    Button("Agregar comida", systemImage: "plus") { showRecipePicker = true }.primaryActionStyle()
                }
                Button { showGrocery = true } label: {
                    Surface {
                        Label("Lista del súper", systemImage: "basket").font(.headline)
                        Text("Semana del \(weekStart.formatted(.dateTime.day().month())) · según tus porciones")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain)
            }.padding()
        }.background { AppBackdrop() }.navigationTitle("Calendario").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWorkout) { NavigationStack { WorkoutEditorView(date: selectedDate) } }
        .sheet(isPresented: $showGrocery) { NavigationStack { GroceryView(days: weekDays, weekStart: weekStart) } }
        .sheet(isPresented: $showRecipePicker, onDismiss: {
            if let pendingRecipe { recipeToPlan = pendingRecipe; self.pendingRecipe = nil }
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
        .sheet(item: $recipeToPlan) { recipe in NavigationStack { PlanMealView(recipe: recipe, initialDate: selectedDate) } }
        .alert("Calendario", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
    private func dateCell(_ date: Date) -> some View {
        let entry = day(for: date)
        let mealCount = entry?.meals.count ?? 0
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let inMonth = Calendar.current.isDate(date, equalTo: displayedDate, toGranularity: .month)
        let workout = entry.map { !$0.workout.isEmpty && $0.workout != "Descanso" } ?? false
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                selectedDate = date
                if !inMonth { displayedDate = date }
            }
        } label: {
            VStack(spacing: 5) {
                Text(date.formatted(.dateTime.day())).font(.body.weight(selected ? .bold : .medium))
                HStack(spacing: 3) {
                    if !(entry?.meals.isEmpty ?? true) { Circle().fill(selected ? Color.white : .teal).frame(width: 5, height: 5) }
                    if workout { Circle().fill(selected ? Color.white : .orange).frame(width: 5, height: 5) }
                }.frame(height: 6)
                Text(mealCount > 0 ? "\(mealCount)" : " ")
                    .font(.system(size: 10)).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity).frame(minHeight: 62)
            .foregroundStyle(selected ? Color.white : inMonth ? Color.primary : Color.secondary)
            .background(selected ? Color.teal : Calendar.current.isDateInToday(date) ? Color.teal.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
            .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(entry?.meals.count ?? 0) comidas\(workout ? ", entrenamiento: " + (entry?.workout ?? "") : "")")
            .accessibilityAddTraits(selected ? [.isSelected] : [])
            .accessibilityIdentifier(Calendar.current.isDateInToday(date) ? "calendar-today" : "calendar-day-\(date.timeIntervalSince1970)")
    }
    private func day(for date: Date) -> CalendarDay? { days.first { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    private func move(_ delta: Int) {
        let component: Calendar.Component = mode == "Mes" ? .month : .weekOfYear
        guard let next = Calendar.current.date(byAdding: component, value: delta, to: displayedDate) else { return }
        displayedDate = next; selectedDate = Calendar.current.startOfDay(for: next)
    }
    private func categoryOrder(_ category: String) -> Int { ["Desayuno", "Almuerzo", "Cena", "Snack"].firstIndex(of: category) ?? 4 }
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
