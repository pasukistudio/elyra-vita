import SwiftData
import XCTest
import Foundation
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

    // MARK: - Ernährung

    /// Prüft die bewusst gewählte Reihenfolge im Tageslogbuch.
    func testNutritionMealTypesUseRequestedDisplayOrder() {
        XCTAssertEqual(
            [NutritionMealType.dinner, .lunch, .breakfast, .snack]
                .map(\.displayOrder),
            [0, 1, 2, 3]
        )
    }

    /// Prüft Stückeinheiten und die Umrechnung auf die Basis-Nährwertmenge.
    func testNutritionFoodProvidesPieceUnitConversion() {
        let egg = NutritionFood.localCatalog.first { $0.id == "egg" }

        XCTAssertEqual(egg?.unitOptions.map(\.symbol), ["g", "Stück"])
        XCTAssertEqual(egg?.baseAmount(for: 1, unit: "piece"), 60)
    }

    /// Prüft, dass ein eigenes Lebensmittel alle Nährwerte in den
    /// gemeinsamen Erfassungsdatensatz überführt.
    func testCustomFoodConvertsAllNutritionValues() {
        let food = CustomFood(
            name: "Eigenes Müsli",
            brand: "Hausmarke",
            unit: "g",
            pieceWeight: 45,
            caloriesPer100: 410,
            proteinPer100: 12,
            carbohydratesPer100: 55,
            fatPer100: 14,
            sugarPer100: 8,
            fiberPer100: 7,
            saturatedFatPer100: 3,
            saltPer100: 0.2
        )

        let nutritionFood = food.nutritionFood

        XCTAssertEqual(nutritionFood.name, "Eigenes Müsli")
        XCTAssertEqual(nutritionFood.brand, "Hausmarke")
        XCTAssertEqual(nutritionFood.source, "custom")
        XCTAssertEqual(nutritionFood.pieceWeight, 45)
        XCTAssertEqual(nutritionFood.caloriesPer100, 410)
        XCTAssertEqual(nutritionFood.proteinPer100, 12)
        XCTAssertEqual(nutritionFood.carbohydratesPer100, 55)
        XCTAssertEqual(nutritionFood.fatPer100, 14)
        XCTAssertEqual(nutritionFood.sugarPer100, 8)
        XCTAssertEqual(nutritionFood.fiberPer100, 7)
        XCTAssertEqual(nutritionFood.saturatedFatPer100, 3)
        XCTAssertEqual(nutritionFood.saltPer100, 0.2)
    }

    /// Prüft, dass ein eigenes Lebensmittel im SwiftData-Kontext gespeichert
    /// und anschließend vollständig wieder geladen werden kann.
    func testCustomFoodPersistsAndNormalizesValues() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let food = CustomFood(
            name: "Negativschutz",
            pieceWeight: -20,
            caloriesPer100: -10,
            proteinPer100: 4
        )

        context.insert(food)
        try context.save()

        let fetchedFoods = try context.fetch(FetchDescriptor<CustomFood>())
        let fetchedFood = try XCTUnwrap(fetchedFoods.first)

        XCTAssertEqual(fetchedFood.name, "Negativschutz")
        XCTAssertEqual(fetchedFood.pieceWeight, 0)
        XCTAssertEqual(fetchedFood.caloriesPer100, 0)
        XCTAssertEqual(fetchedFood.proteinPer100, 4)
        XCTAssertEqual(fetchedFood.updatedAt, fetchedFood.createdAt)
    }

    /// Prüft den vollständigen Lebenszyklus eines eigenen Lebensmittels:
    /// speichern, aktualisieren und löschen.
    func testCustomFoodSupportsUpdateAndDeletion() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let food = CustomFood(name: "Original", caloriesPer100: 100)
        context.insert(food)
        try context.save()

        let originalUpdatedAt = food.updatedAt
        food.name = "Aktualisiert"
        food.caloriesPer100 = 125
        food.updatedAt = originalUpdatedAt.addingTimeInterval(1)
        try context.save()

        let updatedFood = try XCTUnwrap(
            try context.fetch(FetchDescriptor<CustomFood>()).first
        )
        XCTAssertEqual(updatedFood.name, "Aktualisiert")
        XCTAssertEqual(updatedFood.caloriesPer100, 125)
        XCTAssertGreaterThan(updatedFood.updatedAt, originalUpdatedAt)

        context.delete(updatedFood)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<CustomFood>()).isEmpty)
    }

    /// Prüft, dass Open Food Facts alle verfügbaren Nährwerte in das lokale
    /// Lebensmittelmodell übernimmt und die Barcode-Quelle erhalten bleibt.
    func testOpenFoodFactsProductMapsNutritionValues() async throws {
        MockOpenFoodFactsURLProtocol.responseData = Data("""
        {
          "status": "success",
          "product": {
            "code": "4000000000000",
            "product_name": "Testprodukt",
            "product_name_de": "Testprodukt DE",
            "brands": "Testmarke",
            "nutriments": {
              "energy-kcal_100g": 250,
              "proteins_100g": 8.5,
              "carbohydrates_100g": 30.0,
              "fat_100g": 9.0,
              "sugars_100g": 12.0,
              "fiber_100g": 4.0,
              "saturated-fat_100g": 2.5,
              "salt_100g": 0.8
            }
          }
        }
        """.utf8)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockOpenFoodFactsURLProtocol.self]
        let service = OpenFoodFactsService(session: URLSession(configuration: configuration))

        let loadedFood = try await service.product(for: "4000000000000")
        let food = try XCTUnwrap(loadedFood)

        XCTAssertEqual(food.name, "Testprodukt DE")
        XCTAssertEqual(food.brand, "Testmarke")
        XCTAssertEqual(food.source, "openFoodFacts")
        XCTAssertEqual(food.barcode, "4000000000000")
        XCTAssertEqual(food.caloriesPer100, 250)
        XCTAssertEqual(food.proteinPer100, 8.5)
        XCTAssertEqual(food.carbohydratesPer100, 30)
        XCTAssertEqual(food.fatPer100, 9)
        XCTAssertEqual(food.sugarPer100, 12)
        XCTAssertEqual(food.fiberPer100, 4)
        XCTAssertEqual(food.saturatedFatPer100, 2.5)
        XCTAssertEqual(food.saltPer100, 0.8)
    }

    /// Die aktuelle Open-Food-Facts-v3-Antwort verwendet einen Textstatus.
    /// Ein bekanntes Produkt darf dadurch nicht als ungültig verworfen werden.
    func testOpenFoodFactsV3ResponseWithTextStatusIsDecoded() async throws {
        MockOpenFoodFactsURLProtocol.responseData = Data("""
        {
          "code": "3017620422003",
          "status": "success",
          "product": {
            "code": "3017620422003",
            "product_name": "Testprodukt",
            "nutriments": {
              "energy-kcal_100g": 539,
              "fat_100g": 30.9
            }
          }
        }
        """.utf8)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockOpenFoodFactsURLProtocol.self]
        let service = OpenFoodFactsService(session: URLSession(configuration: configuration))

        let loadedFood = try await service.product(for: "3017620422003")
        let food = try XCTUnwrap(loadedFood)

        XCTAssertEqual(food.name, "Testprodukt")
        XCTAssertEqual(food.barcode, "3017620422003")
        XCTAssertEqual(food.caloriesPer100, 539)
        XCTAssertEqual(food.fatPer100, 30.9)
    }

    /// Prüft Tagesaggregation, Änderungszeitstempel und Löschen eines Eintrags.
    func testNutritionEntrySupportsDailyAggregationAndDeletion() throws {
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21))
        )
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let firstEntry = NutritionEntry(
            foodName: "Weizenbrötchen",
            mealType: .breakfast,
            amount: 85,
            unit: "g",
            calories: 230,
            proteinGrams: 7.2,
            carbohydratesGrams: 44.2,
            fatGrams: 2.7,
            sugarGrams: 2.9,
            fiberGrams: 2.6,
            saturatedFatGrams: 0.4,
            saltGrams: 1.0,
            date: selectedDay
        )
        let secondEntry = NutritionEntry(
            foodName: "Apfel",
            mealType: .snack,
            amount: 150,
            unit: "g",
            calories: 78,
            date: selectedDay
        )

        context.insert(firstEntry)
        context.insert(secondEntry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<NutritionEntry>())
        let total = entries
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }
            .reduce(0) { $0 + $1.calories }
        let originalUpdatedAt = firstEntry.updatedAt

        firstEntry.update(mealType: .lunch, amount: 100, date: selectedDay)
        try context.save()

        XCTAssertEqual(total, 308)
        XCTAssertEqual(firstEntry.mealType, .lunch)
        XCTAssertEqual(firstEntry.amount, 100)
        XCTAssertEqual(firstEntry.sugarGrams, 2.9)
        XCTAssertEqual(firstEntry.fiberGrams, 2.6)
        XCTAssertEqual(firstEntry.saturatedFatGrams, 0.4)
        XCTAssertEqual(firstEntry.saltGrams, 1.0)
        XCTAssertGreaterThanOrEqual(firstEntry.updatedAt, originalUpdatedAt)

        context.delete(secondEntry)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<NutritionEntry>()).count, 1)
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
        let schema = Schema([WaterEntry.self, WeightEntry.self, NutritionEntry.self, CustomFood.self])
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

// MARK: - Open Food Facts Test-Helfer

/// Liefert deterministische API-Antworten, ohne im Testnetzwerk auf Open Food
/// Facts angewiesen zu sein.
private final class MockOpenFoodFactsURLProtocol: URLProtocol {
    static var responseData = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
