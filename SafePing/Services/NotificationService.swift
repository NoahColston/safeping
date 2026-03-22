import UserNotifications
import FirebaseFirestore

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let checkInActionId   = "CHECK_IN_ACTION"
    static let checkInCategoryId = "CHECK_IN_CATEGORY"

    override init() {
        super.init()
        // Set delegate at init so action responses are captured even on cold launch
        UNUserNotificationCenter.current().delegate = self
        registerCheckInCategory()
    }

    // MARK: - Story 16: Register "Check In" action button on notifications
    func registerCheckInCategory() {
        let checkInAction = UNNotificationAction(
            identifier: NotificationService.checkInActionId,
            title: "Check In",
            options: [.authenticationRequired]
        )
        let category = UNNotificationCategory(
            identifier: NotificationService.checkInCategoryId,
            actions: [checkInAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Request permission
    func requestPermission() async {
        do {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    // MARK: - Schedule daily check-in reminder
    // Story 14: supports custom message and schedule time
    // Story 16: attaches action button category and stores username in userInfo
    func scheduleCheckInReminder(message: String? = nil, hour: Int = 9, minute: Int = 0, username: String = "") {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyCheckIn"])

        let content = UNMutableNotificationContent()
        content.title = "Time to check in!"
        content.body = message?.isEmpty == false
            ? message!
            : "Your people are counting on you. Tap to check in now."
        content.sound = .default
        content.categoryIdentifier = NotificationService.checkInCategoryId
        content.userInfo = ["username": username]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyCheckIn", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Story 16: Handle "Check In" action tapped from notification banner
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == NotificationService.checkInActionId {
            let username = response.notification.request.content.userInfo["username"] as? String ?? ""
            if !username.isEmpty {
                Task { await saveCheckInFromNotification(username: username) }
            }
        }
        completionHandler()
    }

    // Show notification banner even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Save check-in to Firebase directly from the notification (no app open needed)
    private func saveCheckInFromNotification(username: String) async {
        let db = Firestore.firestore()
        let today = Date()
        let data: [String: Any] = [
            "username": username,
            "date": Timestamp(date: today),
            "status": CheckInStatus.checkedIn.rawValue
        ]
        try? await db.collection("checkIns")
            .document("\(username)_\(Int(today.timeIntervalSince1970))")
            .setData(data)
    }

    // MARK: - Simulate checker being notified
    func simulateCheckerAlert(checkeeName: String) {
        let content = UNMutableNotificationContent()
        content.title = "✅ \(checkeeName) checked in"
        content.body = "\(checkeeName) is safe and checked in today."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Simulate missed check-in alert
    func simulateMissedCheckIn(checkeeName: String) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ \(checkeeName) hasn't checked in"
        content.body = "\(checkeeName) missed their check-in today. You may want to reach out."
        content.sound = UNNotificationSound.defaultCritical

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel all reminders
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
