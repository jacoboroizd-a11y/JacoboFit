import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Query private var goals: [NutritionGoal]
    var body: some View {
        Group {
            if let profile = profiles.first, let goal = goals.first { SettingsForm(profile: profile, goal: goal).id(profile.persistentModelID) }
            else { ProgressView("Preparando ajustes…") }
        }.navigationTitle("Ajustes")
    }
}

private struct SettingsForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    let goal: NutritionGoal
    @State private var name: String
    @State private var currentWeight: Double
    @State private var targetWeight: Double
    @State private var calories: Double
    @State private var protein: Double
    @State private var water: Double
    @State private var resting: Double
    @State private var error: String?
    init(profile: UserProfile, goal: NutritionGoal) {
        self.profile = profile; self.goal = goal
        _name = State(initialValue: profile.name); _currentWeight = State(initialValue: profile.currentWeightLB)
        _targetWeight = State(initialValue: profile.targetWeightLB); _calories = State(initialValue: goal.calories)
        _protein = State(initialValue: goal.protein); _water = State(initialValue: goal.waterOunces)
        _resting = State(initialValue: profile.restingEnergyEstimate)
    }
    var body: some View {
        Form {
            Section("Tu perfil") {
                TextField("Nombre", text: $name)
                number("Peso actual (lb)", value: $currentWeight)
                number("Peso objetivo (lb)", value: $targetWeight)
            }
            Section("Objetivos editables") {
                number("Calorías (kcal)", value: $calories)
                number("Proteína (g)", value: $protein)
                number("Agua (oz)", value: $water)
                Text("Los valores iniciales son ejemplos editables, no una recomendación personalizada.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Estimación de gasto sin Apple Health") {
                number("Gasto en reposo (kcal/día)", value: $resting)
                Text("Opcional: dejá 0 si no lo conocés. Es la base en reposo, no el gasto total. No sumamos otra vez las calorías de un entrenamiento si Health ya las incluyó como actividad.").font(.footnote).foregroundStyle(.secondary)
                if resting > 0 && resting - calories > 1000 {
                    Text("Este objetivo representa un déficit elevado incluso antes de sumar actividad. Las estimaciones tienen margen de error.").font(.footnote).foregroundStyle(.orange)
                }
            }
            Section {
                NavigationLink("Mis alimentos frecuentes") { FrequentFoodsView() }
                NavigationLink("Privacidad y eliminar datos") { PrivacyView() }
            }
            Section("Acerca de JacoboFit") {
                Text("Demo local · sin cuenta ni API key").font(.headline)
                Text("Las fotos y registros permanecen en el dispositivo. El modo demo no envía imágenes ni datos a ningún servidor. Las funciones remotas de IA todavía no están habilitadas.").font(.footnote)
                Text("Las estimaciones nutricionales no son mediciones médicas.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.bold() } }
        .alert("Revisá los ajustes", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
    private func number(_ title: String, value: Binding<Double>) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110) }
    }
    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              [currentWeight, targetWeight, calories, protein, water].allSatisfy({ $0.isFinite && $0 > 0 }), resting.isFinite, resting >= 0 else {
            error = "Usá valores positivos y un nombre. El gasto en reposo puede quedar en 0."; return
        }
        profile.name = name; profile.currentWeightLB = currentWeight; profile.targetWeightLB = targetWeight
        profile.restingEnergyEstimate = resting; goal.calories = calories; goal.protein = protein; goal.waterOunces = water
        do { try context.save(); dismiss() } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

struct WeightEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @State private var pounds: Double = 236
    @State private var error: String?
    var body: some View {
        Form {
            HStack { Text("Peso (lb)"); TextField("Peso", value: $pounds, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            Text("Se guarda localmente; no escribimos datos en Apple Health.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Registrar peso")
        .onAppear { pounds = profiles.first?.currentWeightLB ?? 236 }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                guard pounds.isFinite && pounds > 0 else { error = "Ingresá un peso válido."; return }
                context.insert(WeightEntry(pounds: pounds)); profiles.first?.currentWeightLB = pounds
                do { try context.save(); dismiss() } catch { context.rollback(); self.error = error.localizedDescription }
            } }
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
}

struct FrequentFoodsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodProduct.name) private var products: [FoodProduct]
    @State private var error: String?
    var body: some View {
        List {
            if products.isEmpty { Text("Al editar un ingrediente, activá ‘Guardar como alimento frecuente’. Después podrás reutilizar sus valores y marca.").foregroundStyle(.secondary) }
            ForEach(products) { product in
                VStack(alignment: .leading) { Text(product.name).bold(); Text("\(product.brand) · \(product.portion)").font(.caption).foregroundStyle(.secondary) }
            }.onDelete { indices in
                for index in indices { context.delete(products[index]) }
                do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
            }
        }.navigationTitle("Mis alimentos")
        .alert("No se pudo eliminar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
}

struct PrivacyView: View {
    @Environment(\.modelContext) private var context
    @Query private var meals: [Meal]
    @State private var action: String?
    @State private var selectedDate = Date.now
    @State private var notice: String?
    var body: some View {
        Form {
            Section("Tus datos son tuyos") {
                Text("Las fotos se guardan localmente. Al eliminar una comida se eliminan también sus componentes y análisis. No modificamos datos de Apple Health.")
            }
            Section("Eliminar un día") {
                DatePicker("Día", selection: $selectedDate, displayedComponents: .date)
                Button("Eliminar registros de ese día", role: .destructive) { action = "day" }
            }
            Section("Fotos") { Button("Eliminar todas las fotos de comidas", role: .destructive) { action = "photos" } }
            Section("Restablecer") {
                Button("Eliminar todo el historial y datos locales", role: .destructive) { action = "all" }
                Text("Incluye comidas, fotos, agua, pesos, recetas, planes, alimentos frecuentes y ajustes.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Privacidad")
        .confirmationDialog("¿Confirmás la eliminación? No se puede deshacer.", isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }), titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { performDeletion() }
            Button("Cancelar", role: .cancel) { action = nil }
        }
        .alert("Privacidad", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("Cerrar") { notice = nil } } message: { Text(notice ?? "") }
    }
    private func performDeletion() {
        let selected = action; action = nil
        do {
            switch selected {
            case "photos": for meal in meals { meal.photo = nil }
            case "day":
                for meal in meals where Calendar.current.isDate(meal.date, inSameDayAs: selectedDate) { context.delete(meal) }
                for entry in try context.fetch(FetchDescriptor<WaterEntry>()) where Calendar.current.isDate(entry.date, inSameDayAs: selectedDate) { context.delete(entry) }
                for entry in try context.fetch(FetchDescriptor<WeightEntry>()) where Calendar.current.isDate(entry.date, inSameDayAs: selectedDate) { context.delete(entry) }
            case "all":
                try removeAll(Meal.self); try removeAll(CalendarDay.self); try removeAll(Recipe.self)
                try removeAll(WaterEntry.self); try removeAll(WeightEntry.self); try removeAll(FoodProduct.self)
                try removeAll(FrequentMeal.self); try removeAll(GroceryCheck.self)
                try removeAll(UserProfile.self); try removeAll(NutritionGoal.self)
                context.insert(UserProfile()); context.insert(NutritionGoal())
            default: return
            }
            try context.save(); notice = "Los datos seleccionados se eliminaron."
        } catch { context.rollback(); notice = error.localizedDescription }
    }
    private func removeAll<T: PersistentModel>(_ type: T.Type) throws {
        for item in try context.fetch(FetchDescriptor<T>()) { context.delete(item) }
    }
}
