import Foundation
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
    @Published var isAuthorized = false
    @Published var permissionDenied = false

    // MARK: - Request Permission
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            permissionDenied = !granted
        } catch {
            print("Notification permission error: \(error)")
            permissionDenied = true
        }
    }

    // MARK: - Check Current Status
    func checkCurrentStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        permissionDenied = settings.authorizationStatus == .denied
    }

    // MARK: - Schedule a Check-In Reminder
    /// Schedules a daily local notification at the given hour and minute
    func scheduleCheckInReminder(hour: Int, minute: Int, identifier: String = "daily-checkin") async {
        guard isAuthorized else { return }

        let center = UNUserNotificationCenter.current()

        // Remove any existing check-in notification
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "SafePing Check-In"
        content.body = "Time to check in! Let your people know you're safe."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            print("Check-in reminder scheduled for \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    // MARK: - Schedule a Test Notification (fires in 5 seconds)
    func scheduleTestNotification() async {
        guard isAuthorized else { return }

        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "SafePing Check-In"
        content.body = "Time to check in! Let your people know you're safe."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test-checkin", content: content, trigger: trigger)

        do {
            try await center.add(request)
            print("Test notification scheduled (5 seconds)")
        } catch {
            print("Failed to schedule test notification: \(error)")
        }
    }

    // MARK: - Cancel All Check-In Notifications
    func cancelAllCheckInReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-checkin"])
    }
}
