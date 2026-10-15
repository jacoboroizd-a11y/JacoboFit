import SwiftUI
import UIKit
import SwiftData
import NutritionCore

struct MealEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var analysis: MealAnalysis
    private let original: MealAnalysis?
    private let photo: Data?
    private let onSave: () -> Void
    @State private var category: String
    @State private var date = Date.now
    @State private var editedItem: FoodComponent?
    @State private var error: String?
    @State private var quickAddition: String?
    init(initial: MealAnalysis, original: MealAnalysis?, photo: Data?, category: String = "Almuerzo", onSave: @escaping () -> Void = {}) {
        _analysis = State(initialValue: initial); self.original = original
        self.photo = photo; _category = State(initialValue: category); self.onSave = onSave
    }
    var body: some View {
        List {
            if photo != nil { Section { FoodImage(data: photo, height: 200).listRowInsets(EdgeInsets()) } }
            Section("Tu estimación") {
                TextField("Nombre de la comida", text: $analysis.mealName)
                Picker("Momento", selection: $category) {
                    ForEach(["Desayuno", "Almuerzo", "Cena", "Snack"], id: \.self) { Text($0) }
                }
                DatePicker("Fecha y hora", selection: $date, in: ...Date.now)
                Text("~\(analysis.total.calories.roundedText) kcal").font(.largeTitle.bold()).foregroundStyle(.teal)
                NutritionLine(nutrition: analysis.total)
                Text("Rango: \(analysis.calorieRange.lowerBound.roundedText)–\(analysis.calorieRange.upperBound.roundedText) kcal")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Confianza del análisis original: \((analysis.confidence * 100).roundedText)%").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                ForEach(analysis.items) { item in
                    Button { editedItem = item } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).foregroundStyle(.primary)
                                Text("\(item.quantity.quantityText) \(item.unit) · \(item.brand) \(item.preparation)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Text("~\(item.total.calories.roundedText)").foregroundStyle(.teal)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.onDelete { analysis.items.remove(atOffsets: $0) }
                Button { editedItem = FoodComponent(name: "", perUnit: .zero) } label: { Label("Añadir alimento", systemImage: "plus") }
            } header: { Text("Detecté esto · tocá para corregir") } footer: {
                Text("Las cantidades y macros son aproximados. Podés cambiar marca, preparación y valores por unidad.")
            }
            Section("Calorías que suelen pasar desapercibidas") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["Aceite", "Mantequilla", "Manteca", "Salsa", "Queso", "Aderezo"], id: \.self) { name in
                            Button("+ \(name)") { quickAddition = name }.buttonStyle(.bordered)
                        }
                    }
                }
                ForEach(analysis.uncertainties, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                ForEach(analysis.followUpQuestions, id: \.self) { Label($0, systemImage: "questionmark.circle").font(.subheadline) }
            }
        }
        .navigationTitle("Revisá tu comida").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.bold().disabled(analysis.items.isEmpty || analysis.mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .sheet(item: $editedItem) { item in
            NavigationStack { ComponentEditor(component: item) { result in
                if let index = analysis.items.firstIndex(where: { $0.id == result.id }) { analysis.items[index] = result }
                else { analysis.items.append(result) }
            } }
        }
        .confirmationDialog("Cantidad de \(quickAddition ?? "")", isPresented: Binding(get: { quickAddition != nil }, set: { if !$0 { quickAddition = nil } }), titleVisibility: .visible) {
            Button("½ cucharadita") { addQuick(factor: 1.0 / 6.0) }
            Button("1 cucharadita") { addQuick(factor: 1.0 / 3.0) }
            Button("1 cucharada") { addQuick(factor: 1) }
            Button("Otra cantidad / editar valores") { addQuick(factor: 1, edit: true) }
            Button("Cancelar", role: .cancel) { quickAddition = nil }
        } message: { Text("Valores orientativos por cucharada. Revisá la etiqueta si la tenés.") }
        .alert("No se pudo guardar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Cerrar") { error = nil }
        } message: { Text(error ?? "") }
    }
    private func addQuick(factor: Double, edit: Bool = false) {
        let name = quickAddition ?? "Aceite"
        let values: [String: Nutrients] = [
            "Aceite": .init(calories: 120, fat: 14), "Mantequilla": .init(calories: 102, fat: 11.5),
            "Manteca": .init(calories: 115, fat: 12.8), "Salsa": .init(calories: 10, carbs: 2),
            "Queso": .init(calories: 55, protein: 3.5, carbs: 0.5, fat: 4.5),
            "Aderezo": .init(calories: 65, carbs: 1, fat: 6.5)
        ]
        let item = FoodComponent(name: name, quantity: factor, unit: "cucharada", perUnit: values[name] ?? .zero, confidence: 0.5)
        quickAddition = nil
        if edit { editedItem = item } else { analysis.items.append(item) }
    }
    private func save() {
        do {
            try analysis.validate()
            let meal = try Meal(date: date, category: category, photo: photo, original: original ?? analysis, final: analysis)
            context.insert(meal); try context.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSave(); dismiss()
        } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

struct ComponentEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodProduct.name) private var products: [FoodProduct]
    @State var component: FoodComponent
    var onSave: (FoodComponent) -> Void
    @State private var saveFrequent = false
    @State private var error: String?
    var body: some View {
        Form {
            if !products.isEmpty {
                Section("Mis alimentos frecuentes") {
                    Menu("Usar un producto guardado") {
                        ForEach(products) { product in
                            Button("\(product.brand) \(product.name)") {
                                do {
                                    component.name = product.name; component.brand = product.brand; component.unit = product.portion
                                    component.perUnit = try JSONDecoder().decode(Nutrients.self, from: product.nutritionData)
                                } catch { self.error = error.localizedDescription }
                            }
                        }
                    }
                }
            }
            Section("Alimento") {
                TextField("Nombre", text: $component.name)
                TextField("Marca (opcional)", text: $component.brand)
                TextField("Preparación", text: $component.preparation)
                TextField("Unidad: tortilla, cucharada, porción…", text: $component.unit)
                numeric("Cantidad", value: $component.quantity)
                HStack {
                    Text("Ajustar cantidad")
                    Spacer()
                    Button { component.quantity = max(0.5, component.quantity - 0.5) } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel("Reducir cantidad").accessibilityIdentifier("quantity-decrease").buttonStyle(.borderless)
                    Text(component.quantity.quantityText).monospacedDigit().frame(minWidth: 36)
                    Button { component.quantity = min(10000, component.quantity + 0.5) } label: { Image(systemName: "plus.circle") }
                        .accessibilityLabel("Aumentar cantidad").accessibilityIdentifier("quantity-increase").buttonStyle(.borderless)
                }
            }
            Section("Valores por UNA unidad") {
                numeric("kcal", value: $component.perUnit.calories)
                numeric("Proteína (g)", value: $component.perUnit.protein)
                numeric("Carbohidratos (g)", value: $component.perUnit.carbs)
                numeric("Grasas (g)", value: $component.perUnit.fat)
            }
            Section {
                Text("Total: ~\(component.total.calories.roundedText) kcal")
                Toggle("Guardar como alimento frecuente", isOn: $saveFrequent)
            }
        }.navigationTitle("Editar alimento").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Listo") {
                do {
                    try component.validate()
                    if saveFrequent { context.insert(try FoodProduct(component: component)); try context.save() }
                    onSave(component); dismiss()
                } catch { context.rollback(); self.error = error.localizedDescription }
            }.bold() }
        }
        .alert("Revisá los valores", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Cerrar") { error = nil }
        } message: { Text(error ?? "") }
    }
    private func numeric(_ label: String, value: Binding<Double>) -> some View {
        HStack { Text(label); Spacer(); TextField(label, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110) }
    }
}
