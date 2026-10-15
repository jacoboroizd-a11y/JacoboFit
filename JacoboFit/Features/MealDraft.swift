import Foundation
import Observation
import NutritionCore

@MainActor @Observable final class MealDraft {
    var photo: Data?
    var description = ""
    var analysis: MealAnalysis?
    var original: MealAnalysis?
    var isAnalyzing = false
    var error: String?
    var category = "Almuerzo"
    private let ai: any AIService
    init(ai: any AIService = MockAIService()) { self.ai = ai }
    func analyze() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true; error = nil
        defer { isAnalyzing = false }
        do {
            let result = try await ai.analyzeMealPhoto(photo, description: description)
            try Task.checkCancellation()
            try result.validate()
            original = result; analysis = result
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
    func reset() {
        photo = nil; description = ""; original = nil; analysis = nil; error = nil
    }
}
