import Foundation

public enum NutritionError: Error, LocalizedError {
    case invalidValue(String)
    public var errorDescription: String? {
        switch self { case .invalidValue(let field): "Valor nutricional inválido: \(field)." }
    }
}

public struct Nutrients: Codable, Hashable, Sendable {
    public var calories: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public init(calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.calories = calories; self.protein = protein; self.carbs = carbs; self.fat = fat
    }
    public static let zero = Nutrients()
    public static func + (lhs: Self, rhs: Self) -> Self {
        .init(calories: lhs.calories + rhs.calories, protein: lhs.protein + rhs.protein,
              carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat)
    }
    public func scaled(by factor: Double) -> Self {
        .init(calories: calories * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor)
    }
    public func validate() throws {
        guard [calories, protein, carbs, fat].allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw NutritionError.invalidValue("calorías/macros")
        }
    }
}

public struct FoodComponent: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var brand: String
    public var preparation: String
    public var quantity: Double
    public var unit: String
    public var weightGrams: Double?
    /// Nutrition for one unit; quantities can be edited without compounding rounding errors.
    public var perUnit: Nutrients
    public var confidence: Double
    public var total: Nutrients { perUnit.scaled(by: quantity) }
    public init(id: UUID = UUID(), name: String, brand: String = "", preparation: String = "",
                quantity: Double = 1, unit: String = "porción", weightGrams: Double? = nil,
                perUnit: Nutrients, confidence: Double = 0.7) {
        self.id = id; self.name = name; self.brand = brand; self.preparation = preparation
        self.quantity = quantity; self.unit = unit; self.weightGrams = weightGrams
        self.perUnit = perUnit; self.confidence = confidence
    }
    public func validate() throws {
        try perUnit.validate()
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              quantity.isFinite, quantity > 0, quantity <= 10000,
              confidence.isFinite, (0...1).contains(confidence),
              weightGrams.map({ $0.isFinite && $0 >= 0 }) ?? true else {
            throw NutritionError.invalidValue("ingrediente")
        }
    }
}

public struct MealAnalysis: Codable, Equatable, Sendable {
    public var mealName: String
    public var items: [FoodComponent]
    public var confidence: Double
    public var uncertainties: [String]
    public var followUpQuestions: [String]
    /// Relative uncertainty survives human quantity corrections.
    public var uncertaintyFraction: Double
    public var total: Nutrients { items.reduce(.zero) { $0 + $1.total } }
    public var calorieRange: ClosedRange<Double> {
        max(0, total.calories * (1 - uncertaintyFraction))...total.calories * (1 + uncertaintyFraction)
    }
    public init(mealName: String, items: [FoodComponent], confidence: Double = 0.7,
                uncertaintyFraction: Double = 0.15, uncertainties: [String] = [], followUpQuestions: [String] = []) {
        self.mealName = mealName; self.items = items; self.confidence = confidence
        self.uncertaintyFraction = uncertaintyFraction; self.uncertainties = uncertainties
        self.followUpQuestions = followUpQuestions
    }
    public func validate() throws {
        guard !mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !items.isEmpty, items.count <= 100,
              Set(items.map(\.id)).count == items.count,
              confidence.isFinite, (0...1).contains(confidence),
              uncertaintyFraction.isFinite, (0...1).contains(uncertaintyFraction) else {
            throw NutritionError.invalidValue("análisis")
        }
        for item in items { try item.validate() }
        try total.validate()
    }
    public static func decodeValidated(_ data: Data) throws -> Self {
        let analysis = try JSONDecoder().decode(Self.self, from: data)
        try analysis.validate()
        return analysis
    }
}

public struct EnergyEstimate: Equatable, Sendable {
    public let totalExpenditure: Double
    /// Negative balance means an estimated deficit.
    public let balance: Double
}

public enum EstimatedTDEEService {
    /// HealthKit active energy already includes workouts and daily movement.
    /// Use workout energy ONLY as a fallback if active energy was unavailable.
    public static func estimate(restingEnergy: Double?, activeEnergy: Double?, workoutEnergy: Double = 0,
                                manualRestingEstimate: Double?, consumed: Double) -> EnergyEstimate? {
        guard let resting = restingEnergy ?? manualRestingEstimate, resting.isFinite, resting > 0,
              consumed.isFinite, consumed >= 0 else { return nil }
        let active = activeEnergy ?? workoutEnergy
        guard active.isFinite, active >= 0 else { return nil }
        return .init(totalExpenditure: resting + active, balance: consumed - resting - active)
    }
}
