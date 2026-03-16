import Foundation

enum CheckInFrequency: String, Codable, CaseIterable {
    case daily = "Every Day"
    case weekly = "Weekly"

    var displayName: String { rawValue }
}

struct CheckInSchedule: Codable {
    var time: Date
    var frequency: CheckInFrequency
    // For weekly frequency, which days are active (1 = Sunday, 7 = Saturday)
    var activeDays: Set<Int>

    init(
        time: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
        frequency: CheckInFrequency = .daily,
        activeDays: Set<Int> = Set(1...7)
    ) {
        self.time = time
        self.frequency = frequency
        self.activeDays = activeDays
    }

    // Returns the hour component of the scheduled time
    var hour: Int {
        Calendar.current.component(.hour, from: time)
    }

    // Returns the minute component of the scheduled time
    var minute: Int {
        Calendar.current.component(.minute, from: time)
    }

    // Formatted time string (e.g. "9:41 AM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    // Whether a given weekday is scheduled
    func isScheduled(weekday: Int) -> Bool {
        if frequency == .daily { return true }
        return activeDays.contains(weekday)
    }
}

struct Pairing: Identifiable, Codable {
    let id: UUID
    let checkerUsername: String
    let checkInUsername: String
    var schedule: CheckInSchedule
    var checkIns: [CheckIn]

    init(
        id: UUID = UUID(),
        checkerUsername: String,
        checkInUsername: String,
        schedule: CheckInSchedule = CheckInSchedule(),
        checkIns: [CheckIn] = []
    ) {
        self.id = id
        self.checkerUsername = checkerUsername
        self.checkInUsername = checkInUsername
        self.schedule = schedule
        self.checkIns = checkIns
    }

    // Current streak of consecutive check-ins (counting backward from today)
    var currentStreak: Int {
        let calendar = Calendar.current
        let sorted = checkIns
            .filter { $0.status == .checkedIn }
            .sorted { $0.date > $1.date }

        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())

        for checkIn in sorted {
            let checkInDay = calendar.startOfDay(for: checkIn.date)
            if checkInDay == expectedDate {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if checkInDay < expectedDate {
                break
            }
        }
        return streak
    }

    // Status for a specific date
    func status(for date: Date) -> CheckInStatus? {
        let calendar = Calendar.current
        return checkIns.first { calendar.isDate($0.date, inSameDayAs: date) }?.status
    }

    // Last check-in that was completed
    var lastCheckIn: CheckIn? {
        checkIns
            .filter { $0.status == .checkedIn }
            .sorted { $0.date > $1.date }
            .first
    }

    // Time since last check-in as a human-readable string
    var timeSinceLastCheckIn: String {
        guard let last = lastCheckIn else { return "No check-ins yet" }
        let interval = Date().timeIntervalSince(last.date)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours >= 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            return "\(minutes) min ago"
        }
    }

    // Formatted string for last check-in date
    var lastCheckInDescription: String {
        guard let last = lastCheckIn else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE 'at' h:mma"
        return "Last checked in \(formatter.string(from: last.date))"
    }
}
