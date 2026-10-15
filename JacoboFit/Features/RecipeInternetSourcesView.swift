import SwiftUI

/// Source discovery links, not a claim that these pages or recipes have been fetched/verified.
struct RecipeInternetSourcesView: View {
    var ingredients: [String]
    private var terms: String { Array(Set(ingredients)).sorted().prefix(6).joined(separator: " ") }
    private func search(site: String) -> URL {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: "site:\(site) recipe \(terms)")]
        return components.url!
    }
    var body: some View {
        Surface {
            Label("IDEAS PARA COMER EQUILIBRADO", systemImage: "leaf").font(.caption.bold()).foregroundStyle(.teal)
            Text("Fuentes para explorar").font(.title3.bold())
            Text("Búsquedas preparadas con los ingredientes de tu lista. Abrí una fuente o pedile a ChatGPT que la consulte; todavía no verificamos recetas de esas páginas.").font(.footnote).foregroundStyle(.secondary)
            Link("Buscar en MyPlate · USDA", destination: search(site: "myplate.gov/recipes"))
            Link("Buscar en NHS · recetas familiares", destination: search(site: "nhs.uk/healthier-families/recipes"))
            Text("Una receta con fuente no garantiza que sea adecuada para todos. Revisá porciones, ingredientes y tus preferencias.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
