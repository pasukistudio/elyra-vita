import Foundation
import SwiftData
import XCTest
@testable import Elyra_Vita

@MainActor
final class HabitTests: XCTestCase {
    func testHabitRecurrenceMatchesExpectedDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31)))
        let wednesday = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: monday))
        let tuesday = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: monday))

        let habit = Habit(name: "Spaziergang", recurrence: .selectedDays, anchorDate: monday)
        habit.selectedWeekdaysMask = (1 << (calendar.component(.weekday, from: monday) - 1)) | (1 << (calendar.component(.weekday, from: wednesday) - 1))

        XCTAssertTrue(habit.isDue(on: monday, calendar: calendar))
        XCTAssertTrue(habit.isDue(on: wednesday, calendar: calendar))
        XCTAssertFalse(habit.isDue(on: tuesday, calendar: calendar))
    }

    func testWeeklyHabitUsesFrequencyWithoutFixedWeekday() {
        let habit = Habit(name: "Sport", recurrence: .weekly)
        habit.targetCount = 2
        let firstDay = Calendar.current.startOfDay(for: .now)
        let secondDay = Calendar.current.date(byAdding: .day, value: 1, to: firstDay)!
        XCTAssertTrue(habit.isDue(on: .now, completionDays: []))
        XCTAssertFalse(habit.isDue(on: .now, completionDays: [firstDay, secondDay]))
    }

    func testWeeklyHabitCountsUniqueCompletionDays() {
        let habit = Habit(name: "Sport", recurrence: .weekly)
        habit.targetCount = 2
        let firstDay = Calendar.current.startOfDay(for: .now)
        let secondDay = Calendar.current.date(byAdding: .day, value: 1, to: firstDay)!

        XCTAssertFalse(habit.isDue(on: .now, completionDays: [firstDay, firstDay, secondDay]))
    }

    func testMonthlyHabitUsesFrequencyWithoutFixedDay() {
        let habit = Habit(name: "Großputz", recurrence: .monthly)
        habit.targetCount = 1
        XCTAssertTrue(habit.isDue(on: .now, completionDays: []))
        XCTAssertFalse(habit.isDue(on: .now, completionDays: [.now]))
    }

    func testHabitStoresReminderAndUpdateTimestamp() {
        let habit = Habit(name: "Wasser", recurrence: .daily)
        let originalUpdatedAt = habit.updatedAt
        habit.update(name: "Wasser trinken", note: "", recurrence: .daily, weekdaysMask: 0, anchorDate: .now, targetCount: 1, preset: .custom, hour: 14, minute: 30)

        XCTAssertEqual(habit.name, "Wasser trinken")
        XCTAssertEqual(habit.reminderHour, 14)
        XCTAssertEqual(habit.reminderMinute, 30)
        XCTAssertGreaterThanOrEqual(habit.updatedAt, originalUpdatedAt)
    }

    func testHabitCompletionIsPersistedAndDeleted() throws {
        let schema = Schema([Habit.self, HabitCompletion.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let habit = Habit(name: "Dehnen")
        context.insert(habit)
        context.insert(HabitCompletion(habitID: habit.id, day: .now))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<HabitCompletion>()).count, 1)
        for completion in try context.fetch(FetchDescriptor<HabitCompletion>()) { context.delete(completion) }
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<HabitCompletion>()).isEmpty)
    }

    func testHabitCompletionStoreRemovesDuplicatesAndKeepsOldest() throws {
        let schema = Schema([Habit.self, HabitCompletion.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let habit = Habit(name: "Lesen")
        context.insert(habit)

        let oldest = HabitCompletion(habitID: habit.id, day: .now)
        let duplicate = HabitCompletion(habitID: habit.id, day: .now)
        duplicate.completedAt = oldest.completedAt.addingTimeInterval(60)
        context.insert(oldest)
        context.insert(duplicate)
        try context.save()

        XCTAssertTrue(try HabitCompletionStore.removeDuplicates(in: context))
        try context.save()
        let remaining = try context.fetch(FetchDescriptor<HabitCompletion>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, oldest.id)
    }

    func testWeeklyReminderPlanningDoesNotScheduleEveryDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)))
        let habit = Habit(name: "Sport", recurrence: .weekly, anchorDate: start)
        habit.targetCount = 2
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let planned = days.filter {
            HabitNotificationService.shouldSchedule(habit: habit, on: $0, from: start, calendar: calendar, completionDays: [])
        }

        XCTAssertEqual(planned.count, 2)
    }

    func testMonthlyReminderPlanningRespectsCompletedCount() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let habit = Habit(name: "Großputz", recurrence: .monthly, anchorDate: start)
        habit.targetCount = 2
        let completed = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 2)))
        let days = (0..<30).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let planned = days.filter {
            HabitNotificationService.shouldSchedule(habit: habit, on: $0, from: start, calendar: calendar, completionDays: [completed])
        }

        XCTAssertEqual(planned.count, 1)
    }
}
