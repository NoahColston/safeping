// SafePing — SafePingWatchView.swift (watchOS target)
// Companion watch UI. Shows next check-in countdown and a Check In button.
// Communicates with the iOS app via WatchConnectivity (WCSession).
//
// [OOP] WatchSessionManager is an ObservableObject that wraps WCSession delegate.
// [Procedural] sendCheckIn() sequences: validate session → send message → update UI.

import SwiftUI
import WatchConnectivity

// MARK: - Session manager
@MainActor
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var nextCheckIn: String = "Tap to sync"
    @Published var lastStatus: String = "Unknown"
    @Published var isSending = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // [Procedural] Send check-in event to the paired iPhone
    func sendCheckIn() {
        guard WCSession.default.isReachable else {
            lastStatus = "Phone not reachable"
            return
        }
        isSending = true
        WCSession.default.sendMessage(["action": "checkIn"], replyHandler: { reply in
            Task { @MainActor in
                self.lastStatus = reply["result"] as? String ?? "Done"
                self.isSending = false
            }
        }, errorHandler: { error in
            Task { @MainActor in
                self.lastStatus = "Error: \(error.localizedDescription)"
                self.isSending = false
            }
        })
    }

    // WCSessionDelegate
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let next = message["nextCheckIn"] as? String else { return }
        Task { @MainActor in self.nextCheckIn = next }
    }
}

// MARK: - Watch UI
// [Functional] Pure view -- body is a function of WatchSessionManager's published state
struct SafePingWatchView: View {
    @StateObject private var session = WatchSessionManager()

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)

            Text("Next Check-In")
                .font(.headline)

            Text(session.nextCheckIn)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { session.sendCheckIn() }) {
                if session.isSending {
                    ProgressView()
                } else {
                    Text("Check In Now")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(session.isSending)

            Text(session.lastStatus)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    SafePingWatchView()
}
