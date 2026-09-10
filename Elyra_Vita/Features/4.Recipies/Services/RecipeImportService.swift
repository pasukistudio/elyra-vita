import Foundation

struct ImportedRecipe {
    var title = ""
    var note = ""
    var category = ""
    var imageURL = ""
    var servings = 2
    var prepMinutes = 0
    var ingredients: [ImportedIngredient] = []
    var steps: [String] = []
}

struct ImportedIngredient {
    var amount: String
    var unit: String
    var name: String
}

enum RecipeImportError: LocalizedError {
    case invalidURL
    case noRecipeFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Die URL ist ungültig."
        case .noRecipeFound: "Auf dieser Seite wurde kein strukturiertes Rezept gefunden."
        case .invalidResponse: "Die Rezeptseite konnte nicht geladen werden."
        }
    }
}

struct RecipeImportService {
    func importRecipe(from rawURL: String) async throws -> ImportedRecipe {
        guard let url = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "http" || url.scheme == "https"
        else {
            throw RecipeImportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Elyra Vita Recipe Import/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 400).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8)
        else {
            throw RecipeImportError.invalidResponse
        }

        guard let recipe = parseRecipe(from: html) else { throw RecipeImportError.noRecipeFound }
        return recipe
    }

    private func parseRecipe(from html: String) -> ImportedRecipe? {
        let pattern = #"(?is)<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex ..< html.endIndex, in: html)

        for match in expression.matches(in: html, range: range) {
            guard let jsonRange = Range(match.range(at: 1), in: html),
                  let data = html[jsonRange].data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let recipe = findRecipe(in: json) {
                return recipe
            }
        }
        return nil
    }

    private func findRecipe(in value: Any) -> ImportedRecipe? {
        if let dictionary = value as? [String: Any] {
            if let type = dictionary["@type"] as? String, type.lowercased().contains("recipe") {
                return makeRecipe(from: dictionary)
            }
            if let types = dictionary["@type"] as? [String],
               types.contains(where: { $0.lowercased().contains("recipe") }) {
                return makeRecipe(from: dictionary)
            }
            for child in dictionary.values {
                if let recipe = findRecipe(in: child) {
                    return recipe
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let recipe = findRecipe(in: child) {
                    return recipe
                }
            }
        }
        return nil
    }

    private func makeRecipe(from dictionary: [String: Any]) -> ImportedRecipe {
        var result = ImportedRecipe()
        result.title = string(dictionary["name"])
        result.note = string(dictionary["description"])
        result.category = string(dictionary["recipeCategory"])
        result.imageURL = imageString(dictionary["image"])
        result.servings = firstInteger(in: string(dictionary["recipeYield"])) ?? 2
        result.prepMinutes = parseMinutes(string(dictionary["totalTime"]))
            ?? parseMinutes(string(dictionary["prepTime"]))
            ?? 0

        if let rawIngredients = dictionary["recipeIngredient"] as? [String] {
            result.ingredients = rawIngredients.map(parseIngredient)
        }
        result.steps = instructionStrings(dictionary["recipeInstructions"])
        return result
    }

    private func instructionStrings(_ value: Any?) -> [String] {
        if let text = value as? String {
            return [text].filter { !$0.isEmpty }
        }
        if let values = value as? [String] {
            return values.flatMap { instructionStrings($0) }
        }
        if let values = value as? [[String: Any]] {
            return values.flatMap { instructionStrings($0["text"] ?? $0["name"]) }
        }
        return []
    }

    private func parseIngredient(_ value: String) -> ImportedIngredient {
        let cleaned = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^([\d\s.,\/-]+)\s*([A-Za-zÄÖÜäöüß]+)?\s+(.+)$"#
        if let expression = try? NSRegularExpression(pattern: pattern),
           let match = expression.firstMatch(
               in: cleaned,
               range: NSRange(cleaned.startIndex ..< cleaned.endIndex, in: cleaned)
           ),
           let amountRange = Range(match.range(at: 1), in: cleaned),
           let nameRange = Range(match.range(at: 3), in: cleaned) {
            let unitRange = Range(match.range(at: 2), in: cleaned)
            return ImportedIngredient(
                amount: String(cleaned[amountRange]).trimmingCharacters(in: .whitespaces),
                unit: unitRange.map { String(cleaned[$0]) } ?? "",
                name: String(cleaned[nameRange])
            )
        }
        return ImportedIngredient(amount: "", unit: "", name: cleaned)
    }

    private func string(_ value: Any?) -> String {
        if let value = value as? String {
            return value.htmlDecoded
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        return ""
    }

    private func imageString(_ value: Any?) -> String {
        if let value = value as? String {
            return value
        }
        if let values = value as? [String] {
            return values.first ?? ""
        }
        if let dictionary = value as? [String: Any] {
            return string(dictionary["url"])
        }
        return ""
    }

    private func firstInteger(in value: String) -> Int? {
        Int(value.split(whereSeparator: { !$0.isNumber }).first.map(String.init) ?? "")
    }

    private func parseMinutes(_ value: String) -> Int? {
        guard !value.isEmpty else { return nil }
        if value.uppercased().hasPrefix("PT") {
            let pattern = #"^PT(?:(\d+)H)?(?:(\d+)M)?$"#
            guard let expression = try? NSRegularExpression(pattern: pattern),
                  let match = expression.firstMatch(
                      in: value.uppercased(),
                      range: NSRange(value.startIndex ..< value.endIndex, in: value)
                  ) else { return nil }
            let hours = match.range(at: 1).location == NSNotFound
                ? 0
                : Int((value as NSString).substring(with: match.range(at: 1))) ?? 0
            let minutes = match.range(at: 2).location == NSNotFound
                ? 0
                : Int((value as NSString).substring(with: match.range(at: 2))) ?? 0
            return hours * 60 + minutes
        }
        return firstInteger(in: value)
    }
}

private extension String {
    var htmlDecoded: String {
        guard let data = data(using: .utf8) else { return self }
        return String(bytes: data, encoding: .utf8) ?? replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
