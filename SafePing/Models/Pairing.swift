import Foundation

// MARK: - Check-in Schedule
enum CheckInFrequency: String, Codable, CaseIterable {
    case daily = "Every Day"
    case weekly = "Weekly"

    var displayName: String { rawValue }
}

struct CheckInSchedule: Codable {
    var time: Date
    var frequency: CheckInFrequency
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

    var hour: Int {
        Calendar.current.component(.hour, from: time)
    }

    var minute: Int {
        Calendar.current.component(.minute, from: time)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    func isScheduled(weekday: Int) -> Bool {
        if frequency == .daily { return true }
        return activeDays.contains(weekday)
    }
    
    func toFirestore() -> [String: Any] {
        [
            "hour": hour,
            "minute": minute,
            "frequency": frequency.rawValue,
            "activeDays": Array(activeDays).sorted()
        ]
    }
     
        
    static func fromFirestore(_ data: [String: Any]) -> CheckInSchedule {
        let hour = data["hour"] as? Int ?? 9
        let minute = data["minute"] as? Int ?? 0
        let frequencyRaw = data["frequency"] as? String ?? CheckInFrequency.daily.rawValue
        let frequency = CheckInFrequency(rawValue: frequencyRaw) ?? .daily
        let activeDaysArray = data["activeDays"] as? [Int] ?? Array(1...7)
 
        let time = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
 
        return CheckInSchedule(time: time, frequency: frequency, activeDays: Set(activeDaysArray))
    }
}

// MARK: - Pairing
struct Pairing: Identifiable, Codable {
    let id: UUID
    let checkerUsername: String
    let checkInUsername: String
    var schedule: CheckInSchedule
    var checkIns: [CheckIn]
    var customReminderMessage: String  // Story 14

    init(
        id: UUID = UUID(),
        checkerUsername: String,
        checkInUsername: String,
        schedule: CheckInSchedule = CheckInSchedule(),
        checkIns: [CheckIn] = [],
        customReminderMessage: String = ""
    ) {
        self.id = id
        self.checkerUsername = checkerUsername
        self.checkInUsername = checkInUsername
        self.schedule = schedule
        self.checkIns = checkIns
        self.customReminderMessage = customReminderMessage
    }

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

    func status(for date: Date) -> CheckInStatus? {
        let calendar = Calendar.current
        return checkIns.first { calendar.isDate($0.date, inSameDayAs: date) }?.status
    }

    var lastCheckIn: CheckIn? {
        checkIns
            .filter { $0.status == .checkedIn }
            .sorted { $0.date > $1.date }
            .first
    }

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

    var lastCheckInDescription: String {
        guard let last = lastCheckIn else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE 'at' h:mma"
        return "Last checked in \(formatter.string(from: last.date))"
    }
}
