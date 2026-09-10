enum NutritionUnitFormatter {
    static func baseUnit(for unit: String) -> String {
        unit == "piece" ? "g" : unit
    }

    static func title(for unit: String) -> String {
        switch unit {
        case "piece": "Stück"
        case "ml": "Milliliter"
        default: "Gramm"
        }
    }

    static func symbol(for unit: String) -> String {
        switch unit {
        case "piece": "Stück"
        case "ml": "ml"
        default: "g"
        }
    }
}
