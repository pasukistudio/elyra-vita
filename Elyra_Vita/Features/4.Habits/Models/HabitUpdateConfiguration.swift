import Foundation

struct HabitUpdateConfiguration {
    let name: String
    let note: String
    let recurrence: HabitRecurrence
    let weekdaysMask: Int
    let anchorDate: Date
    let targetCount: Int
    let preset: HabitTimePreset
    let hour: Int
    let minute: Int
}
