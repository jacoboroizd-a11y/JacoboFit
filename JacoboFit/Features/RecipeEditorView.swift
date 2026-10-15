import SwiftUI
import SwiftData
import NutritionCore

struct RecipeEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let existing: Recipe?
    @State private var draft: RecipeData
    @State private var stepsText: String
    @State private var error: String?
    init(existing: Recipe? = nil) {
        self.existing = existing
        let value = (try? existing?.value()) ?? RecipeData(name: "", nutrition: .zero,
            ingredients: [.init(name: "", quantity: 1, unit: "g", category: "otros")], steps: [])
        _draft = State(initialValue: value); _stepsText = State(initialValue: value.steps.joined(separator: "\n"))
    }
    var body: some View {
        Form {
            Section("Receta") {
                TextField("Nombre", text: $draft.name)
                Stepper("Porciones de la receta: \(draft.servings)", value: $draft.servings, in: 1...12)
                Stepper("Tiempo: \(draft.minutes) min", value: $draft.minutes, in: 5...240, step: 5)
                Picker("Dificultad", selection: $draft.difficulty) { ForEach(["Fácil", "Media", "Avanzada"], id: \.self) { Text($0) } }
            }
            Section("Nutrición de TODA la receta") {
                number("Calorías (kcal)", value: $draft.nutrition.calories)
                number("Proteína (g)", value: $draft.nutrition.protein)
                number("Carbohidratos (g)", value: $draft.nutrition.carbs)
                number("Grasas (g)", value: $draft.nutrition.fat)
                Text("Ingresá el total de las \(draft.servings) porciones. Al cocinar para otra cantidad, todos los valores se escalan proporcionalmente.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Ingredientes de toda la receta") {
                ForEach($draft.ingredients) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Ingrediente", text: $item.name)
                        HStack { TextField("Cantidad", value: $item.quantity, format: .number).keyboardType(.decimalPad); TextField("Unidad", text: $item.unit) }
                        Picker("Categoría", selection: $item.category) {
                            ForEach(["proteínas", "vegetales", "carbohidratos", "otros"], id: \.self) { Text($0.capitalized) }
                        }
                    }
                }.onDelete { draft.ingredients.remove(atOffsets: $0) }
                Button("Añadir ingrediente", systemImage: "plus") { draft.ingredients.append(.init(name: "", quantity: 1, unit: "g", category: "otros")) }
            }
            Section("Preparación · un paso por línea") { TextEditor(text: $stepsText).frame(minHeight: 130) }
        }.navigationTitle(existing == nil ? "Crear receta" : "Editar receta").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.bold() }
        }
        .alert("Revisá la receta", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
    private func number(_ name: String, value: Binding<Double>) -> some View {
        HStack { Text(name); Spacer(); TextField(name, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100) }
    }
    private func save() {
        do {
            draft.steps = stepsText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            try draft.validate()
            if existing?.isDraft == true && (draft.nutrition.calories <= 0 || draft.steps.contains(where: { $0.hasPrefix("Borrador:") })) {
                throw NutritionError.invalidValue("completá los pasos y la estimación de calorías del borrador")
            }
            if let existing {
                existing.isDraft = false
                existing.name = draft.name; existing.servings = draft.servings; existing.minutes = draft.minutes
                existing.difficulty = draft.difficulty; existing.steps = draft.steps
                existing.nutritionData = try JSONEncoder().encode(draft.nutrition)
                let previous = existing.ingredients
                existing.ingredients = draft.ingredients.map { RecipeIngredient($0) }
                for item in previous { context.delete(item) }
            } else { context.insert(try Recipe(draft)) }
            try context.save(); dismiss()
        } catch { context.rollback(); self.error = error.localizedDescription }
    }
}
