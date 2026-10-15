import SwiftUI
import SwiftData
import NutritionCore

struct GroceryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var checks: [GroceryCheck]
    let days: [CalendarDay]
    let weekStart: Date
    var foodPlans: [RecipePlan]? = nil
    @State private var error: String?
    private var prefix: String {
        if foodPlans != nil { return "food-list|" }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: weekStart)
        return "\(components.year!)-\(components.month!)-\(components.day!)|"
    }
    private var result: Result<[GroceryItem], Error> {
        Result {
            if let foodPlans { return try GroceryService.list(for: foodPlans) }
            let plans = try days.flatMap(\.meals).map { meal in
                guard let recipe = meal.recipe else { throw NutritionError.invalidValue("receta planificada") }
                return RecipePlan(recipe: recipe, portions: meal.portions)
            }
            return try GroceryService.list(for: plans)
        }
    }
    var body: some View {
        List {
            switch result {
            case .failure(let error):
                ContentUnavailableView("No se pudo calcular la lista", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
            case .success(let items):
                if items.isEmpty { ContentUnavailableView("Tu lista empieza con el plan", systemImage: "basket", description: Text(foodPlans == nil ? "Agregá recetas al calendario de esta semana." : "Agregá ingredientes a tus comidas.")) }
                ForEach(Array(Set(items.map(\.category))).sorted(), id: \.self) { category in
                    Section(category.capitalized) {
                        ForEach(items.filter { $0.category == category }) { item in
                            let isChecked = checks.contains { $0.key == checkKey(item) }
                            Button { toggle(item) } label: {
                                HStack {
                                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle").foregroundStyle(isChecked ? .teal : .secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name.capitalized).strikethrough(isChecked).foregroundStyle(.primary)
                                        Text("\(item.quantity.quantityText) \(item.unit)").font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }.accessibilityLabel("\(item.name), \(item.quantity.quantityText) \(item.unit), \(isChecked ? "comprado" : "pendiente")")
                        }
                    }
                }
                Section { Text("Las cantidades se consolidan por ingrediente y unidad. Revisá lo que ya tenés; las unidades diferentes se muestran por separado.").font(.footnote).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Lista del súper")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        .alert("No se pudo guardar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
    private func checkKey(_ item: GroceryItem) -> String { prefix + item.id + (foodPlans == nil ? "" : "|\(item.quantity)") }
    private func toggle(_ item: GroceryItem) {
        let key = checkKey(item)
        let matches = checks.filter { $0.key == key }
        if matches.isEmpty { context.insert(GroceryCheck(key: key)) }
        else { for check in matches { context.delete(check) } }
        do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
    }
}
