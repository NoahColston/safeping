// SafePing — SafePingWatchApp.swift (watchOS target)
// Entry point for the Apple Watch companion app.
// Shows the user's next check-in time and a one-tap Check In button.

import SwiftUI

@main
struct SafePingWatchApp: App {
    var body: some Scene {
        WindowGroup {
            SafePingWatchView()
        }
    }
}
