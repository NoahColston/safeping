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
    private var listeners: [ListenerRegistration] = []
    
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
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Restart listeners for current pairings
    private func restartListeners() {
        stopListening()
        for pairing in pairings {
            startCheckInListener(for: pairing)
        }
    }
    
    // MARK: - Load data and start live listeners
    func loadData(for username: String, role: UserRole) async {
        isLoading = true
        errorMessage = nil
        stopListening()
        
        let field = role == .checker ? "checkerUsername" : "checkInUsername"
        
        do {
            let snapshot = try await db.collection("pairs")
                .whereField(field, isEqualTo: username)
                .getDocuments()
            
            var loadedPairings: [Pairing] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                guard
                    let checkerUsername = data["checkerUsername"] as? String,
                    let checkInUsername = data["checkInUsername"] as? String
                else { continue }
                
                // Use the stored Firestore doc ID as the pairing UUID so unpair/updates work
                let storedId = UUID(uuidString: doc.documentID) ?? UUID()
                let customMsg = data["customReminderMessage"] as? String ?? ""
                let scheduleData = data["schedule"] as? [String: Any]
                let schedule = scheduleData.map { CheckInSchedule.fromFirestore($0)} ?? CheckInSchedule()
                let checkIns = try await fetchCheckIns(for: storedId)
                let currentStreak = data["currentStreak"] as? Int ?? 0
                
                let pairing = Pairing(
                    id: storedId,
                    checkerUsername: checkerUsername,
                    checkInUsername: checkInUsername,
                    schedule: schedule,
                    checkIns: checkIns,
                    customReminderMessage: customMsg,
                    currentStreak: currentStreak
                )
                loadedPairings.append(pairing)
            }
            
            pairings = loadedPairings
            if selectedPairingId == nil || !pairings.contains(where: { $0.id == selectedPairingId }) {
                selectedPairingId = pairings.first?.id
            }
            
            for pairing in pairings {
                startCheckInListener(for: pairing)
            }
            
            // NOTE: This is a client-side implementation. It only fires when
            // the check-in user opens the app.
            if role == .checkInUser {
                for index in pairings.indices {
                    await processMissedDays(at: index, username: username)
                }
            }
            
        } catch {
            errorMessage = error.localizedDescription
            pairings = []
        }
        
        isLoading = false
    }
    
    // MARK: - Process missed days on app foreground
    
    private func processMissedDays(at index: Int, username: String) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Yesterday is the last day that could possibly have been missed.
        // Today is excluded — the user still has time to check in.
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        
        let pairing = pairings[index]
        
        // Determine the start of the window to check.
        // If there are existing records, start the day after the most recent one.
        // Otherwise, look back a maximum of 30 days.
        let mostRecentRecordDate = pairing.checkIns
            .map { calendar.startOfDay(for: $0.date) }
            .max()
        
        let lookbackStart = calendar.date(byAdding: .day, value: -30, to: today)!
        let windowStart: Date
        if let mostRecent = mostRecentRecordDate {
            let dayAfterMostRecent = calendar.date(byAdding: .day, value: 1, to: mostRecent)!
            // Use whichever is more recent — the day after the last record, or 30 days ago.
            // This prevents reprocessing a large backlog if there's a long-ago check-in.
            windowStart = max(dayAfterMostRecent, lookbackStart)
        } else {
            windowStart = lookbackStart
        }
        
        // Nothing to process if the window is empty
        guard windowStart <= yesterday else { return }
        
        // Collect all dates that already have a record so we can skip them efficiently
        let recordedDays = Set(pairing.checkIns.map { calendar.startOfDay(for: $0.date) })
        
        var missedDates: [Date] = []
        var cursor = windowStart
        
        while cursor <= yesterday {
            let weekday = calendar.component(.weekday, from: cursor)
            
            if pairing.schedule.isScheduled(weekday: weekday) && !recordedDays.contains(cursor) {
                missedDates.append(cursor)
            }
            
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        
        guard !missedDates.isEmpty else { return }
        
        // Apply missed records locally for immediate UI update
        let newCheckIns = missedDates.map {
            CheckIn(pairingId: pairing.id, date: $0, status: .missed)
        }
        pairings[index].checkIns.append(contentsOf: newCheckIns)
        
        // The streak is broken — any missed scheduled day resets it to 0.
        // The next successful check-in will start a fresh streak from 1.
        pairings[index].currentStreak = 0
        
        // Persist to Firestore
        do {
            for checkIn in newCheckIns {
                let data: [String: Any] = [
                    "id": checkIn.id.uuidString,
                    "pairingId": pairing.id.uuidString,
                    "username": username,
                    "date": Timestamp(date: checkIn.date),
                    "status": CheckInStatus.missed.rawValue
                ]
                // Document ID uses midnight timestamp to match the date granularity
                // and avoid duplicates if this runs more than once for the same day
                try await db.collection("checkIns")
                    .document("\(pairing.id.uuidString)_missed_\(Int(checkIn.date.timeIntervalSince1970))")
                    .setData(data)
            }
            
            try await db.collection("pairs")
                .document(pairing.id.uuidString)
                .updateData(["currentStreak": 0])
            
        } catch {
            errorMessage = "Failed to record missed days: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Live listener for a checkee's check-ins
    private func startCheckInListener(for pairing: Pairing) {
        let listener = db.collection("checkIns")
            .whereField("pairingId", isEqualTo: pairing.id.uuidString)
            .order(by: "date", descending: true)
            .limit(to: 30)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
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
                    return CheckIn(
                        id: id,
                        pairingId: pairingId,
                        date: timestamp.dateValue(),
                        status: status,
                        latitude: data["latitude"] as? Double,
                        longitude: data["longitude"] as? Double
                    )
                }
                
                Task { @MainActor in
                    if let index = self.pairings.firstIndex(where: { $0.id == pairing.id }) {
                        self.pairings[index].checkIns = checkIns
                    }
                }
            }
        
        listeners.append(listener)
    }
    
    // MARK: - Fetch check-ins once
    private func fetchCheckIns(for pairingId: UUID) async throws -> [CheckIn] {
        let snapshot = try await db.collection("checkIns")
            .whereField("pairingId", isEqualTo: pairingId.uuidString)
            .order(by: "date", descending: true)
            .limit(to: 30)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let pairingIdString = data["pairingId"] as? String,
                let pairingId = UUID(uuidString: pairingIdString),
                let timestamp = data["date"] as? Timestamp,
                let statusRaw = data["status"] as? String,
                let status = CheckInStatus(rawValue: statusRaw)
            else { return nil }
            let id = (data["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
            return CheckIn(
                id: id,
                pairingId: pairingId,
                date: timestamp.dateValue(),
                status: status,
                latitude: data["latitude"] as? Double,
                longitude: data["longitude"] as? Double
            )
        }
    }
    // MARK: - Select Pairing
    func selectPairing(_ pairing: Pairing) {
        selectedPairingId = pairing.id
    }
    
    // MARK: - Update Schedule
    func updateScheduleTime(_ time: Date) {
        guard let index = selectedPairingIndex else { return }
        pairings[index].schedule.time = time
        let pairing = pairings[index]
        Task { await saveSchedule(for: pairing.id, schedule: pairing.schedule) }
    }
    
    func updateScheduleFrequency(_ frequency: CheckInFrequency) {
        guard let index = selectedPairingIndex else { return }
        pairings[index].schedule.frequency = frequency
        let pairing = pairings[index]
        Task { await saveSchedule(for: pairing.id, schedule: pairing.schedule) }
    }
    
    func toggleScheduleDay(_ weekday: Int) {
        guard let index = selectedPairingIndex else { return }
        if pairings[index].schedule.activeDays.contains(weekday) {
            if pairings[index].schedule.activeDays.count > 1 {
                pairings[index].schedule.activeDays.remove(weekday)
            }
        } else {
            pairings[index].schedule.activeDays.insert(weekday)
        }
        let pairing = pairings[index]
        Task { await saveSchedule(for: pairing.id, schedule: pairing.schedule) }
    }
    
    private func saveSchedule(for pairingId: UUID, schedule: CheckInSchedule) async {
        do {
            try await db.collection("pairs")
                .document(pairingId.uuidString)
                .updateData(["schedule": schedule.toFirestore()])
        } catch {
            errorMessage = "Failed to save schedule: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Story 14: Update custom reminder message
    func updateReminderMessage(_ message: String) async {
        guard let index = selectedPairingIndex else { return }
        let pairingId = pairings[index].id
        pairings[index].customReminderMessage = message
        do {
            try await db.collection("pairs")
                .document(pairingId.uuidString)
                .updateData(["customReminderMessage": message])
        } catch {
            errorMessage = "Failed to save message: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Story 13: Unpair a user
    func unpairUser(_ pairing: Pairing) async {
        do {
            try await pairingService.removePairing(pairingId: pairing.id)
            pairings.removeAll { $0.id == pairing.id }
            if selectedPairingId == pairing.id {
                selectedPairingId = pairings.first?.id
            }
            restartListeners()
        } catch {
            errorMessage = "Failed to unpair: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Perform Check-In (saves to Firebase)
    func performCheckIn(username: String, location: CLLocationCoordinate2D? = nil) async {
        guard let index = selectedPairingIndex else { return }
        let today = Date()
        let pairingId = pairings[index].id
        
        pairings[index].checkIns.removeAll { (checkIn: CheckIn) -> Bool in
            Calendar.current.isDate(checkIn.date, inSameDayAs: today) && checkIn.status == .pending
        }
        let newCheckIn = CheckIn(
            pairingId: pairingId,
            date: today,
            status: .checkedIn,
            latitude: location?.latitude,
            longitude: location?.longitude
        )
        pairings[index].checkIns.insert(newCheckIn, at: 0)
        
        pairings[index].currentStreak += 1
        let newStreak = pairings[index].currentStreak
        do {
            var data: [String: Any] = [
                "id": newCheckIn.id.uuidString,
                "pairingId": pairingId.uuidString,
                "username": username,
                "date": Timestamp(date: today),
                "status": CheckInStatus.checkedIn.rawValue
            ]
            
            // attach location if available
            if let location {
                data["latitude"] = location.latitude
                data["longitude"] = location.longitude
            }
            
            try await db.collection("checkIns")
                .document("\(pairingId.uuidString)_\(Int(today.timeIntervalSince1970))")
                .setData(data)
            
            try await db.collection("pairs")
                .document(pairingId.uuidString)
                .updateData(["currentStreak": newStreak])
            
        } catch {
            errorMessage = "Failed to save check-in: \(error.localizedDescription)"
        }
    }
}
