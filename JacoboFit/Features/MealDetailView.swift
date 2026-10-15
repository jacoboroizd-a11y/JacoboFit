import SwiftUI
import SwiftData
import NutritionCore

struct MealDetailView: View {
    @Bindable var meal: Meal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FoodImage(data: meal.photo, height: 270)
                Text(meal.name).font(.largeTitle.bold())
                Text("\(meal.category) · \(meal.date.formatted())").foregroundStyle(.secondary)
                Surface {
                    Text("~\(meal.total.calories.roundedText) kcal").font(.largeTitle.bold()).foregroundStyle(.teal)
                    NutritionLine(nutrition: meal.total)
                    if let analysis = meal.analysis {
                        Text("Rango estimado: \(analysis.calorieRange.lowerBound.roundedText)–\(analysis.calorieRange.upperBound.roundedText) kcal")
                        ForEach(analysis.items) { item in
                            HStack { Text("\(item.quantity.quantityText) \(item.unit) · \(item.name)"); Spacer(); Text("~\(item.total.calories.roundedText)") }.font(.subheadline)
                        }
                        ForEach(analysis.uncertainties, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                if let original = try? MealAnalysis.decodeValidated(meal.originalAnalysis) {
                    DisclosureGroup("Análisis original y correcciones") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Original: ~\(original.total.calories.roundedText) kcal")
                            Text("Guardado: ~\(meal.total.calories.roundedText) kcal")
                            ForEach(original.items) { item in Text("\(item.name): \(item.quantity.quantityText) \(item.unit)").font(.caption) }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    }
                }
                if meal.photo != nil { Button("Eliminar solo la foto", role: .destructive) {
                    meal.photo = nil
                    do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
                } }
                Button("Eliminar comida", role: .destructive) { confirmDelete = true }
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle("Detalle").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Eliminar esta comida y su foto?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                context.delete(meal)
                do { try context.save(); dismiss() } catch { context.rollback(); self.error = error.localizedDescription }
            }
        }
        .alert("No se pudo guardar el cambio", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Cerrar") { error = nil }
        } message: { Text(error ?? "") }
    }
}
