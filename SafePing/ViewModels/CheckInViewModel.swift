import Foundation
import SwiftUI

@MainActor
class CheckInViewModel: ObservableObject {
    @Published var pairings: [Pairing] = []
    @Published var selectedPairingId: UUID?

    var selectedPairing: Pairing? {
        guard let id = selectedPairingId else { return pairings.first }
        return pairings.first { $0.id == id }
    }

    var selectedPairingIndex: Int? {
        guard let id = selectedPairingId ?? pairings.first?.id else { return nil }
        return pairings.firstIndex { $0.id == id }
    }

    // Load Mock Data for testing
    func loadMockData(for username: String, role: UserRole) {
        let calendar = Calendar.current
        let today = Date()

        if role == .checker {
            // Checker sees their paired check-in users
            var johnCheckIns: [CheckIn] = []
            var emilyCheckIns: [CheckIn] = []

            // Generate check-in history for past 30 days
            for dayOffset in 0..<30 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

                // John: mostly checks in, misses a couple days
                let johnMissed = [3, 14, 21].contains(dayOffset)
                if dayOffset > 0 {
                    let checkInTime = calendar.date(bySettingHour: 9, minute: Int.random(in: 0...59), second: 0, of: date)!
                    johnCheckIns.append(CheckIn(
                        date: checkInTime,
                        status: johnMissed ? .missed : .checkedIn
                    ))
                }

                // Emily: very consistent
                let emilyMissed = [7].contains(dayOffset)
                if dayOffset > 0 {
                    let checkInTime = calendar.date(bySettingHour: 8, minute: Int.random(in: 0...45), second: 0, of: date)!
                    emilyCheckIns.append(CheckIn(
                        date: checkInTime,
                        status: emilyMissed ? .missed : .checkedIn
                    ))
                }
            }

            // Today's check-in for John (4 hours ago)
            if let fourHoursAgo = calendar.date(byAdding: .hour, value: -4, to: today) {
                johnCheckIns.insert(CheckIn(date: fourHoursAgo, status: .checkedIn), at: 0)
            }

            // Emily hasn't checked in today yet
            emilyCheckIns.insert(CheckIn(date: today, status: .pending), at: 0)

            let johnPairing = Pairing(
                checkerUsername: username,
                checkInUsername: "John",
                schedule: CheckInSchedule(
                    time: calendar.date(from: DateComponents(hour: 9, minute: 41))!,
                    frequency: .daily
                ),
                checkIns: johnCheckIns
            )

            let emilyPairing = Pairing(
                checkerUsername: username,
                checkInUsername: "Emily",
                schedule: CheckInSchedule(
                    time: calendar.date(from: DateComponents(hour: 8, minute: 30))!,
                    frequency: .daily
                ),
                checkIns: emilyCheckIns
            )

            pairings = [johnPairing, emilyPairing]
            selectedPairingId = johnPairing.id

        } else {
            // Check-in user sees their own status
            var myCheckIns: [CheckIn] = []

            for dayOffset in 1..<20 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                let missed = [5, 12].contains(dayOffset)
                let checkInTime = calendar.date(bySettingHour: 9, minute: Int.random(in: 0...30), second: 0, of: date)!
                myCheckIns.append(CheckIn(
                    date: checkInTime,
                    status: missed ? .missed : .checkedIn
                ))
            }

            let pairing = Pairing(
                checkerUsername: "Mom",
                checkInUsername: username,
                schedule: CheckInSchedule(
                    time: calendar.date(from: DateComponents(hour: 9, minute: 0))!,
                    frequency: .daily
                ),
                checkIns: myCheckIns
            )

            pairings = [pairing]
            selectedPairingId = pairing.id
        }
    }

    // Select Pairing
    func selectPairing(_ pairing: Pairing) {
        selectedPairingId = pairing.id
    }

    // Update Schedule
    func updateScheduleTime(_ time: Date) {
        guard let index = selectedPairingIndex else { return }
        pairings[index].schedule.time = time
    }

    func updateScheduleFrequency(_ frequency: CheckInFrequency) {
        guard let index = selectedPairingIndex else { return }
        pairings[index].schedule.frequency = frequency
    }

    func toggleScheduleDay(_ weekday: Int) {
        guard let index = selectedPairingIndex else { return }
        if pairings[index].schedule.activeDays.contains(weekday) {
            // Don't allow deselecting all days
            if pairings[index].schedule.activeDays.count > 1 {
                pairings[index].schedule.activeDays.remove(weekday)
            }
        } else {
            pairings[index].schedule.activeDays.insert(weekday)
        }
    }

    // Perform Check-In (for check-in users)
    func performCheckIn() {
        guard let index = selectedPairingIndex else { return }
        let today = Date()
        // Remove pending status for today if it exists
        pairings[index].checkIns.removeAll { checkIn in
            Calendar.current.isDate(checkIn.date, inSameDayAs: today) && checkIn.status == .pending
        }
        // Add checked-in status
        pairings[index].checkIns.insert(
            CheckIn(date: today, status: .checkedIn),
            at: 0
        )
    }
}
