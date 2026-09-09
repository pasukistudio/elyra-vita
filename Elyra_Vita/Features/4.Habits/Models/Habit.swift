import Foundation
import SwiftData

enum HabitRecurrence: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case selectedDays

    var id: Self { self }

    var title: String {
        switch self {
        case .daily: return "Täglich"
        case .weekly: return "Wöchentlich"
        case .monthly: return "Monatlich"
        case .selectedDays: return "Bestimmte Wochentage"
        }
    }
}

enum HabitTimePreset: String, CaseIterable, Identifiable {
    case morning
    case noon
    case evening
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .morning: return "Morgens"
        case .noon: return "Mittags"
        case .evening: return "Abends"
        case .custom: return "Eigene Uhrzeit"
        }
    }

    var defaultComponents: DateComponents {
        switch self {
        case .morning: return DateComponents(hour: 8, minute: 0)
        case .noon: return DateComponents(hour: 12, minute: 0)
        case .evening: return DateComponents(hour: 20, minute: 0)
        case .custom: return DateComponents(hour: 9, minute: 0)
        }
    }
}

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var note: String = ""
    var recurrenceRawValue: String = HabitRecurrence.daily.rawValue
    var selectedWeekdaysMask: Int = 0
    /// Anzahl der Erledigungen innerhalb einer Woche oder eines Monats.
    var targetCount: Int = 1
    var anchorDate: Date = Date()
    var timePresetRawValue: String = HabitTimePreset.morning.rawValue
    var reminderHour: Int = 8
    var reminderMinute: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String, recurrence: HabitRecurrence = .daily, anchorDate: Date = .now) {
        let timestamp = Date()
        id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        recurrenceRawValue = recurrence.rawValue
        self.anchorDate = anchorDate
        createdAt = timestamp
        updatedAt = timestamp
    }

    var recurrence: HabitRecurrence {
        get { HabitRecurrence(rawValue: recurrenceRawValue) ?? .daily }
        set { recurrenceRawValue = newValue.rawValue; updatedAt = .now }
    }

    var timePreset: HabitTimePreset {
        get { HabitTimePreset(rawValue: timePresetRawValue) ?? .morning }
        set {
            timePresetRawValue = newValue.rawValue
            let components = newValue.defaultComponents
            reminderHour = components.hour ?? reminderHour
            reminderMinute = components.minute ?? reminderMinute
            updatedAt = .now
        }
    }

    var reminderDateComponents: DateComponents {
        DateComponents(hour: reminderHour, minute: reminderMinute)
    }

    var reminderTimeText: String {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        return Calendar.current.date(from: components)?.formatted(date: .omitted, time: .shortened) ?? ""
    }

    var recurrenceText: String {
        switch recurrence {
        case .daily: return recurrence.title
        case .weekly: return "\(targetCount)× pro Woche"
        case .monthly: return "\(targetCount)× pro Monat"
        case .selectedDays:
            let names = Calendar.current.shortStandaloneWeekdaySymbols
            return (1...7).compactMap { selectedWeekdaysMask & (1 << ($0 - 1)) != 0 ? names[$0 - 1] : nil }.joined(separator: ", ")
        }
    }

    func update(name: String, note: String, recurrence: HabitRecurrence, weekdaysMask: Int, anchorDate: Date, targetCount: Int, preset: HabitTimePreset, hour: Int, minute: Int) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { self.name = trimmedName }
        self.note = note
        recurrenceRawValue = recurrence.rawValue
        selectedWeekdaysMask = weekdaysMask
        self.anchorDate = anchorDate
        self.targetCount = min(max(targetCount, 1), recurrence == .monthly ? 31 : 7)
        timePresetRawValue = preset.rawValue
        reminderHour = min(max(hour, 0), 23)
        reminderMinute = min(max(minute, 0), 59)
        updatedAt = .now
    }

    func isDue(on date: Date, calendar: Calendar = .current, completionDays: [Date] = []) -> Bool {
        guard !isArchived else { return false }
        switch recurrence {
        case .daily: return true
        case .weekly, .monthly:
            let component: Calendar.Component = recurrence == .weekly ? .weekOfYear : .month
            guard let interval = calendar.dateInterval(of: component, for: date),
                  let periodEnd = calendar.date(byAdding: component, value: 1, to: interval.start)
            else { return false }
            let completedInPeriod = Set(
                completionDays
                    .filter { $0 >= interval.start && $0 < periodEnd }
                    .map { calendar.startOfDay(for: $0) }
            ).count
            return completedInPeriod < targetCount
        case .selectedDays:
            let weekday = calendar.component(.weekday, from: date)
            return selectedWeekdaysMask & (1 << (weekday - 1)) != 0
        }
    }

    /// Liefert die aktuelle Serie passend zur Wiederholung des Habits.
    /// Bei Wochen- und Monatszielen zählt eine Serie aus erfüllten Zeiträumen;
    /// bei täglichen bzw. festen Tagen zählt jede geplante Erledigung.
    func currentStreak(on date: Date = .now, calendar: Calendar = .current, completionDays: [Date] = []) -> Int {
        guard !isArchived else { return 0 }

        let completed = Set(completionDays.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: date)

        switch recurrence {
        case .daily:
            var cursor = today
            if !completed.contains(cursor) {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor),
                      completed.contains(previous) else { return 0 }
                cursor = previous
            }

            var streak = 0
            while completed.contains(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
            }
            return streak

        case .selectedDays:
            func isScheduled(_ day: Date) -> Bool {
                let weekday = calendar.component(.weekday, from: day)
                return selectedWeekdaysMask & (1 << (weekday - 1)) != 0
            }

            var cursor = today
            if !isScheduled(cursor) || !completed.contains(cursor) {
                var foundPrevious = false
                for _ in 0..<7 {
                    guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                    cursor = previous
                    if isScheduled(cursor) {
                        foundPrevious = completed.contains(cursor)
                        break
                    }
                }
                guard foundPrevious else { return 0 }
            }

            var streak = 0
            while isScheduled(cursor) && completed.contains(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
                while !isScheduled(cursor) {
                    guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { return streak }
                    cursor = previous
                }
            }
            return streak

        case .weekly, .monthly:
            let component: Calendar.Component = recurrence == .weekly ? .weekOfYear : .month
            func periodIsComplete(_ periodDate: Date) -> Bool {
                guard let interval = calendar.dateInterval(of: component, for: periodDate),
                      let periodEnd = calendar.date(byAdding: component, value: 1, to: interval.start) else {
                    return false
                }
                let count = completed.filter { $0 >= interval.start && $0 < periodEnd }.count
                return count >= targetCount
            }

            var cursor = today
            if !periodIsComplete(cursor) {
                guard let previous = calendar.date(byAdding: component, value: -1, to: cursor),
                      periodIsComplete(previous) else { return 0 }
                cursor = previous
            }

            var streak = 0
            while periodIsComplete(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: component, value: -1, to: cursor) else { break }
                cursor = previous
            }
            return streak
        }
    }
}

