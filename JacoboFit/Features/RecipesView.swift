import SwiftUI
import SwiftData
import NutritionCore

struct RecipesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var search = ""
    @State private var onlyFavorites = false
    @State private var showCreate = false
    @State private var error: String?
    private var filtered: [Recipe] {
        recipes.filter { (!onlyFavorites || $0.favorite) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.ingredients.contains { $0.name.localizedCaseInsensitiveContains(search) }) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("¿Qué querés comer?").font(.largeTitle.bold())
                TextField("Buscá pollo, atún, tacos…", text: $search).textFieldStyle(.roundedBorder)
                Text("En modo demo podés buscar por nombre o ingrediente, crear recetas y editar los ejemplos. Las sugerencias con IA llegarán al conectar el backend.").font(.footnote).foregroundStyle(.secondary)
                Toggle("Solo mis favoritas", isOn: $onlyFavorites)
                HStack {
                    Button("Crear receta", systemImage: "plus") { showCreate = true }.buttonStyle(.borderedProminent)
                    Menu {
                        Button("Cargar 9 recetas de ejemplo") {
                            do { try DemoData.loadRecipes(into: context) } catch { context.rollback(); self.error = error.localizedDescription }
                        }
                    } label: { Image(systemName: "ellipsis.circle").font(.title2).padding(8) }.accessibilityLabel("Opciones de recetas")
                }
                if recipes.isEmpty {
                    ContentUnavailableView("Tu cocina, a tu manera", systemImage: "book.closed", description: Text("Creá una receta o cargá ejemplos editables desde el botón de opciones."))
                    Button("Empezar con recetas de ejemplo") {
                        do { try DemoData.loadRecipes(into: context) } catch { context.rollback(); self.error = error.localizedDescription }
                    }.buttonStyle(.bordered)
                } else if filtered.isEmpty { ContentUnavailableView.search(text: search) }
                ForEach(filtered) { recipe in
                    NavigationLink { RecipeDetailView(recipe: recipe) } label: {
                        Surface {
                            FoodImage(symbol: recipe.symbol, height: 140)
                            HStack { Text(recipe.name).font(.title3.bold()).foregroundStyle(.primary); Spacer(); if recipe.favorite { Image(systemName: "heart.fill").foregroundStyle(.pink) } }
                            if let data = try? recipe.value(), let portion = try? data.scaled(to: 1) {
                                Text("~\(portion.nutrition.calories.roundedText) kcal · \(recipe.minutes) min · \(recipe.difficulty)").font(.subheadline).foregroundStyle(.secondary)
                                NutritionLine(nutrition: portion.nutrition)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle("Recetas").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreate) { NavigationStack { RecipeEditorView() } }
        .alert("Recetas", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
}

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var portions = 1
    @State private var showPlan = false
    @State private var showLog = false
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var error: String?
    private var value: RecipeData? { try? recipe.value().scaled(to: portions) }
    private var mealAnalysis: MealAnalysis? {
        guard let single = try? recipe.value().scaled(to: 1) else { return nil }
        return .init(mealName: recipe.name, items: [.init(name: recipe.name, quantity: Double(portions), perUnit: single.nutrition)],
                     confidence: 0.7, uncertainties: ["Valores estimados de receta. Ajustá tu porción antes de guardar."])
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                FoodImage(symbol: recipe.symbol, height: 200)
                Text(recipe.name).font(.largeTitle.bold())
                Text("\(recipe.minutes) min · \(recipe.difficulty)").foregroundStyle(.secondary)
                Stepper("Cocinar para \(portions)", value: $portions, in: 1...12)
                if let value {
                    Surface {
                        Text("~\(value.nutrition.calories.roundedText) kcal en total").font(.title2.bold()).foregroundStyle(.teal)
                        NutritionLine(nutrition: value.nutrition)
                        Text("\(portions) porción(es) · cantidades escaladas").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Ingredientes").font(.title2.bold())
                    ForEach(value.ingredients) { item in
                        HStack { Text(item.name); Spacer(); Text("\(item.quantity.quantityText) \(item.unit)").foregroundStyle(.secondary) }
                    }
                    Text("Preparación").font(.title2.bold())
                    ForEach(Array(value.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) { Text("\(index + 1)").bold().foregroundStyle(.teal); Text(step) }
                    }
                    Button("Agregar al calendario", systemImage: "calendar.badge.plus") { showPlan = true }.buttonStyle(.borderedProminent)
                    Button("Registrar como comida", systemImage: "fork.knife") { showLog = true }.buttonStyle(.bordered)
                    Text("Registrar abre la revisión: elegí cuántas porciones comiste. Cocinar para dos no implica que hayas comido ambas.").font(.caption).foregroundStyle(.secondary)
                } else { Text("No se pudieron leer los datos de esta receta.").foregroundStyle(.red) }
                Button(recipe.favorite ? "Quitar de favoritas" : "Guardar en favoritas", systemImage: recipe.favorite ? "heart.fill" : "heart") {
                    recipe.favorite.toggle(); save()
                }
                Button("Editar receta", systemImage: "pencil") { showEdit = true }
                Button("Eliminar receta", role: .destructive) { confirmDelete = true }
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle("Receta").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPlan) { if let value { NavigationStack { PlanMealView(recipe: value) } } }
        .sheet(isPresented: $showLog) { if let mealAnalysis { NavigationStack { MealEditorView(initial: mealAnalysis, original: nil, photo: nil) } } }
        .sheet(isPresented: $showEdit) { NavigationStack { RecipeEditorView(existing: recipe) } }
        .confirmationDialog("¿Eliminar esta receta? Los planes conservan su copia.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { context.delete(recipe); do { try context.save(); dismiss() } catch { context.rollback(); self.error = error.localizedDescription } }
        }
        .alert("Receta", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
    private func save() { do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription } }
}
