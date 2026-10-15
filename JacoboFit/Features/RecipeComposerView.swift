import SwiftUI
import SwiftData
import UIKit
import NutritionCore

struct RecipeComposerView: View {
    var foodIdeas: String = ""
    @State private var lastAutomaticIdea = ""
    @Environment(\.openURL) private var openURL
    @State private var prompt = ""
    @State private var portions = 1
    @State private var minutes = 25
    @State private var response = ""
    @State private var suggestions: [RecipeData] = []
    @State private var error: String?
    @State private var copied = false
    @FocusState private var focused: Field?
    private enum Field: Hashable { case prompt, response }
    private var validRequest: Bool { (3...2500).contains(prompt.trimmingCharacters(in: .whitespacesAndNewlines).count) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Surface {
                Label("TU COCINA + CHATGPT", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.teal)
                Text("¿Qué querés comer?").font(.largeTitle.bold())
                Text("Contame qué tenés y armamos un pedido para tu ChatGPT.").font(.subheadline).foregroundStyle(.secondary)
                TextField("Voy a comer pollo cocido…", text: $prompt, axis: .vertical)
                    .lineLimit(3...6).padding(14).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                    .focused($focused, equals: .prompt).accessibilityIdentifier("recipe-prompt")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["Tengo pollo cocido", "Atún, yogurt y pepino", "Una cena alta en proteína"], id: \.self) { suggestion in
                            Button(suggestion) { prompt = suggestion; copied = false }.buttonStyle(.bordered)
                        }
                    }
                }
                Stepper("Para \(portions) persona(s)", value: $portions, in: 1...12)
                Stepper("Tengo \(minutes) minutos", value: $minutes, in: 10...120, step: 5)
                Button {
                    do {
                        let prepared = try ChatGPTRecipeExchange.makePrompt(idea: prompt, servings: portions, minutes: minutes)
                        UIPasteboard.general.string = prepared
                        copied = true; error = nil; focused = nil
                        openURL(URL(string: "https://chatgpt.com/")!)
                    } catch { self.error = error.localizedDescription }
                } label: {
                    Label("1. Copiar pedido y abrir ChatGPT", systemImage: "arrow.up.right.square").bold().padding(.vertical, 8)
                }.primaryActionStyle().disabled(!validRequest).accessibilityIdentifier("recipe-open-chatgpt")
                if copied { Label("Pedido copiado. Pegalo en ChatGPT y copiá el JSON de su respuesta.", systemImage: "checkmark.circle").font(.footnote).foregroundStyle(.teal) }
                Text("Usás tu cliente y tu suscripción de ChatGPT. JacoboFit no accede a tu cuenta ni hace llamadas de API.").font(.caption).foregroundStyle(.secondary)
            }
            Surface {
                Label("DE VUELTA EN JACOBOFIT", systemImage: "arrow.down.doc").font(.caption.bold()).foregroundStyle(.teal)
                Text("2. Pegá tu receta").font(.title2.bold())
                Text("Copiá la respuesta JSON que ChatGPT preparó para este pedido y pegala acá.").font(.subheadline).foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    if response.isEmpty { Text("La respuesta de ChatGPT…").foregroundStyle(.tertiary).padding(.top, 12).padding(.leading, 5).allowsHitTesting(false) }
                    TextEditor(text: $response).scrollContentBackground(.hidden).frame(minHeight: 150, maxHeight: 220)
                        .focused($focused, equals: .response).accessibilityLabel("Respuesta JSON de ChatGPT").accessibilityIdentifier("recipe-response")
                }.padding(8).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                PasteButton(payloadType: String.self) { values in
                    if let value = values.first { response = value; error = nil }
                }.labelStyle(.titleAndIcon)
                Button("Revisar recetas", systemImage: "checkmark.shield") {
                    do {
                        suggestions = try ChatGPTRecipeExchange.importRecipes(response)
                        error = nil; focused = nil
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } catch { suggestions = []; self.error = error.localizedDescription }
                }.primaryActionStyle().disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("recipe-import")
                if let error { Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.orange).textSelection(.enabled) }
                Text("El intercambio es manual. Revisamos el formato y los valores, pero las calorías siguen siendo estimaciones que podés corregir.").font(.caption).foregroundStyle(.secondary)
            }
            if !suggestions.isEmpty {
                Text("Tus propuestas de ChatGPT").font(.title2.bold())
                Text("Revisá los ingredientes y la preparación antes de guardar o planificar.").font(.footnote).foregroundStyle(.secondary)
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, recipe in
                    RecipeSuggestionView(recipe: recipe, recommended: index == 0)
                }
            }
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Listo") { focused = nil } } }
        .task(id: foodIdeas) {
            if !foodIdeas.isEmpty && (prompt.isEmpty || prompt == lastAutomaticIdea) { prompt = foodIdeas; lastAutomaticIdea = foodIdeas }
        }
        .onChange(of: prompt) { _, _ in copied = false }
        .onChange(of: portions) { _, _ in copied = false }
        .onChange(of: minutes) { _, _ in copied = false }
    }
}