@Model
final class HabitCompletion {
    var id: UUID = UUID()
    var habitID: UUID = UUID()
    var day: Date = Date()
    var completedAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(habitID: UUID, day: Date) {
        id = UUID()
        self.habitID = habitID
        self.day = Calendar.current.startOfDay(for: day)
        completedAt = .now
        createdAt = completedAt
        updatedAt = completedAt
    }
}

@MainActor
enum HabitCompletionStore {
    /// Entfernt doppelte Abschlüsse anhand von Habit und Kalendertag.
    /// Der älteste Datensatz bleibt erhalten, damit Synchronisationskonflikte
    /// nicht mehrfach in Fortschritt und Erinnerungen auftauchen.
    @discardableResult
    static func removeDuplicates(in context: ModelContext) throws -> Bool {
        let records = try context.fetch(FetchDescriptor<HabitCompletion>())
        var seen = Set<String>()
        var removedAny = false
        let calendar = Calendar.current

        for record in records.sorted(by: { $0.completedAt < $1.completedAt }) {
            let day = calendar.startOfDay(for: record.day).timeIntervalSince1970
            let key = "\(record.habitID.uuidString)-\(day)"
            if !seen.insert(key).inserted {
                context.delete(record)
                removedAny = true
            }
        }

        return removedAny
    }
}
