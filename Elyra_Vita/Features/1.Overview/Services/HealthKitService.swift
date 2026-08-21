import Foundation
import HealthKit

// MARK: - HealthKit-Datenmodell

// MARK: - Tageswerte

/// Bündelt die aus Apple Health gelesenen Werte eines einzelnen Tages.
struct HealthMetrics: Sendable {
    // MARK: - Messwerte

    let steps: Double?
    let walkingRunningDistanceKilometers: Double?
    let activeEnergyKilocalories: Double?
    let basalEnergyKilocalories: Double?
    let weightKilograms: Double?
    let proteinGrams: Double?
    let carbohydratesGrams: Double?
    let fatGrams: Double?

    var containsData: Bool {
        steps != nil ||
        walkingRunningDistanceKilometers != nil ||
        activeEnergyKilocalories != nil ||
        basalEnergyKilocalories != nil ||
        weightKilograms != nil ||
        proteinGrams != nil ||
        carbohydratesGrams != nil ||
        fatGrams != nil
    }

    /// Addiert aktive und Ruheenergie, sofern mindestens einer der Werte vorhanden ist.
    var totalEnergyKilocalories: Double? {
        guard activeEnergyKilocalories != nil || basalEnergyKilocalories != nil else {
            return nil
        }

        return (activeEnergyKilocalories ?? 0) + (basalEnergyKilocalories ?? 0)
    }
}

// MARK: - HealthKit-Service

/// Kapselt Berechtigungsanfrage und Tagesabfragen gegenüber Apple Health.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    /// Verhindert HealthKit-Aufrufe in isolierten Tests und Previews.
    static var isDisabledForCurrentProcess: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil ||
            environment["XCInjectBundleInto"] != nil ||
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ||
            environment["ELYRA_VITA_DISABLE_HEALTHKIT"] == "YES" ||
            ProcessInfo.processInfo.arguments.contains("--disable-healthkit")
    }

    // MARK: - Abhängigkeiten

    private let healthStore = HKHealthStore()

    private var authorizationWasRequested = false

    private init() {}

    // MARK: - Berechtigungen

    /// Liefert die HealthKit-Datentypen, die die Übersicht nur lesen möchte.
    private var readTypes: Set<HKObjectType> {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .distanceWalkingRunning,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .bodyMass,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal
        ]

        return Set(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
    }

    func requestAuthorization() async throws {
        guard !Self.isDisabledForCurrentProcess else { return }

        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.unavailable
        }

        guard !authorizationWasRequested else { return }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        authorizationWasRequested = true
    }

    // MARK: - Tagesabfrage

    /// Lädt alle unterstützten Gesundheitswerte für den ausgewählten Kalendertag.
    func metrics(for date: Date) async throws -> HealthMetrics {
        guard !Self.isDisabledForCurrentProcess else {
            return HealthMetrics(
                steps: nil,
                walkingRunningDistanceKilometers: nil,
                activeEnergyKilocalories: nil,
                basalEnergyKilocalories: nil,
                weightKilograms: nil,
                proteinGrams: nil,
                carbohydratesGrams: nil,
                fatGrams: nil
            )
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw HealthKitError.invalidDate
        }

        async let steps = valueOrNil(
            .stepCount,
            unit: .count(),
            start: start,
            end: end
        )
        async let distance = valueOrNil(
            .distanceWalkingRunning,
            unit: .meterUnit(with: .kilo),
            start: start,
            end: end
        )
        async let activeEnergy = valueOrNil(
            .activeEnergyBurned,
            unit: .kilocalorie(),
            start: start,
            end: end
        )
        async let basalEnergy = valueOrNil(
            .basalEnergyBurned,
            unit: .kilocalorie(),
            start: start,
            end: end
        )
        async let protein = valueOrNil(
            .dietaryProtein,
            unit: .gram(),
            start: start,
            end: end
        )
        async let carbohydrates = valueOrNil(
            .dietaryCarbohydrates,
            unit: .gram(),
            start: start,
            end: end
        )
        async let fat = valueOrNil(
            .dietaryFatTotal,
            unit: .gram(),
            start: start,
            end: end
        )

        return HealthMetrics(
            steps: await steps,
            walkingRunningDistanceKilometers: await distance,
            activeEnergyKilocalories: await activeEnergy,
            basalEnergyKilocalories: await basalEnergy,
            weightKilograms: await weightOrNil(on: date),
            proteinGrams: await protein,
            carbohydratesGrams: await carbohydrates,
            fatGrams: await fat
        )
    }

    // MARK: - Mengenabfragen

    /// Ein einzelner fehlender/gesperrter Datentyp darf die übrigen Werte nicht blockieren.
    private func valueOrNil(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        try? await cumulativeValue(
            identifier,
            unit: unit,
            start: start,
            end: end
        )
    }

    private func cumulativeValue(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(
                    returning: statistics?.sumQuantity()?.doubleValue(for: unit)
                )
            }

            self.healthStore.execute(query)
        }
    }

    private func latestWeight(on date: Date) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw HealthKitError.invalidDate
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let weight = (samples?.first as? HKQuantitySample)?.quantity
                    .doubleValue(for: .gram())

                continuation.resume(returning: weight.map { $0 / 1_000 })
            }

            self.healthStore.execute(query)
        }
    }

    /// Wandelt fehlende oder nicht freigegebene Gewichtsdaten in einen leeren Wert um.
    private func weightOrNil(on date: Date) async -> Double? {
        try? await latestWeight(on: date)
    }
}

// MARK: - Fehler

enum HealthKitError: LocalizedError {
    case unavailable
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health ist auf diesem Gerät nicht verfügbar."
        case .invalidDate:
            return "Das ausgewählte Datum konnte nicht verarbeitet werden."
        }
    }
}
