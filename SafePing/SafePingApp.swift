import SwiftUI
import FirebaseCore

@main
struct SafePingApp: App {
    // Created here so the UNUserNotificationCenterDelegate is set before any notification response arrives
    @StateObject private var notificationService = NotificationService()
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(notificationService)
        }
    }
}
