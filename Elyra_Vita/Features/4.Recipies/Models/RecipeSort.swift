enum RecipeSort: String, CaseIterable, Identifiable {
    case recent
    case title
    case time

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .recent: "Zuletzt geändert"
        case .title: "Alphabetisch"
        case .time: "Zubereitungszeit"
        }
    }
}
