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
    @Published var nextCheckIn: String = "Open SafePing on your iPhone to sync"
    @Published var resultMessage: String?
    @Published var isSending = false

    /// True when the phone has sent a scheduled time (not a "no schedules" message).
    var canCheckIn: Bool {
        guard !isSending else { return false }
        // Only allow check-in if we have an actual time string from the phone.
        let noCheckInPhrases = [
            "Open SafePing on your iPhone to sync",
            "No check-ins scheduled",
            "Phone not reachable"
        ]
        return !noCheckInPhrases.contains(nextCheckIn)
    }

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
            nextCheckIn = "Phone not reachable"
            return
        }
        isSending = true
        resultMessage = nil
        WCSession.default.sendMessage(["action": "checkIn"], replyHandler: { reply in
            Task { @MainActor in
                self.resultMessage = reply["result"] as? String ?? "Done"
                self.isSending = false
                // Clear the result after a few seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if self.resultMessage == reply["result"] as? String {
                    self.resultMessage = nil
                }
            }
        }, errorHandler: { error in
            Task { @MainActor in
                self.resultMessage = "Could not reach phone"
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
struct SafePingWatchView: View {
    @StateObject private var session = WatchSessionManager()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("Safe")
                    .foregroundColor(.white)
                Text("Ping")
                    .foregroundColor(.green)
            }
            .font(.system(size: 18, weight: .bold, design: .rounded))

            if session.canCheckIn {
                Text("Next Check-In")
                    .font(.headline)
            }

            Text(session.nextCheckIn)
                .font(.caption)
                .foregroundColor(session.canCheckIn ? .primary : .secondary)
                .multilineTextAlignment(.center)

            if session.canCheckIn {
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
            }

            if let result = session.resultMessage {
                Text(result)
                    .font(.caption2)
                    .foregroundColor(result.contains("Checked in") ? .green : .orange)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .padding()
        .animation(.easeInOut(duration: 0.3), value: session.resultMessage)
        .animation(.easeInOut(duration: 0.3), value: session.canCheckIn)
    }
}

#Preview {
    SafePingWatchView()
}
