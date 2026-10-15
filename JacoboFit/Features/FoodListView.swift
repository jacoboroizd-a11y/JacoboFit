import SwiftUI
import SwiftData
import NutritionCore

struct FoodListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var showAdd = false
    @State private var editing: Recipe?
    @State private var showShopping = false
    @State private var error: String?
    private var meals: [Recipe] { recipes.filter(\.inFoodList) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("¿Qué vas a comer?").font(.largeTitle.bold())
                Text("Armá tu lista de platos y sus ingredientes. Cada plato aparece también como borrador en Recetas.").foregroundStyle(.secondary)
                Button("Agregar a mis comidas", systemImage: "plus") { showAdd = true }.primaryActionStyle()
                Button("Lista del súper", systemImage: "basket") { showShopping = true }.buttonStyle(.bordered).disabled(meals.isEmpty)
                NavigationLink { MealLoggingView() } label: { Label("Registrar comida con foto", systemImage: "camera") }.font(.headline)
                if meals.isEmpty { ContentUnavailableView("Tu menú empieza acá", systemImage: "fork.knife", description: Text("Por ejemplo: pollo cocido con arroz. Añadí sus ingredientes y cantidades para crear tu lista del súper.")) }
                ForEach(meals) { recipe in
                    Surface {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(recipe.name).font(.title3.bold())
                                Text("\(recipe.shoppingServings) porción(es) · \(recipe.ingredients.count) ingredientes").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Button { editing = recipe } label: { Image(systemName: "pencil") }.accessibilityLabel("Editar \(recipe.name)")
                        }
                        ForEach(recipe.ingredients.prefix(5)) { item in Text("\(item.quantity.quantityText) \(item.unit) · \(item.name)").font(.subheadline) }
                        if recipe.ingredients.count > 5 { Text("Y \(recipe.ingredients.count - 5) ingredientes más").font(.caption).foregroundStyle(.secondary) }
                        Button("Quitar de esta lista", role: .destructive) {
                            recipe.inFoodList = false
                            do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
                        }.font(.caption)
                    }
                }
                Text("En Recetas encontrarás tus borradores y un pedido de ChatGPT preparado con esta lista para completar recetas y consultar fuentes de internet.").font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }.background { AppBackdrop() }.navigationTitle("Comida").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) { NavigationStack { FoodListEditor() } }
        .sheet(item: $editing) { recipe in NavigationStack { FoodListEditor(existing: recipe) } }
        .sheet(isPresented: $showShopping) {
            NavigationStack {
                FoodShoppingSheet(recipes: meals)
            }
        }
        .alert("Lista de comidas", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
}

private struct FoodShoppingSheet: View {
    let recipes: [Recipe]
    var body: some View {
        if let plans = try? recipes.map({ RecipePlan(recipe: try $0.value(), portions: $0.shoppingServings) }) {
            GroceryView(days: [], weekStart: .now, foodPlans: plans)
        } else { ContentUnavailableView("Revisá los ingredientes", systemImage: "exclamationmark.triangle", description: Text("No se pudo leer una comida. Editala antes de generar la lista.")) }
    }
}

struct FoodListEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var existing: Recipe?
    @State private var name = ""
    @State private var servings = 1
    @State private var ingredients: [Ingredient] = [.init(name: "", quantity: 1, unit: "g", category: "proteínas")]
    @State private var error: String?
    var body: some View {
        Form {
            Section("Qué vas a comer") {
                TextField("Pollo cocido con arroz…", text: $name)
                Stepper("Para \(servings) persona(s)", value: $servings, in: 1...12)
            }
            Section("Ingredientes para todas esas porciones") {
                ForEach($ingredients) { $item in
                    VStack(spacing: 8) {
                        TextField("Ingrediente", text: $item.name)
                        HStack { TextField("Cantidad", value: $item.quantity, format: .number).keyboardType(.decimalPad); TextField("Unidad (g, unidad, taza…)", text: $item.unit) }
                        Picker("Grupo", selection: $item.category) { ForEach(["proteínas", "vegetales", "carbohidratos", "otros"], id: \.self) { Text($0.capitalized) } }
                    }
                }.onDelete { ingredients.remove(atOffsets: $0) }
                Button("Agregar ingrediente", systemImage: "plus") { ingredients.append(.init(name: "", quantity: 1, unit: "g", category: "otros")) }
            }
            Section { Text("Guardamos una receta borrador con estos ingredientes. Completá su preparación y estimaciones en Recetas; no inventamos calorías para un plato sin analizar.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle(existing == nil ? "Agregar comida" : "Editar comida").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let existing { name = existing.name; servings = existing.shoppingServings; ingredients = (try? existing.value().scaled(to: servings).ingredients) ?? existing.ingredients.map(\.value) }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                do {
                    let value = RecipeData(name: name, servings: servings, nutrition: .zero, ingredients: ingredients,
                        steps: ["Borrador: completá los pasos con ChatGPT o editando la receta antes de cocinar."])
                    try value.validate()
                    let recipe: Recipe
                    if let existing {
                        recipe = existing
                        let old = recipe.ingredients
                        recipe.name = name; recipe.servings = servings; recipe.ingredients = ingredients.map { RecipeIngredient($0) }
                        recipe.nutritionData = try JSONEncoder().encode(Nutrients.zero); recipe.steps = value.steps; recipe.sourcesData = nil
                        for item in old { context.delete(item) }
                    } else { recipe = try Recipe(value); context.insert(recipe) }
                    recipe.inFoodList = true; recipe.shoppingServings = servings; recipe.isDraft = true
                    try context.save(); dismiss()
                } catch { context.rollback(); self.error = error.localizedDescription }
            }.bold() }
        }
        .alert("Revisá tu comida", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
}
