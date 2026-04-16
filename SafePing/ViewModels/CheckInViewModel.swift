import Foundation
import SwiftUI
import FirebaseFirestore
import CoreLocation

@MainActor
class CheckInViewModel: ObservableObject {
    @Published var pairings: [Pairing] = []
    @Published var selectedPairingId: UUID?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let pairingService = PairingService()
    private var pairsListener: ListenerRegistration?
    private var checkInListeners: [UUID: ListenerRegistration] = [:]

    
    var selectedPairing: Pairing? {
        guard let id = selectedPairingId else { return pairings.first }
        return pairings.first { $0.id == id }
    }
    
    var selectedPairingIndex: Int? {
        guard let id = selectedPairingId ?? pairings.first?.id else { return nil }
        return pairings.firstIndex { $0.id == id }
    }
    
    // MARK: - Stop all listeners
    func stopListening() {
        pairsListener?.remove()
        pairsListener = nil
        checkInListeners.values.forEach { $0.remove() }
        checkInListeners.removeAll()
    }
    
    // MARK: - Load data and start live listeners
    func loadData(for username: String, role: UserRole) async {
        isLoading = true
        errorMessage = nil
        stopListening()

        let field = role == .checker ? "checkerUsername" : "checkInUsername"

        pairsListener = db.collection("pairs")
            .whereField(field, isEqualTo: username)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handlePairsSnapshot(
                        snapshot,
                        error: error,
                        username: username,
                        role: role
                    )
                }
            }
    }

    @MainActor
    private func handlePairsSnapshot(
        _ snapshot: QuerySnapshot?,
        error: Error?,
        username: String,
        role: UserRole
    ) async {
        defer { isLoading = false }
        
        if let error = error {
            errorMessage = error.localizedDescription
            return
        }
        guard let documents = snapshot?.documents else {
            errorMessage = "Pairs snapshot was empty or missing."
            return
        }
        
        // Build the new pairings list, preserving any check-ins we've already
        // loaded so the calendar doesn't flicker between snapshots.
        var loadedPairings: [Pairing] = []
        for doc in documents {
            let data = doc.data()
            guard
                let checkerUsername = data["checkerUsername"] as? String,
                let checkInUsername = data["checkInUsername"] as? String
            else { continue }
            
            let storedId = UUID(uuidString: doc.documentID) ?? UUID()
            let currentStreak = data["currentStreak"] as? Int ?? 0
            let pairedAt = (data["pairedAt"] as? Timestamp)?.dateValue() ?? Date()
            
            let schedules: [CheckInSchedule]
            if let arr = data["schedules"] as? [[String: Any]] {
                schedules = arr.map { CheckInSchedule.fromFirestore($0) }
            } else if let single = data["schedule"] as? [String: Any] {
                schedules = [CheckInSchedule.fromFirestore(single)]
            } else {
                schedules = [CheckInSchedule()]
            }
            
            let existingCheckIns = pairings.first(where: { $0.id == storedId })?.checkIns ?? []
            
            loadedPairings.append(Pairing(
                id: storedId,
                checkerUsername: checkerUsername,
                checkInUsername: checkInUsername,
                schedules: schedules,
                checkIns: existingCheckIns,
                currentStreak: currentStreak,
                pairedAt: pairedAt
            ))
        }
        
        // Diff against current pairings to start/stop per-pairing check-in listeners
        let oldIds = Set(pairings.map { $0.id })
        let newIds = Set(loadedPairings.map { $0.id })
        
        pairings = loadedPairings
        
        if selectedPairingId == nil || !pairings.contains(where: { $0.id == selectedPairingId }) {
            selectedPairingId = pairings.first?.id
        }
        
        // Stop listeners for pairings that were removed
        for removedId in oldIds.subtracting(newIds) {
            checkInListeners[removedId]?.remove()
            checkInListeners.removeValue(forKey: removedId)
        }
        
        // Ensure every current pairing has an active listener.
        // This also fixes reloads after stopListening().
        for pairing in pairings {
            if checkInListeners[pairing.id] == nil {
                startCheckInListener(for: pairing)
            }
        }
        
        // Client-side missed-day backfill (still fires only when checkee opens app)
        if role == .checkInUser {
            for index in pairings.indices {
                await processMissedDays(at: index, username: username)
            }
        }
    }
    
    // MARK: - Process missed days on app foreground
    private func processMissedDays(at index: Int, username: String) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }

        let pairing = pairings[index]
        
        let pairedDay = calendar.startOfDay(for: pairing.pairedAt)
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let lookbackStart = max(thirtyDaysAgo, pairedDay)
        var newCheckIns: [CheckIn] = []

        // Walk each schedule independently so every slot gets its own
        // missed record when no check-in exists for that (day, slot).
        for schedule in pairing.schedules {
            let recordedDays: Set<Date> = Set(
                pairing.checkIns
                    .filter { $0.scheduleId == schedule.id || $0.scheduleId == nil }
                    .map { calendar.startOfDay(for: $0.date) }
            )

            var cursor = lookbackStart
            while cursor <= yesterday {
                let weekday = calendar.component(.weekday, from: cursor)
                if schedule.isScheduled(weekday: weekday) && !recordedDays.contains(cursor) {
                    newCheckIns.append(CheckIn(
                        pairingId: pairing.id,
                        scheduleId: schedule.id,
                        date: cursor,
                        status: .missed
                    ))
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }

        guard !newCheckIns.isEmpty else { return }

        pairings[index].checkIns.append(contentsOf: newCheckIns)
        let newStreak = recomputeStreak(for: pairings[index])
        pairings[index].currentStreak = 0

        do {
            for ci in newCheckIns {
                let dayKey = Int(ci.date.timeIntervalSince1970)
                let scheduleKey = ci.scheduleId?.uuidString ?? "legacy"
                let docId = "\(pairing.id.uuidString)_\(scheduleKey)_missed_\(dayKey)"
                let data: [String: Any] = [
                    "id": ci.id.uuidString,
                    "pairingId": pairing.id.uuidString,
                    "scheduleId": scheduleKey,
                    "username": username,
                    "date": Timestamp(date: ci.date),
                    "status": CheckInStatus.missed.rawValue
                ]
                try await db.collection("checkIns").document(docId).setData(data)
            }
            try await db.collection("pairs")
                .document(pairing.id.uuidString)
                .updateData(["currentStreak": newStreak])
        } catch {
            errorMessage = "Failed to record missed days for pairing \(pairing.id.uuidString): \(error.localizedDescription)"
        }
    }
    
    // MARK: - Live listener for a checkee's check-ins
    private func startCheckInListener(for pairing: Pairing) {
        // avoid duplicate listeners
        checkInListeners[pairing.id]?.remove()
        
        let listener = db.collection("checkIns")
            .whereField("pairingId", isEqualTo: pairing.id.uuidString)
            .order(by: "date", descending: true)
            .limit(to: 90)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Check-in listener error for pairing \(pairing.id.uuidString): \(error.localizedDescription)")
                    Task { @MainActor in
                        self.errorMessage = "Failed to load check-ins for \(pairing.checkInUsername): \(error.localizedDescription)"
                    }
                    return
                }
                guard let documents = snapshot?.documents else {
                    print("No snapshot returned for pairing:", pairing.id.uuidString)
                    Task { @MainActor in
                        self.errorMessage = "No snapshot returned for \(pairing.checkInUsername)."
                    }
                    return
                }
                
                print("Received \(documents.count) check-in docs for pairing \(pairing.id.uuidString)")
                
                let checkIns = documents.compactMap { doc -> CheckIn? in
                    let data = doc.data()
                    guard
                        let pairingIdString = data["pairingId"] as? String,
                        let pairingId = UUID(uuidString: pairingIdString),
                        let timestamp = data["date"] as? Timestamp,
                        let statusRaw = data["status"] as? String,
                        let status = CheckInStatus(rawValue: statusRaw)
                    else { return nil }
                    
                    let id = (data["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
                    let scheduleId = (data["scheduleId"] as? String).flatMap(UUID.init(uuidString:))
                    
                    return CheckIn(
                        id: id,
                        pairingId: pairingId,
                        scheduleId: scheduleId,
                        date: timestamp.dateValue(),
                        status: status,
                        latitude: data["latitude"] as? Double,
                        longitude: data["longitude"] as? Double
                    )
                }
                
                print("Decoded \(checkIns.count) check-ins for pairing \(pairing.id.uuidString)")
                
                Task { @MainActor in
                    if checkIns.count != documents.count {
                        self.errorMessage = "Loaded \(checkIns.count) of \(documents.count) check-ins for \(pairing.checkInUsername). Some documents may be malformed."
                    } else {
                        self.errorMessage = nil
                    }

                    guard let index = self.pairings.firstIndex(where: { $0.id == pairing.id }) else { return }

                    var updatedPairings = self.pairings
                    updatedPairings[index].checkIns = checkIns
                    self.pairings = updatedPairings
                }
            }
        
        checkInListeners[pairing.id] = listener
    }
    
    // --- Scheuling methods --
    
    
    // MARK: - Select Pairing
    func selectPairing(_ pairing: Pairing) {
        selectedPairingId = pairing.id
    }
    
    // MARK: - Schedule CRUD

    /// Add a new default schedule to the selected pairing.
    func addSchedule(to pairingId: UUID? = nil) {
        let targetId = pairingId ?? selectedPairingId
        guard let id = targetId,
              let index = pairings.firstIndex(where: { $0.id == id }) else { return }
        pairings[index].schedules.append(CheckInSchedule())
        let pairing = pairings[index]
        Task { await saveSchedules(for: pairing.id, schedules: pairing.schedules) }
    }

    func removeSchedule(_ scheduleId: UUID, from pairingId: UUID? = nil) {
        let targetId = pairingId ?? selectedPairingId
        guard let id = targetId,
              let index = pairings.firstIndex(where: { $0.id == id }) else { return }
        guard pairings[index].schedules.count > 1 else { return }
        pairings[index].schedules.removeAll { $0.id == scheduleId }
        let pairing = pairings[index]
        Task { await saveSchedules(for: pairing.id, schedules: pairing.schedules) }
    }

    func updateScheduleTime(_ time: Date, scheduleId: UUID, in pairingId: UUID? = nil) {
        mutateSchedule(scheduleId, in: pairingId) { $0.time = time }
    }

    func updateScheduleFrequency(_ frequency: CheckInFrequency, scheduleId: UUID, in pairingId: UUID? = nil) {
        mutateSchedule(scheduleId, in: pairingId) { $0.frequency = frequency }
    }

    func updateScheduleMessage(_ message: String, scheduleId: UUID, in pairingId: UUID? = nil) {
        mutateSchedule(scheduleId, in: pairingId) { $0.message = message }
    }

    func toggleScheduleDay(_ weekday: Int, scheduleId: UUID, in pairingId: UUID? = nil) {
        mutateSchedule(scheduleId, in: pairingId) { schedule in
            if schedule.activeDays.contains(weekday) {
                if schedule.activeDays.count > 1 {
                    schedule.activeDays.remove(weekday)
                }
            } else {
                schedule.activeDays.insert(weekday)
            }
        }
    }

    private func mutateSchedule(
        _ scheduleId: UUID,
        in pairingId: UUID?,
        _ mutation: (inout CheckInSchedule) -> Void
    ) {
        let targetId = pairingId ?? selectedPairingId
        guard let id = targetId,
              let pairingIndex = pairings.firstIndex(where: { $0.id == id }),
              let scheduleIndex = pairings[pairingIndex].schedules.firstIndex(where: { $0.id == scheduleId })
        else { return }
        mutation(&pairings[pairingIndex].schedules[scheduleIndex])
        let pairing = pairings[pairingIndex]
        Task { await saveSchedules(for: pairing.id, schedules: pairing.schedules) }
    }

    private func saveSchedules(for pairingId: UUID, schedules: [CheckInSchedule]) async {
        do {
            try await db.collection("pairs")
                .document(pairingId.uuidString)
                .updateData([
                    "schedules": schedules.map { $0.toFirestore() },
                ])
        } catch {
            errorMessage = "Failed to save schedule: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Story 13: Unpair a user
    func unpairUser(_ pairing: Pairing) async {
        do {
            try await pairingService.removePairing(pairingId: pairing.id)
            pairings.removeAll { $0.id == pairing.id }
            checkInListeners[pairing.id]?.remove()
            checkInListeners.removeValue(forKey: pairing.id)
            if selectedPairingId == pairing.id {
                selectedPairingId = pairings.first?.id
            }
        } catch {
            errorMessage = "Failed to unpair: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Streak calculation
    /// Walks backward from today counting consecutive scheduled days where
    /// every slot was checked in. Days with no scheduled slots are skipped.
    /// For the current day,if its slots aren't all done yet, we don't count it but also don't
    /// dont treat it as a break, so an in-progress day does not reset the streak.
    private func recomputeStreak(for pairing: Pairing) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pairedDay = calendar.startOfDay(for: pairing.pairedAt)

        var streak = 0
        var cursor = today
        var isFirstDay = true

        for _ in 0..<365 {
            if cursor < pairedDay { break }

            let activeSchedules = pairing.schedules(forDate: cursor)
            if activeSchedules.isEmpty {
                // No obligations this day —> skip without counting or breaking.
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
                isFirstDay = false
                continue
            }

            let allCheckedIn = activeSchedules.allSatisfy { schedule in
                pairing.status(for: cursor, scheduleId: schedule.id) == .checkedIn
            }

            if allCheckedIn {
                streak += 1
            } else if !isFirstDay {
                // A prior scheduled day was incomplete -> streak ends here.
                break
            }
            // else: today with incomplete slots -> in progress, keep going.

            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
            isFirstDay = false
        }

        return streak
    }
    
    // MARK: - Perform Check-In (saves to Firebase)
    func performCheckIn(
        username: String,
        scheduleId: UUID,
        location: CLLocationCoordinate2D? = nil
    ) async {
        guard let index = selectedPairingIndex else { return }
        let today = Date()
        let pairingId = pairings[index].id

        // Remove any pending/missed placeholder for this slot today
        pairings[index].checkIns.removeAll { ci in
            Calendar.current.isDate(ci.date, inSameDayAs: today)
                && (ci.scheduleId == scheduleId || ci.scheduleId == nil)
                && ci.status != .checkedIn
        }
        let newCheckIn = CheckIn(
            pairingId: pairingId,
            scheduleId: scheduleId,
            date: today,
            status: .checkedIn,
            latitude: location?.latitude,
            longitude: location?.longitude
        )
        pairings[index].checkIns.insert(newCheckIn, at: 0)

        let newStreak = recomputeStreak(for: pairings[index])
        pairings[index].currentStreak = newStreak

        do {
            // Doc ID bucketed by (pairing, schedule, day) — repeated taps
            // on the same slot overwrite rather than duplicate.
            let dayKey = Int(Calendar.current.startOfDay(for: today).timeIntervalSince1970)
            let docId = "\(pairingId.uuidString)_\(scheduleId.uuidString)_\(dayKey)"

            var data: [String: Any] = [
                "id": newCheckIn.id.uuidString,
                "pairingId": pairingId.uuidString,
                "scheduleId": scheduleId.uuidString,
                "username": username,
                "date": Timestamp(date: today),
                "status": CheckInStatus.checkedIn.rawValue
            ]

            if let location {
                data["latitude"] = location.latitude
                data["longitude"] = location.longitude
            }

            try await db.collection("checkIns").document(docId).setData(data)
            try await db.collection("pairs")
                .document(pairingId.uuidString)
                .updateData(["currentStreak": newStreak])
        } catch {
            errorMessage = "Failed to save check-in for pairing \(pairingId.uuidString): \(error.localizedDescription)"
        }
    }
}
