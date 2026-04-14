import Foundation
import SwiftUI
import FirebaseFirestore

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
            startCheckInListener(for: pairing.checkInUsername)
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
                let checkIns = try await fetchCheckIns(for: checkInUsername)

                let pairing = Pairing(
                    id: storedId,
                    checkerUsername: checkerUsername,
                    checkInUsername: checkInUsername,
                    schedule: schedule,
                    checkIns: checkIns,
                    customReminderMessage: customMsg
                )
                loadedPairings.append(pairing)
            }

            pairings = loadedPairings
            if selectedPairingId == nil || !pairings.contains(where: { $0.id == selectedPairingId }) {
                selectedPairingId = pairings.first?.id
            }

            for pairing in pairings {
                startCheckInListener(for: pairing.checkInUsername)
            }

        } catch {
            errorMessage = error.localizedDescription
            pairings = []
        }

        isLoading = false
    }

    // MARK: - Live listener for a checkee's check-ins
    private func startCheckInListener(for username: String) {
        let listener = db.collection("checkIns")
            .whereField("username", isEqualTo: username)
            .order(by: "date", descending: true)
            .limit(to: 30)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }

                let checkIns = documents.compactMap { doc -> CheckIn? in
                    let data = doc.data()
                    guard
                        let timestamp = data["date"] as? Timestamp,
                        let statusRaw = data["status"] as? String,
                        let status = CheckInStatus(rawValue: statusRaw)
                    else { return nil }
                    return CheckIn(date: timestamp.dateValue(), status: status)
                }

                Task { @MainActor in
                    if let index = self.pairings.firstIndex(where: { $0.checkInUsername == username }) {
                        self.pairings[index].checkIns = checkIns
                    }
                }
            }

        listeners.append(listener)
    }

    // MARK: - Fetch check-ins once
    private func fetchCheckIns(for username: String) async throws -> [CheckIn] {
        let snapshot = try await db.collection("checkIns")
            .whereField("username", isEqualTo: username)
            .order(by: "date", descending: true)
            .limit(to: 30)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let timestamp = data["date"] as? Timestamp,
                let statusRaw = data["status"] as? String,
                let status = CheckInStatus(rawValue: statusRaw)
            else { return nil }
            return CheckIn(date: timestamp.dateValue(), status: status)
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
    func performCheckIn(username: String) async {
        guard let index = selectedPairingIndex else { return }
        let today = Date()

        pairings[index].checkIns.removeAll { checkIn in
            Calendar.current.isDate(checkIn.date, inSameDayAs: today) && checkIn.status == .pending
        }
        pairings[index].checkIns.insert(
            CheckIn(date: today, status: .checkedIn),
            at: 0
        )

        do {
            let data: [String: Any] = [
                "username": username,
                "date": Timestamp(date: today),
                "status": CheckInStatus.checkedIn.rawValue
            ]

            try await db.collection("checkIns")
                .document("\(username)_\(Int(today.timeIntervalSince1970))")
                .setData(data)

        } catch {
            errorMessage = "Failed to save check-in: \(error.localizedDescription)"
        }
    }
}
