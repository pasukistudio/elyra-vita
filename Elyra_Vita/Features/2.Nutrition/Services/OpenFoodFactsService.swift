import Foundation

// MARK: - OpenFoodFactsService

/// Liest Lebensmittel aus Open Food Facts und übersetzt sie in das App-Modell.
///
/// Die App speichert beim späteren Erfassen einen Nährwert-Snapshot. Änderungen
/// an einem externen Produkt verändern dadurch keine alten Ernährungseinträge.
struct OpenFoodFactsService {

    // MARK: - Konfiguration

    private let session: URLSession
    private let decoder: JSONDecoder

    /// Open Food Facts erwartet einen identifizierbaren User-Agent.
    private let userAgent = "ElyraVita/1.0 (pasuki.studio)"

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
    }

    // MARK: - Öffentliche Abfragen

    /// Lädt ein Produkt anhand seines standardisierten Barcodes.
    func product(for barcode: String) async throws -> NutritionFood? {
        let normalizedBarcode = barcode.filter(\.isNumber)
        guard !normalizedBarcode.isEmpty else { return nil }

        var components = URLComponents(
            string: "https://world.openfoodfacts.org/api/v3/product/\(normalizedBarcode).json"
        )
        components?.queryItems = [
            URLQueryItem(
                name: "fields",
                value: "code,product_name,product_name_de,brands,nutriments"
            )
        ]

        guard let url = components?.url else { throw OpenFoodFactsError.invalidURL }
        let response: ProductResponse = try await request(url)

        // Die aktuelle v3-API liefert `status` als Text (z. B. "success").
        // Für die Produktentscheidung ist das Vorhandensein des Produktobjekts
        // maßgeblich; so bleiben auch ältere Antworten ohne Status kompatibel.
        // `nil` bedeutet ausschließlich: Der Barcode ist in Open Food Facts
        // nicht vorhanden. Ein vorhandenes Produkt ohne ausreichende
        // Nährwerte ist ein eigener Fehler und darf nicht den Fallback zum
        // Anlegen eines neuen Lebensmittels auslösen.
        guard let product = response.product else { return nil }
        guard let food = product.food(barcode: normalizedBarcode) else {
            throw OpenFoodFactsError.missingNutritionData
        }
        return food
    }

    /// Sucht nach Produkten. Der textbasierte Suchdienst ist bei Open Food Facts
    /// derzeit ein Legacy-Endpunkt; der Adapter hält diese Abhängigkeit an einer Stelle.
    func search(_ query: String) async throws -> [NutritionFood] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return [] }

        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmedQuery),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: "code,product_name,product_name_de,brands,nutriments")
        ]

        guard let url = components?.url else { throw OpenFoodFactsError.invalidURL }
        let response: SearchResponse = try await request(url)

        return response.products.compactMap { product in
            guard let barcode = product.code, !barcode.isEmpty else { return nil }
            return product.food(barcode: barcode)
        }
    }

    // MARK: - HTTP

    private func request<Response: Decodable>(_ url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw OpenFoodFactsError.httpError
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw OpenFoodFactsError.invalidResponse
        }
    }
}

// MARK: - API-Modelle

private struct ProductResponse: Decodable {
    let product: Product?
}

private struct SearchResponse: Decodable {
    let products: [Product]
}

private struct Product: Decodable {
    let code: String?
    let productName: String?
    let productNameGerman: String?
    let brands: String?
    let nutriments: Nutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameGerman = "product_name_de"
        case brands
        case nutriments
    }

    func food(barcode: String) -> NutritionFood? {
        let name = [productNameGerman, productName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let name, let nutriments, nutriments.hasNutritionData else { return nil }

        return NutritionFood(
            id: "off-\(barcode)",
            name: name,
            brand: brands ?? "",
            unit: nutriments.isLiquid ? "ml" : "g",
            caloriesPer100: nutriments.caloriesPer100,
            proteinPer100: nutriments.proteinPer100,
            carbohydratesPer100: nutriments.carbohydratesPer100,
            fatPer100: nutriments.fatPer100,
            sugarPer100: nutriments.sugarPer100,
            fiberPer100: nutriments.fiberPer100,
            saturatedFatPer100: nutriments.saturatedFatPer100,
            saltPer100: nutriments.saltPer100,
            source: "openFoodFacts",
            barcode: barcode
        )
    }
}

private struct Nutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let sugars100g: Double?
    let fiber100g: Double?
    let saturatedFat100g: Double?
    let salt100g: Double?
    let energyKcal100ml: Double?
    let proteins100ml: Double?
    let carbohydrates100ml: Double?
    let fat100ml: Double?
    let sugars100ml: Double?
    let fiber100ml: Double?
    let saturatedFat100ml: Double?
    let salt100ml: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case sugars100g = "sugars_100g"
        case fiber100g = "fiber_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case salt100g = "salt_100g"
        case energyKcal100ml = "energy-kcal_100ml"
        case proteins100ml = "proteins_100ml"
        case carbohydrates100ml = "carbohydrates_100ml"
        case fat100ml = "fat_100ml"
        case sugars100ml = "sugars_100ml"
        case fiber100ml = "fiber_100ml"
        case saturatedFat100ml = "saturated-fat_100ml"
        case salt100ml = "salt_100ml"
    }

    var isLiquid: Bool { energyKcal100g == nil && energyKcal100ml != nil }
    var hasNutritionData: Bool { caloriesPer100 > 0 || proteinPer100 > 0 || carbohydratesPer100 > 0 || fatPer100 > 0 }

    var caloriesPer100: Double { isLiquid ? energyKcal100ml ?? 0 : energyKcal100g ?? 0 }
    var proteinPer100: Double { isLiquid ? proteins100ml ?? 0 : proteins100g ?? 0 }
    var carbohydratesPer100: Double { isLiquid ? carbohydrates100ml ?? 0 : carbohydrates100g ?? 0 }
    var fatPer100: Double { isLiquid ? fat100ml ?? 0 : fat100g ?? 0 }
    var sugarPer100: Double { isLiquid ? sugars100ml ?? 0 : sugars100g ?? 0 }
    var fiberPer100: Double { isLiquid ? fiber100ml ?? 0 : fiber100g ?? 0 }
    var saturatedFatPer100: Double { isLiquid ? saturatedFat100ml ?? 0 : saturatedFat100g ?? 0 }
    var saltPer100: Double { isLiquid ? salt100ml ?? 0 : salt100g ?? 0 }
}

// MARK: - Fehler

enum OpenFoodFactsError: LocalizedError {
    case invalidURL
    case httpError
    case invalidResponse
    case missingNutritionData

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Die Open-Food-Facts-Adresse ist ungültig."
        case .httpError: "Open Food Facts ist momentan nicht erreichbar."
        case .invalidResponse: "Open Food Facts hat keine verwertbaren Daten geliefert."
        case .missingNutritionData: "Für dieses Produkt sind keine ausreichenden Nährwerte hinterlegt."
        }
    }
}
