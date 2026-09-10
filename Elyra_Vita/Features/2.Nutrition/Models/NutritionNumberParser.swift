import Foundation

enum NutritionNumberParser {
    nonisolated static func parse(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
              value.isFinite else { return nil }
        return value
    }

    nonisolated static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
            .replacingOccurrences(of: #"\.00$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(\.[0-9])0$"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: ".", with: ",")
    }
}
