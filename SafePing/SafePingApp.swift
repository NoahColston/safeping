// SafePing — SafePingApp.swift
// App entry point. Configures Firebase and injects shared environment objects.
// [OOP] Three ObservableObject services are created once and flow down the hierarchy.

import SwiftUI
import FirebaseCore

@main
struct SafePingApp: App {
    // Created here so the UNUserNotificationCenterDelegate is set before any notification response arrives
    @StateObject private var notificationService = NotificationService()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var locationService = LocationService()
    @StateObject private var watchConnectivity = WatchConnectivityService()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(notificationService)
                .environmentObject(locationService)
                .environmentObject(watchConnectivity)
        }
    }
}
