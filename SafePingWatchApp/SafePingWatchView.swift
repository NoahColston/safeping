// SafePing — SafePingWatchView.swift (watchOS target)
// Companion watch UI. Shows distinct states for check-in readiness:
//   • ready    — a check-in window is open right now
//   • waiting  — next check-in is scheduled but the window isn't open yet
//   • done     — all of today's check-ins are complete
//   • none     — no check-ins are scheduled
//   • syncing  — waiting for first data from the iPhone
//   • unreachable — phone is not reachable
//
// Communicates with the iOS app via WatchConnectivity (WCSession).
//
// [OOP] WatchSessionManager is an ObservableObject that wraps WCSession delegate.
// [Procedural] sendCheckIn() sequences: validate session → send message → update UI.

import SwiftUI
import WatchConnectivity

// MARK: - Watch check-in state

enum WatchCheckInState: Equatable {
    /// Initial state — no data received from the phone yet.
    case syncing
    /// A check-in window is currently open. `time` is the scheduled time,
    /// `deadline` is when the window closes.
    case ready(time: String, deadline: String)
    /// A check-in is scheduled but the window hasn't opened yet.
    case waiting(nextTime: String)
    /// All of today's check-ins are complete. `nextTime` is the next
    /// future slot (e.g. "Tomorrow 9:00 AM") or nil if none upcoming.
    case done(nextTime: String?)
    /// No check-in schedules exist at all.
    case noSchedule
    /// The paired iPhone is not reachable.
    case unreachable
}

// MARK: - Session manager

@MainActor
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var state: WatchCheckInState = .syncing
    @Published var resultMessage: String?
    @Published var isSending = false

    /// True only when a check-in window is currently open and we're not
    /// already mid-send.
    var canCheckIn: Bool {
        guard !isSending else { return false }
        if case .ready = state { return true }
        return false
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
            state = .unreachable
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
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        let status = message["status"] as? String ?? ""
        let nextCheckIn = message["nextCheckIn"] as? String ?? ""
        let deadline = message["deadline"] as? String

        Task { @MainActor in
            switch status {
            case "ready":
                self.state = .ready(
                    time: nextCheckIn,
                    deadline: deadline ?? ""
                )
            case "waiting":
                self.state = .waiting(nextTime: nextCheckIn)
            case "done":
                // If nextCheckIn is "All done for today" there's no upcoming
                // slot to show; otherwise it's a formatted future time.
                let upcoming: String? = (nextCheckIn == "All done for today") ? nil : nextCheckIn
                self.state = .done(nextTime: upcoming)
            case "none":
                self.state = .noSchedule
            default:
                break
            }
        }
    }
}

// MARK: - Watch UI

struct SafePingWatchView: View {
    @StateObject private var session = WatchSessionManager()

    var body: some View {
        VStack(spacing: 10) {
            // Brand header
            HStack(spacing: 0) {
                Text("Safe")
                    .foregroundColor(.white)
                Text("Ping")
                    .foregroundColor(.green)
            }
            .font(.system(size: 18, weight: .bold, design: .rounded))

            // State-specific content
            stateContent

            // Result message (shown briefly after a check-in attempt)
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
        .animation(.easeInOut(duration: 0.3), value: session.state)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch session.state {

        // ── Ready: check-in window is open ──
        case .ready(let time, let deadline):
            VStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Time to Check In")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)

                Text(time)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                if !deadline.isEmpty {
                    Text("Window closes at \(deadline)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Button(action: { session.sendCheckIn() }) {
                    if session.isSending {
                        ProgressView()
                    } else {
                        Label("Check In Now", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(session.isSending)
            }

        // ── Waiting: next check-in hasn't opened yet ──
        case .waiting(let nextTime):
            VStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundColor(.blue)

                Text("Next Check-In")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text(nextTime)
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Not time yet")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

        // ── Done: all today's check-ins complete ──
        case .done(let nextTime):
            VStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                Text("All Done for Today!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)

                if let next = nextTime {
                    Text("Next: \(next)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

        // ── No schedule: nothing configured ──
        case .noSchedule:
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.minus")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text("No Check-Ins Scheduled")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Open SafePing on\nyour iPhone to set up")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

        // ── Syncing: waiting for first data from phone ──
        case .syncing:
            VStack(spacing: 6) {
                ProgressView()
                    .tint(.green)

                Text("Syncing with iPhone…")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

        // ── Unreachable: phone not connected ──
        case .unreachable:
            VStack(spacing: 6) {
                Image(systemName: "iphone.slash")
                    .font(.title3)
                    .foregroundColor(.orange)

                Text("iPhone Not Reachable")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.orange)

                Text("Make sure SafePing\nis open on your phone")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    SafePingWatchView()
}
