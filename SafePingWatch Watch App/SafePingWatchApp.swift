// SafePing — SafePingWatchApp.swift (watchOS target)
// Entry point for the Apple Watch companion app.
// Shows the user's next check-in time and a one-tap Check In button.
//
// Setup: In Xcode add a new "Watch App" target named "SafePingWatch",
// then add this file and SafePingWatchView.swift to that target.

import SwiftUI

@main
struct SafePingWatchApp: App {
    var body: some Scene {
        WindowGroup {
            SafePingWatchView()
        }
    }
}
