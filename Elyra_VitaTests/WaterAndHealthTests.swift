import SwiftData
import XCTest
@testable import Elyra_Vita

@MainActor
final class WaterAndHealthTests: XCTestCase {

    // MARK: - Wasser und SwiftData

    /// Prüft, dass Wasser gespeichert wird und nur der ausgewählte Tag summiert wird.
    func testWaterEntriesArePersistedAndAggregatedForSelectedDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20))
        )
        let followingDay = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 1, to: selectedDay)
        )

        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        context.insert(
            WaterEntry(
                date: calendar.date(byAdding: .hour, value: 9, to: selectedDay)!,
                amount: 250
            )
        )
        context.insert(
            WaterEntry(
                date: calendar.date(byAdding: .hour, value: 14, to: selectedDay)!,
                amount: 500
            )
        )
        context.insert(WaterEntry(date: followingDay, amount: 750))

        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        let selectedDayTotal = entries
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }
            .reduce(0) { $0 + $1.amount }

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(selectedDayTotal, 750)
    }

    // MARK: - Wasserziel

    /// Prüft die unteren und oberen Grenzen des Wasserziels.
    func testWaterGoalIsClampedToSupportedRange() {
        let tooSmall = UserSettings(waterGoalML: 100)
        let tooLarge = UserSettings(waterGoalML: 10_000)
        let valid = UserSettings(waterGoalML: 3_250)

        XCTAssertEqual(tooSmall.waterGoalML, 500)
        XCTAssertEqual(tooLarge.waterGoalML, 6_000)
        XCTAssertEqual(valid.waterGoalML, 3_250)
    }

    // MARK: - HealthMetrics

    /// Prüft die Addition von aktiver Energie und Ruheenergie.
    func testHealthMetricsCalculateTotalEnergy() {
        let metrics = HealthMetrics(
            steps: 8_000,
            walkingRunningDistanceKilometers: 5.2,
            activeEnergyKilocalories: 420,
            basalEnergyKilocalories: 1_650,
            weightKilograms: 72.4,
            proteinGrams: 120,
            carbohydratesGrams: 210,
            fatGrams: 70
        )

        XCTAssertEqual(metrics.totalEnergyKilocalories, 2_070)
        XCTAssertTrue(metrics.containsData)
    }

    /// Prüft den Leerzustand, der in der Tageswertekarte Platzhalter anzeigt.
    func testEmptyHealthMetricsContainNoData() {
        let metrics = HealthMetrics(
            steps: nil,
            walkingRunningDistanceKilometers: nil,
            activeEnergyKilocalories: nil,
            basalEnergyKilocalories: nil,
            weightKilograms: nil,
            proteinGrams: nil,
            carbohydratesGrams: nil,
            fatGrams: nil
        )

        XCTAssertFalse(metrics.containsData)
        XCTAssertNil(metrics.totalEnergyKilocalories)
    }

    // MARK: - Test-Hilfen

    /// Erstellt für jeden Test einen isolierten SwiftData-Speicher.
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([WaterEntry.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
