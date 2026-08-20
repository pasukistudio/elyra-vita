import Foundation
import SwiftData

/// Ein einzelner Wassereintrag für einen bestimmten Zeitpunkt.
@Model
final class WaterEntry {
    var date: Date
    var amount: Int

    init(date: Date = .now, amount: Int) {
        self.date = date
        self.amount = amount
    }
}
