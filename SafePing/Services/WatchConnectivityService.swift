// SafePing — WatchConnectivityService.swift
// iOS-side WatchConnectivity handler. Receives check-in messages from the
// companion Apple Watch app and writes them to Firestore. Also pushes the
// next scheduled check-in time to the watch when pairings change.

import Foundation
import WatchConnectivity
import FirebaseFirestore

class WatchConnectivityService: NSObject, ObservableObject, WCSessionDelegate {

    private let db = Firestore.firestore()

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Push next check-in time to watch

    /// Call this whenever pairings load or change so the watch displays
    /// an up-to-date countdown. Safe to call when the watch is not
    /// reachable — the message is silently dropped.
    func sendNextCheckInToWatch(pairings: [Pairing]) {
        guard WCSession.default.isReachable else { return }

        // Find the earliest upcoming scheduled time across all pairings.
        let nextTimes = pairings.compactMap { $0.nextScheduledOccurrence }
        guard let earliest = nextTimes.min() else {
            WCSession.default.sendMessage(
                ["nextCheckIn": "No check-ins scheduled"],
                replyHandler: nil,
                errorHandler: nil
            )
            return
        }

        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(earliest) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "EEE h:mm a"
        }

        WCSession.default.sendMessage(
            ["nextCheckIn": formatter.string(from: earliest)],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    // MARK: - Receive check-in from watch

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let action = message["action"] as? String, action == "checkIn" else {
            replyHandler(["result": "Unknown action"])
            return
        }

        Task {
            let result = await handleWatchCheckIn()
            replyHandler(["result": result])
        }
    }

    /// Performs a check-in for the currently logged-in user's next
    /// available schedule slot. Mirrors the logic in
    /// NotificationService.saveCheckInFromNotification.
    private func handleWatchCheckIn() async -> String {
        // Look up the logged-in user
        guard let username = UserDefaults.standard.string(forKey: "currentUsername") else {
            return "Not logged in"
        }

        // Find pairings where this user is the check-in user
        do {
            let pairsSnapshot = try await db.collection("pairs")
                .whereField("checkInUsername", isEqualTo: username)
                .getDocuments()

            guard !pairsSnapshot.documents.isEmpty else {
                return "No pairings found"
            }

            let calendar = Calendar.current
            let now = Date()
            var checkedInCount = 0

            for pairDoc in pairsSnapshot.documents {
                let pairData = pairDoc.data()
                let pairingId = pairDoc.documentID

                guard let schedulesArr = pairData["schedules"] as? [[String: Any]] else {
                    continue
                }

                let schedules = schedulesArr.map { CheckInSchedule.fromFirestore($0) }
                let weekday = calendar.component(.weekday, from: now)

                for schedule in schedules {
                    // Only check in for schedules active today
                    guard schedule.isScheduled(weekday: weekday) else { continue }

                    // Build scheduled time for today
                    var components = calendar.dateComponents([.year, .month, .day], from: now)
                    components.hour = schedule.hour
                    components.minute = schedule.minute
                    guard let scheduledTime = calendar.date(from: components) else { continue }

                    // Must be within the check-in window (no earlier than 15 min before)
                    let earliestAllowed = calendar.date(byAdding: .minute, value: -15, to: scheduledTime)!
                    guard now >= earliestAllowed else { continue }

                    // Check if already checked in for this slot today
                    let dayKey = Int(calendar.startOfDay(for: now).timeIntervalSince1970)
                    let docId = "\(pairingId)_\(schedule.id.uuidString)_\(dayKey)"

                    let existing = try await db.collection("checkIns").document(docId).getDocument()
                    if let data = existing.data(),
                       let status = data["status"] as? String,
                       status == CheckInStatus.checkedIn.rawValue {
                        // Already checked in for this slot
                        continue
                    }

                    // Write the check-in
                    let checkInData: [String: Any] = [
                        "id": UUID().uuidString,
                        "pairingId": pairingId,
                        "scheduleId": schedule.id.uuidString,
                        "username": username,
                        "date": Timestamp(date: now),
                        "status": CheckInStatus.checkedIn.rawValue
                    ]
                    try await db.collection("checkIns").document(docId).setData(checkInData)
                    checkedInCount += 1
                }
            }

            if checkedInCount > 0 {
                return "Checked in! (\(checkedInCount) slot\(checkedInCount == 1 ? "" : "s"))"
            } else {
                return "No slots available right now"
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Required WCSessionDelegate methods (iOS)

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after switching watch devices
        WCSession.default.activate()
    }
}
