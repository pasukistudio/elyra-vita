import SwiftUI
import UserNotifications

extension HabitsView {
    var deletingAlert: Binding<Bool> {
        Binding(get: { deletingHabit != nil }, set: {
            if !$0 {
                deletingHabit = nil
            }
        })
    }

    var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: {
                if !$0 {
                    saveErrorMessage = nil
                }
            }
        )
    }

    var notificationPresented: Binding<Bool> {
        Binding(
            get: { notificationMessage != nil },
            set: {
                if !$0 {
                    notificationMessage = nil
                }
            }
        )
    }

    func rescheduleNotifications() async {
        let result = await HabitNotificationService.synchronize(habits: activeHabits, completions: completions)
        if activeHabits.isEmpty {
            return
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            notificationMessage = "Benachrichtigungen sind deaktiviert. Aktiviere sie in den iPhone-"
                + "Einstellungen, damit Habit-Erinnerungen angezeigt werden."
            return
        }

        if result.failedCount > 0 {
            notificationMessage = "\(result.failedCount) Erinnerung(en) konnten nicht geplant werden."
        }
    }
}
