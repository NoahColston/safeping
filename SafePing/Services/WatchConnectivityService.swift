// SafePing — WatchConnectivityService.swift
// iOS-side WatchConnectivity handler. Receives check-in messages from the
// companion Apple Watch app and writes them to Firestore. Also pushes the
// next scheduled check-in time to the watch when pairings change.

import Foundation
import WatchConnectivity
import FirebaseFirestore

class WatchConnectivityService: NSObject, ObservableObject, WCSessionDelegate {

    private let db = Firestore.firestore()

    
    /// Cached pairings so we can re-send to the watch when it becomes
    /// reachable without needing the dashboard to be on screen.
    private var cachedPairings: [Pairing] = []

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
        cachedPairings = pairings
        pushNextCheckIn()
    }

    /// Sends the cached next check-in status to the watch.
    /// Now sends a richer dictionary with a `status` field so the watch
    /// can display distinct UI for each state.
    private func pushNextCheckIn() {
        guard WCSession.default.isReachable else { return }

        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()

        // 1. Check if any slot is currently in its check-in window (ready).
        var readySlot: (time: Date, deadline: Date)? = nil
        for pairing in cachedPairings {
            let todaysSchedules = pairing.schedules(forDate: now)
            for schedule in todaysSchedules {
                // Skip already-checked-in slots
                if pairing.status(for: now, scheduleId: schedule.id) == .checkedIn {
                    continue
                }
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = schedule.hour
                components.minute = schedule.minute
                guard let scheduledTime = calendar.date(from: components) else { continue }
                let earliestAllowed = calendar.date(byAdding: .minute, value: -15, to: scheduledTime)!
                let latestAllowed = calendar.date(byAdding: .minute, value: schedule.gracePeriodMinutes, to: scheduledTime)!
                if now >= earliestAllowed && now <= latestAllowed {
                    if readySlot == nil || scheduledTime < readySlot!.time {
                        readySlot = (scheduledTime, latestAllowed)
                    }
                }
            }
        }

        if let slot = readySlot {
            formatter.dateFormat = "h:mm a"
            let timeStr = formatter.string(from: slot.time)
            let deadlineStr = formatter.string(from: slot.deadline)
            WCSession.default.sendMessage(
                [
                    "status": "ready",
                    "nextCheckIn": timeStr,
                    "deadline": deadlineStr
                ],
                replyHandler: nil,
                errorHandler: nil
            )
            return
        }

        // 2. Find the next future occurrence across all pairings.
        let nextTimes = cachedPairings.compactMap { $0.nextScheduledOccurrence }
        guard let earliest = nextTimes.min() else {
            // No upcoming slots at all — either no schedules or no pairings.
            // Figure out if everything today is done vs. nothing scheduled.
            let anyTodaySchedules = cachedPairings.contains { pairing in
                !pairing.schedules(forDate: now).isEmpty
            }
            let allTodayDone = anyTodaySchedules && cachedPairings.allSatisfy { pairing in
                let todaysSchedules = pairing.schedules(forDate: now)
                return todaysSchedules.allSatisfy { schedule in
                    pairing.status(for: now, scheduleId: schedule.id) == .checkedIn
                }
            }
            if allTodayDone {
                WCSession.default.sendMessage(
                    ["status": "done", "nextCheckIn": "All done for today"],
                    replyHandler: nil,
                    errorHandler: nil
                )
            } else {
                WCSession.default.sendMessage(
                    ["status": "none", "nextCheckIn": "No check-ins scheduled"],
                    replyHandler: nil,
                    errorHandler: nil
                )
            }
            return
        }

        // 3. There's a future slot — is it today or a later day?
        let isToday = calendar.isDateInToday(earliest)

        // Check if all of today's slots are already done
        let allTodayDone = cachedPairings.allSatisfy { pairing in
            let todaysSchedules = pairing.schedules(forDate: now)
            guard !todaysSchedules.isEmpty else { return true }
            return todaysSchedules.allSatisfy { schedule in
                pairing.status(for: now, scheduleId: schedule.id) == .checkedIn
            }
        }

        if allTodayDone && !isToday {
            // Everything today is done; next slot is tomorrow or later.
            formatter.dateFormat = "EEE h:mm a"
            WCSession.default.sendMessage(
                [
                    "status": "done",
                    "nextCheckIn": formatter.string(from: earliest)
                ],
                replyHandler: nil,
                errorHandler: nil
            )
        } else {
            // Waiting for a future slot (could be later today or another day).
            if isToday {
                formatter.dateFormat = "h:mm a"
            } else {
                formatter.dateFormat = "EEE h:mm a"
            }
            WCSession.default.sendMessage(
                [
                    "status": "waiting",
                    "nextCheckIn": formatter.string(from: earliest)
                ],
                replyHandler: nil,
                errorHandler: nil
            )
        }
    }

    // MARK: - Watch became reachable — push latest data

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            pushNextCheckIn()
        }
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

                    // Check-in window: 15 min before scheduled time → scheduled time + grace period
                    let earliestAllowed = calendar.date(byAdding: .minute, value: -15, to: scheduledTime)!
                    let latestAllowed = calendar.date(byAdding: .minute, value: schedule.gracePeriodMinutes, to: scheduledTime)!
                    guard now >= earliestAllowed && now <= latestAllowed else { continue }

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
                await pushNextCheckInAfterWatchAction(username: username)
                return "Checked in! (\(checkedInCount) slot\(checkedInCount == 1 ? "" : "s"))"
            } else {
                return "No slots available right now"
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    /// After a watch-initiated check-in, compute the next unchecked slot
    /// and send it to the watch directly from Firestore data.
    private func pushNextCheckInAfterWatchAction(username: String) async {
        guard WCSession.default.isReachable else { return }
        let calendar = Calendar.current
        let now = Date()

        do {
            let pairsSnapshot = try await db.collection("pairs")
                .whereField("checkInUsername", isEqualTo: username)
                .getDocuments()

            var candidates: [Date] = []
            var hasReadySlot = false
            var readyTime: Date?
            var readyDeadline: Date?

            for pairDoc in pairsSnapshot.documents {
                let pairData = pairDoc.data()
                let pairingId = pairDoc.documentID
                guard let schedulesArr = pairData["schedules"] as? [[String: Any]] else { continue }
                let schedules = schedulesArr.map { CheckInSchedule.fromFirestore($0) }

                for schedule in schedules {
                    // Check if there's a currently-open window first
                    let weekdayToday = calendar.component(.weekday, from: now)
                    if schedule.isScheduled(weekday: weekdayToday) {
                        var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
                        todayComponents.hour = schedule.hour
                        todayComponents.minute = schedule.minute
                        if let scheduledTime = calendar.date(from: todayComponents) {
                            let earliestAllowed = calendar.date(byAdding: .minute, value: -15, to: scheduledTime)!
                            let latestAllowed = calendar.date(byAdding: .minute, value: schedule.gracePeriodMinutes, to: scheduledTime)!

                            if now >= earliestAllowed && now <= latestAllowed {
                                // Check if already checked in
                                let dayKey = Int(calendar.startOfDay(for: now).timeIntervalSince1970)
                                let docId = "\(pairingId)_\(schedule.id.uuidString)_\(dayKey)"
                                let existing = try await db.collection("checkIns").document(docId).getDocument()
                                let alreadyDone = existing.data().flatMap { $0["status"] as? String } == CheckInStatus.checkedIn.rawValue
                                if !alreadyDone {
                                    if readyTime == nil || scheduledTime < readyTime! {
                                        hasReadySlot = true
                                        readyTime = scheduledTime
                                        readyDeadline = latestAllowed
                                    }
                                }
                            }
                        }
                    }

                    // Also find the next future occurrence
                    for offset in 0...7 {
                        guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                        let weekday = calendar.component(.weekday, from: day)
                        guard schedule.isScheduled(weekday: weekday) else { continue }
                        var components = calendar.dateComponents([.year, .month, .day], from: day)
                        components.hour = schedule.hour
                        components.minute = schedule.minute
                        guard let occurrence = calendar.date(from: components), occurrence > now else { continue }

                        // Check if already checked in for this slot
                        let dayKey = Int(calendar.startOfDay(for: day).timeIntervalSince1970)
                        let docId = "\(pairingId)_\(schedule.id.uuidString)_\(dayKey)"
                        let existing = try await db.collection("checkIns").document(docId).getDocument()
                        if let data = existing.data(),
                           let status = data["status"] as? String,
                           status == CheckInStatus.checkedIn.rawValue {
                            continue
                        }

                        candidates.append(occurrence)
                        break
                    }
                }
            }

            let formatter = DateFormatter()

            if hasReadySlot, let rTime = readyTime, let rDeadline = readyDeadline {
                formatter.dateFormat = "h:mm a"
                WCSession.default.sendMessage(
                    [
                        "status": "ready",
                        "nextCheckIn": formatter.string(from: rTime),
                        "deadline": formatter.string(from: rDeadline)
                    ],
                    replyHandler: nil,
                    errorHandler: nil
                )
            } else if let earliest = candidates.min() {
                let isToday = calendar.isDateInToday(earliest)
                formatter.dateFormat = isToday ? "h:mm a" : "EEE h:mm a"
                WCSession.default.sendMessage(
                    [
                        "status": "waiting",
                        "nextCheckIn": formatter.string(from: earliest)
                    ],
                    replyHandler: nil,
                    errorHandler: nil
                )
            } else {
                WCSession.default.sendMessage(
                    [
                        "status": "done",
                        "nextCheckIn": "All done for today"
                    ],
                    replyHandler: nil,
                    errorHandler: nil
                )
            }
        } catch {
            // Non-fatal — watch will show stale data until next sync
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
