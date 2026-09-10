enum FoodFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recent

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .all: "Alle"
        case .favorites: "Favoriten"
        case .recent: "Zuletzt"
        }
    }
}
