import Foundation
import HealthKit
import Observation

struct DailyActivity {
    var activeCalories: Double?
    var restingCalories: Double?
    var steps: Double?
    var kilometers: Double?
    var exerciseMinutes: Double?
    var latestWeightLB: Double?
    var workouts: [WorkoutSummary] = []
}

struct WorkoutSummary: Identifiable {
    var id: UUID
    var name: String
    var minutes: Double
    var calories: Double?
}

@MainActor @Observable final class HealthKitService {
    private let store = HKHealthStore()
    var activity = DailyActivity()
    var isLoading = false
    var message: String?
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    private let identifiers: [HKQuantityTypeIdentifier] = [
        .activeEnergyBurned, .basalEnergyBurned, .stepCount,
        .distanceWalkingRunning, .appleExerciseTime, .bodyMass
    ]

    func connect() async {
        guard isAvailable else { message = "Apple Health no está disponible en este dispositivo. La app funciona sin conectarlo."; return }
        isLoading = true
        defer { isLoading = false }
        do {
            var readTypes = Set<HKObjectType>(identifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) as HKObjectType? })
            readTypes.insert(HKObjectType.workoutType())
            try await store.requestAuthorization(toShare: [], read: readTypes)
            await refresh()
        } catch { message = error.localizedDescription }
    }

    func refresh() async {
        guard isAvailable else { return }
        do {
            let start = Calendar.current.startOfDay(for: .now)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
            var result = DailyActivity()
            result.activeCalories = try await sum(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
            result.restingCalories = try await sum(.basalEnergyBurned, unit: .kilocalorie(), predicate: predicate)
            result.steps = try await sum(.stepCount, unit: .count(), predicate: predicate)
            result.kilometers = try await sum(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), predicate: predicate)
            result.exerciseMinutes = try await sum(.appleExerciseTime, unit: .minute(), predicate: predicate)
            result.latestWeightLB = try await latestWeight()
            result.workouts = try await workouts(predicate: predicate)
            activity = result
            message = "Los permisos de lectura son privados: un dato vacío puede significar que no hay muestras o que no se compartió."
        } catch { message = "No se pudieron actualizar todos los datos: \(error.localizedDescription)" }
    }

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error as? HKError, error.code == .errorNoData { continuation.resume(returning: nil) }
                else if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit)) }
            }
            store.execute(query)
        }
    }

    private func latestWeight() async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .pound())) }
            }
            store.execute(query)
        }
    }

    private func workouts(predicate: NSPredicate) async throws -> [WorkoutSummary] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let activeType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let result = (samples as? [HKWorkout] ?? []).map { workout in
                    WorkoutSummary(id: workout.uuid, name: Self.name(workout.workoutActivityType), minutes: workout.duration / 60,
                        calories: workout.statistics(for: activeType)?.sumQuantity()?.doubleValue(for: .kilocalorie()))
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    nonisolated private static func name(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: "Caminata"
        case .running: "Carrera"
        case .cycling: "Ciclismo"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Fuerza"
        case .swimming: "Natación"
        case .yoga: "Yoga"
        default: "Entrenamiento"
        }
    }
}
