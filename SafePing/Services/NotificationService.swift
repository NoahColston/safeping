import UserNotifications

class NotificationService: ObservableObject {
    
    // MARK: - Request permission
    func requestPermission() async {
        do {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
        }
    }
    
    // MARK: - Checkee: reminder to check in
    func scheduleCheckInReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time to check in!"
        content.body = "Your people are counting on you. Tap to check in now."
        content.sound = .default
        
        // Fire every day at 9am
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "dailyCheckIn",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Simulate checker being notified (fires locally on same device for demo)
    func simulateCheckerAlert(checkeeName: String) {
        let content = UNMutableNotificationContent()
        content.title = "✅ \(checkeeName) checked in"
        content.body = "\(checkeeName) is safe and checked in today."
        content.sound = .default
        
        // Fire after 2 seconds so it feels like a real notification
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 2,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Simulate missed check-in alert (for demo)
    func simulateMissedCheckIn(checkeeName: String) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ \(checkeeName) hasn't checked in"
        content.body = "\(checkeeName) missed their check-in today. You may want to reach out."
        content.sound = UNNotificationSound.defaultCritical
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 2,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Cancel reminders
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
