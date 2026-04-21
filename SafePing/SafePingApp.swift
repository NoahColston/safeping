import SwiftUI
import FirebaseCore

// SafePing SafePingApp.swift
// App entry point Configures Firebase and injects shared services into the environment

@main
struct SafePingApp: App {
    
    // These are created once at app launch and shared throughout the app
    // Keeping them at the root ensures consistent state across all views
    @StateObject private var notificationService = NotificationService()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var locationService = LocationService()
    @StateObject private var watchConnectivity = WatchConnectivityService()

    init() {
        // Initializes Firebase before any view loads or network calls happen
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject shared app-wide services into SwiftUI environment
                .environmentObject(authViewModel)
                .environmentObject(notificationService)
                .environmentObject(locationService)
                .environmentObject(watchConnectivity)
        }
    }
}
