import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol AIService: Sendable {
    func analyzeMealPhoto(_ photo: Data?, description: String) async throws -> MealAnalysis
    func analyzeNutritionLabel(_ photo: Data) async throws -> FoodComponent
    func generateRecipes(prompt: String) async throws -> [RecipeData]
    func generateWeeklyPlan(prompt: String, recipes: [RecipeData]) async throws -> [[UUID]]
    func adjustMealAnalysis(_ analysis: MealAnalysis, correction: String) async throws -> MealAnalysis
    func recognizeFrequentMeal(_ analysis: MealAnalysis, candidates: [RecipeData]) async throws -> UUID?
}

public struct MockAIService: AIService {
    public init() {}
    public func analyzeMealPhoto(_ photo: Data?, description: String) async throws -> MealAnalysis {
        try await Task.sleep(for: .milliseconds(650))
        let result = MealAnalysis(mealName: description.isEmpty ? "Tacos de fajita · ejemplo" : description,
            items: [
                .init(name: "Tortilla de maíz", quantity: 3, unit: "unidad", perUnit: .init(calories: 35, protein: 1, carbs: 7, fat: 0.3)),
                .init(name: "Res magra", preparation: "A la plancha", quantity: 1, unit: "porción de 170 g", weightGrams: 170,
                      perUnit: .init(calories: 330, protein: 42, carbs: 0, fat: 18)),
                .init(name: "Cebolla, cilantro y jalapeño", perUnit: .init(calories: 35, protein: 1, carbs: 7, fat: 0))
            ], confidence: 0.65, uncertaintyFraction: 0.2,
            uncertainties: ["Modo demo: esta muestra no interpreta la foto ni la descripción.", "El aceite utilizado no puede estimarse visualmente."],
            followUpQuestions: ["¿Usaste aceite, mantequilla o manteca?"])
        try result.validate(); return result
    }
    public func analyzeNutritionLabel(_ photo: Data) async throws -> FoodComponent {
        throw AIServiceError.notAvailableInDemo
    }
    public func generateRecipes(prompt: String) async throws -> [RecipeData] { throw AIServiceError.notAvailableInDemo }
    public func generateWeeklyPlan(prompt: String, recipes: [RecipeData]) async throws -> [[UUID]] {
        throw AIServiceError.notAvailableInDemo
    }
    public func adjustMealAnalysis(_ analysis: MealAnalysis, correction: String) async throws -> MealAnalysis {
        // Free-form corrections require a real model; manual editing remains fully available.
        throw AIServiceError.notAvailableInDemo
    }
    public func recognizeFrequentMeal(_ analysis: MealAnalysis, candidates: [RecipeData]) async throws -> UUID? { nil }
}

public enum AIServiceError: Error, LocalizedError {
    case notAvailableInDemo, notImplemented, invalidEndpoint, server(Int)
    public var errorDescription: String? {
        switch self {
        case .notAvailableInDemo: "Esta función de IA estará disponible al conectar el backend. Podés editar los datos manualmente."
        case .notImplemented: "Esta función remota todavía no está implementada."
        case .invalidEndpoint: "El backend debe usar HTTPS."
        case .server(let code): "El servicio no pudo completar la solicitud (\(code))."
        }
    }
}

/// No OpenAI key belongs in the client. The backend must authenticate the user and limit usage.
public struct RemoteAIService: AIService {
    public let endpoint: URL
    public let sessionToken: String
    public init(endpoint: URL, sessionToken: String) throws {
        guard endpoint.scheme == "https" else { throw AIServiceError.invalidEndpoint }
        self.endpoint = endpoint; self.sessionToken = sessionToken
    }
    private struct PhotoRequest: Encodable { let photoBase64: String?; let description: String }
    public func analyzeMealPhoto(_ photo: Data?, description: String) async throws -> MealAnalysis {
        var request = URLRequest(url: endpoint.appendingPathComponent("v1/meals/analyze"))
        request.httpMethod = "POST"; request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(PhotoRequest(photoBase64: photo?.base64EncodedString(), description: description))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIServiceError.server((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try MealAnalysis.decodeValidated(data)
    }
    public func analyzeNutritionLabel(_ photo: Data) async throws -> FoodComponent { throw AIServiceError.notImplemented }
    public func generateRecipes(prompt: String) async throws -> [RecipeData] { throw AIServiceError.notImplemented }
    public func generateWeeklyPlan(prompt: String, recipes: [RecipeData]) async throws -> [[UUID]] { throw AIServiceError.notImplemented }
    public func adjustMealAnalysis(_ analysis: MealAnalysis, correction: String) async throws -> MealAnalysis { throw AIServiceError.notImplemented }
    public func recognizeFrequentMeal(_ analysis: MealAnalysis, candidates: [RecipeData]) async throws -> UUID? { throw AIServiceError.notImplemented }
}
