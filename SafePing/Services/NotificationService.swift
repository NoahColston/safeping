// SafePing — NotificationService.swift

// Handles scheduling and cancelling local notifications
// Also processes notification actions like "Check In"
//

import UserNotifications
import FirebaseFirestore


// NotificationService
// Manages reminders, escalation alerts, and notification actions
//
// [OOP] Class using delegate pattern and ObservableObject
//
class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    static let checkInActionId   = "CHECK_IN_ACTION"
    static let checkInCategoryId = "CHECK_IN_CATEGORY"
    
    // used to scope cancellation
    static let checkInRequestPrefix = "checkIn-"
    
    @Published var isReminderEnabled: Bool
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    
    override init() {
        isReminderEnabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
        super.init()
        // Set delegate at init so action responses are captured even on cold launch
        UNUserNotificationCenter.current().delegate = self
        registerCheckInCategory()
    }
    
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
    
    
    // Requests notification permission
    // [Procedural] Handles async permission flow
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isReminderEnabled = granted
                UserDefaults.standard.set(granted, forKey: "reminderEnabled")
                permissionStatus = granted ? .authorized : .denied
            }
        } catch {
            print("Notification permission error: \(error)")
        }
    }
    func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            permissionStatus = settings.authorizationStatus
            // If the user revoked permission in iOS Settings, reflect that in our toggle
            if settings.authorizationStatus == .denied {
                isReminderEnabled = false
                UserDefaults.standard.set(false, forKey: "reminderEnabled")
            }
        }
    }
    
    
    // Schedules reminders for all pairings
    // [Procedural] Iterates through pairings and schedules
    func scheduleAllReminders(for pairings: [Pairing], username: String) {
        Task {
            await cancelAllCheckInRemindersAsync()
            
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            
            for pairing in pairings {
                for schedule in pairing.schedules {
                    let title = schedule.message.isEmpty
                    ? "Time to check in!"
                    : "Check in: \(schedule.message)"
                    let body = schedule.message.isEmpty
                    ? "Your people are counting on you. Tap to check in now."
                    : schedule.message
                    
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = body
                    content.sound = .default
                    content.categoryIdentifier = NotificationService.checkInCategoryId
                    content.userInfo = [
                        "username": username,
                        "pairingId": pairing.id.uuidString,
                        "scheduleId": schedule.id.uuidString
                    ]
                    
                    if schedule.frequency == .daily {
                        var components = DateComponents()
                        components.hour = schedule.hour
                        components.minute = schedule.minute
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                        let identifier = "\(NotificationService.checkInRequestPrefix)\(pairing.id.uuidString)-\(schedule.id.uuidString)-daily"
                        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                        try? await UNUserNotificationCenter.current().add(request)
                    } else {
                        for weekday in schedule.activeDays {
                            var components = DateComponents()
                            components.hour = schedule.hour
                            components.minute = schedule.minute
                            components.weekday = weekday
                            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                            let identifier = "\(NotificationService.checkInRequestPrefix)\(pairing.id.uuidString)-\(schedule.id.uuidString)-w\(weekday)"
                            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                            try? await UNUserNotificationCenter.current().add(request)
                        }
                    }
                }
            }
            
            await MainActor.run {
                isReminderEnabled = true
                UserDefaults.standard.set(true, forKey: "reminderEnabled")
            }
        }
    }
    
    // Schedules escalation alerts after missed check ins
    // [Procedural] Calculates adjusted time and schedules notifications
    static let escalationRequestPrefix = "escalation-"

    func scheduleEscalationNotifications(for pairings: [Pairing], username: String) {
        Task {
            await cancelEscalationNotificationsAsync()

            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }

            for pairing in pairings {
                for schedule in pairing.schedules {
                    let content = UNMutableNotificationContent()
                    content.title = "⚠️ Missed check-in"
                    content.body = schedule.message.isEmpty
                        ? "You missed your check-in. \(pairing.checkerUsername) will be notified."
                        : "Missed: \(schedule.message). \(pairing.checkerUsername) will be notified."
                    content.sound = .default
                    content.userInfo = [
                        "type": "escalation",
                        "pairingId": pairing.id.uuidString,
                        "scheduleId": schedule.id.uuidString
                    ]

                    // Fire at scheduled time + grace period
                    let fireMinute = (schedule.minute + schedule.gracePeriodMinutes) % 60
                    let extraHours = (schedule.minute + schedule.gracePeriodMinutes) / 60
                    let fireHour = (schedule.hour + extraHours) % 24
                    let crossesMidnight = (schedule.hour + extraHours) >= 24

                    if schedule.frequency == .daily {
                        var components = DateComponents()
                        components.hour = fireHour
                        components.minute = fireMinute
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                        let identifier = "\(NotificationService.escalationRequestPrefix)\(pairing.id.uuidString)-\(schedule.id.uuidString)-daily"
                        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                        try? await UNUserNotificationCenter.current().add(request)
                    } else {
                        for weekday in schedule.activeDays {
                            let adjustedWeekday = crossesMidnight
                                ? (weekday % 7) + 1
                                : weekday
                            var components = DateComponents()
                            components.hour = fireHour
                            components.minute = fireMinute
                            components.weekday = adjustedWeekday
                            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                            let identifier = "\(NotificationService.escalationRequestPrefix)\(pairing.id.uuidString)-\(schedule.id.uuidString)-w\(weekday)"
                            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                            try? await UNUserNotificationCenter.current().add(request)
                        }
                    }
                }
            }
        }
    }

    // Cancel a specific schedule's escalation notification
    func cancelEscalationForSchedule(pairingId: UUID, scheduleId: UUID) {
        Task {
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let prefix = "\(NotificationService.escalationRequestPrefix)\(pairingId.uuidString)-\(scheduleId.uuidString)"
            let toCancel = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toCancel)
        }
    }

    private func cancelEscalationNotificationsAsync() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let toCancel = pending.map(\.identifier).filter { $0.hasPrefix(NotificationService.escalationRequestPrefix) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toCancel)
    }

    // Handles "Check In" action from notification
    // [OOP] Delegate method
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == NotificationService.checkInActionId {
            let userInfo = response.notification.request.content.userInfo
            let username = userInfo["username"] as? String ?? ""
            let pairingId = userInfo["pairingId"] as? String ?? ""
            let scheduleId = userInfo["scheduleId"] as? String ?? ""
            if !username.isEmpty && !pairingId.isEmpty {
                Task { await saveCheckInFromNotification(
                    username: username,
                    pairingId: pairingId,
                    scheduleId: scheduleId
                )
                }
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
    
    private func saveCheckInFromNotification(
        username: String,
        pairingId: String,
        scheduleId: String
    ) async {
        let db = Firestore.firestore()
        let today = Date()
        
        // Look up the schedule's configured time from the
        // pairing document and reject if more than 15 minutes early.
        if !scheduleId.isEmpty, let _ = UUID(uuidString: scheduleId) {
            do {
                let pairDoc = try await db.collection("pairs").document(pairingId).getDocument()
                if let pairData = pairDoc.data(),
                   let schedulesArr = pairData["schedules"] as? [[String: Any]] {
                    let matched = schedulesArr.first { ($0["id"] as? String) == scheduleId }
                    if let matched = matched {
                        let schedule = CheckInSchedule.fromFirestore(matched)
                        let calendar = Calendar.current
                        var components = calendar.dateComponents([.year, .month, .day], from: today)
                        components.hour = schedule.hour
                        components.minute = schedule.minute
                        if let scheduledTime = calendar.date(from: components) {
                            let earliest = calendar.date(byAdding: .minute, value: -15, to: scheduledTime)!
                            let latest = calendar.date(byAdding: .minute, value: schedule.gracePeriodMinutes, to: scheduledTime)!
                            if today < earliest || today > latest {
                                // Outside check-in window — silently skip
                                return
                            }
                        }
                    }
                }
            } catch {
                // If we can't verify, allow the check-in
            }
        }
        
        
        let dayKey = Int(Calendar.current.startOfDay(for: today).timeIntervalSince1970)
        let scheduleKey = scheduleId.isEmpty ? "legacy" : scheduleId
        let docId = "\(pairingId)_\(scheduleKey)_\(dayKey)"
        
        var data: [String: Any] = [
            "id": UUID().uuidString,
            "pairingId": pairingId,
            "username": username,
            "date": Timestamp(date: today),
            "status": CheckInStatus.checkedIn.rawValue
        ]
        if !scheduleId.isEmpty {
            data["scheduleId"] = scheduleId
        }
        try? await db.collection("checkIns")
            .document(docId)
            .setData(data)
    }
    
    func simulateCheckerAlert(checkeeName: String) {
        let content = UNMutableNotificationContent()
        content.title = "✅ \(checkeeName) checked in"
        content.body = "\(checkeeName) is safe and checked in today."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    
    func cancelAllCheckInReminders() {
        Task { await cancelAllCheckInRemindersAsync() }
    }
    
    private func cancelAllCheckInRemindersAsync() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let toCancel = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(NotificationService.checkInRequestPrefix) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toCancel)
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
}
