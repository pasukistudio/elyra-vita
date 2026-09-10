import Foundation

/// Bündelt die aus Apple Health gelesenen Werte eines einzelnen Tages.
struct HealthMetrics: Sendable {
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

struct DailyHealthValues {
    let steps: [Date: Double]?
    let distance: [Date: Double]?
    let activeEnergy: [Date: Double]?
    let basalEnergy: [Date: Double]?
    let protein: [Date: Double]?
    let carbohydrates: [Date: Double]?
    let fat: [Date: Double]?
    let weight: [Date: Double]?
}

func makeDailyMetrics(
    from start: Date,
    to end: Date,
    values: DailyHealthValues
) -> [Date: HealthMetrics] {
    let calendar = Calendar.current
    var result: [Date: HealthMetrics] = [:]
    var date = calendar.startOfDay(for: start)

    while date < end {
        let metrics = HealthMetrics(
            steps: values.steps?[date],
            walkingRunningDistanceKilometers: values.distance?[date],
            activeEnergyKilocalories: values.activeEnergy?[date],
            basalEnergyKilocalories: values.basalEnergy?[date],
            weightKilograms: values.weight?[date],
            proteinGrams: values.protein?[date],
            carbohydratesGrams: values.carbohydrates?[date],
            fatGrams: values.fat?[date]
        )

        if metrics.containsData {
            result[date] = metrics
        }

        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
            break
        }
        date = nextDate
    }

    return result
}