private struct RecipeSuggestionView: View {
    @Environment(\.modelContext) private var context
    @Query private var savedRecipes: [Recipe]
    let recipe: RecipeData
    var recommended: Bool
    @State private var didSave = false
    @State private var showPlan = false
    @State private var showLog = false
    @State private var error: String?
    private var saved: Bool { didSave || savedRecipes.contains { $0.id == recipe.id } }
    private var analysis: MealAnalysis? {
        guard let portion = try? recipe.scaled(to: 1) else { return nil }
        return .init(mealName: recipe.name, items: [.init(name: recipe.name, quantity: 1, perUnit: portion.nutrition)],
                     uncertainties: ["Nutrición estimada por IA. Revisá los ingredientes y la porción."])
    }
    var body: some View {
        Surface {
            if recommended { Label("Sugerida para vos", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.teal) }
            Text(recipe.name).font(.title2.bold())
            Text("\(recipe.minutes) min · \(recipe.difficulty) · \(recipe.servings) porción(es)").font(.subheadline).foregroundStyle(.secondary)
            if let single = try? recipe.scaled(to: 1) {
                Text("~\(single.nutrition.calories.roundedText) kcal por porción").font(.headline).foregroundStyle(.teal)
                NutritionLine(nutrition: single.nutrition)
            }
            if let sources = recipe.sources, !sources.isEmpty {
                Text("Fuentes citadas por ChatGPT · verificá el contenido").font(.caption).foregroundStyle(.secondary)
                ForEach(sources, id: \.url) { source in Link(source.title, destination: source.url).font(.footnote) }
            }
            DisclosureGroup("Ingredientes y preparación") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recipe.ingredients) { item in Text("\(item.quantity.quantityText) \(item.unit) de \(item.name)") }
                    Divider()
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in Text("\(index + 1). \(step)") }
                }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
            }
            Button(saved ? "Guardada en mis recetas" : "Guardar receta", systemImage: saved ? "checkmark" : "heart") {
                do {
                    try recipe.validate()
                    if let draft = savedRecipes.first(where: { $0.isDraft && $0.name.localizedCaseInsensitiveCompare(recipe.name) == .orderedSame }) {
                        let old = draft.ingredients
                        draft.name = recipe.name; draft.servings = recipe.servings; draft.minutes = recipe.minutes
                        draft.nutritionData = try JSONEncoder().encode(recipe.nutrition)
                        draft.sourcesData = try JSONEncoder().encode(recipe.sources)
                        draft.steps = recipe.steps; draft.difficulty = recipe.difficulty; draft.isDraft = false
                        draft.ingredients = recipe.ingredients.map { RecipeIngredient($0) }
                        for item in old { context.delete(item) }
                    } else { context.insert(try Recipe(recipe)) }
                    try context.save(); didSave = true
                }
                catch { context.rollback(); self.error = error.localizedDescription }
            }.primaryActionStyle().disabled(saved)
            HStack {
                Button("Planificar", systemImage: "calendar.badge.plus") { showPlan = true }.buttonStyle(.bordered)
                Button("Registrar", systemImage: "fork.knife") { showLog = true }.buttonStyle(.bordered)
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .sheet(isPresented: $showPlan) { NavigationStack { PlanMealView(recipe: recipe) } }
        .sheet(isPresented: $showLog) { if let analysis { NavigationStack { MealEditorView(initial: analysis, original: nil, photo: nil) } } }
    }
}
