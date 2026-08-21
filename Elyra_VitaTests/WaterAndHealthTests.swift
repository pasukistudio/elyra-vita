import SwiftData
import XCTest
import PasukiUI
@testable import Elyra_Vita

// MARK: - WaterAndHealthTests

/// Isolierte Tests für Wasser-, Ziel- und Health-Metriklogik.
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

    /// Prüft, dass ein Wassereintrag getrennte Erstellungs- und
    /// Änderungszeitpunkte mitbringt.
    func testWaterEntryStoresSynchronizationTimestamps() throws {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let entry = WaterEntry(date: createdAt, amount: 330)

        XCTAssertGreaterThanOrEqual(entry.createdAt, createdAt)
        XCTAssertEqual(entry.createdAt, entry.updatedAt)
    }

    /// Prüft, dass eine fachliche Änderung den Änderungszeitpunkt aktualisiert.
    func testWaterEntryUpdatesTimestampWhenEdited() {
        let entry = WaterEntry(amount: 330)
        let originalUpdatedAt = entry.updatedAt

        entry.update(amount: 500)

        XCTAssertEqual(entry.amount, 500)
        XCTAssertGreaterThanOrEqual(entry.updatedAt, originalUpdatedAt)
    }

    /// Prüft das Löschen eines Wassereintrags aus dem lokalen SwiftData-Store.
    func testWaterEntryCanBeDeleted() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let entry = WaterEntry(amount: 500)

        context.insert(entry)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<WaterEntry>()).count, 1)

        context.delete(entry)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<WaterEntry>()).isEmpty)
    }

    // MARK: - Gewicht

    /// Prüft Zeitstempel, Änderung und Löschung einer Gewichtsmessung.
    func testWeightEntrySupportsUpdatesAndDeletion() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weightKilograms: 72.5)
        let originalUpdatedAt = entry.updatedAt

        context.insert(entry)
        try context.save()
        entry.update(weightKilograms: 72.2)
        XCTAssertGreaterThanOrEqual(entry.updatedAt, originalUpdatedAt)

        context.delete(entry)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<WeightEntry>()).isEmpty)
    }

    /// Prüft die fachliche Regel: Ein Kalendertag besitzt genau eine Messung.
    func testWeightEntryKeepsOneMeasurementPerCalendarDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21))
        )
        let measurementDate = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: 8, to: selectedDay)
        )
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(date: measurementDate, weightKilograms: 72.5)

        context.insert(entry)
        try context.save()

        // Eine zweite Eingabe für denselben Tag ersetzt den bestehenden Wert.
        entry.update(weightKilograms: 72.1)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weightKilograms, 72.1)
        XCTAssertEqual(entries.first?.date, measurementDate)
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

    // MARK: - Gemeinsame UI-Konfiguration

    /// Prüft, dass die beiden Bereiche ihre vorgesehenen Plus-Menüs erhalten.
    func testToolbarActionsMatchOverviewAndNutrition() {
        XCTAssertEqual(
            SharedToolbarAction.overview,
            [.meal, .water, .weight]
        )
        XCTAssertEqual(
            SharedToolbarAction.nutrition,
            [.breakfast, .lunch, .dinner, .snack, .water]
        )
    }

    // MARK: - Gesundheitstrends

    /// Prüft die gemeinsamen Trendzeiträume.
    func testHealthTrendRangesUseExpectedDurations() {
        XCTAssertEqual(HealthTrendRange.week.days, 7)
        XCTAssertEqual(HealthTrendRange.month.days, 30)
        XCTAssertEqual(HealthTrendRange.threeMonths.days, 90)
        XCTAssertEqual(HealthTrendRange.year.days, 365)
    }

    /// Prüft, dass lokale und Apple-Health-Metriken klar getrennt bleiben.
    func testHealthTrendMetricsDeclareTheirDataSource() {
        XCTAssertTrue(HealthTrendMetric.steps.usesHealthKit)
        XCTAssertTrue(HealthTrendMetric.totalEnergy.usesHealthKit)
        XCTAssertFalse(HealthTrendMetric.weight.usesHealthKit)
        XCTAssertFalse(HealthTrendMetric.water.usesHealthKit)
    }

    /// Prüft, dass feste Farben aus der gemeinsamen PasukiUI-Palette kommen.
    func testAccentColorUsesSharedPresetValues() throws {
        let accentColor = try XCTUnwrap(AppAccentColor(rawValue: "blue"))

        XCTAssertEqual(accentColor.preset, .blue)
        XCTAssertFalse(accentColor.isProOnly)
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
        let schema = Schema([WaterEntry.self, WeightEntry.self])
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
