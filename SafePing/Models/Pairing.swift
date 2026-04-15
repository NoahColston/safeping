import Foundation

// MARK: - Check-in Schedule
enum CheckInFrequency: String, Codable, CaseIterable {
    case daily = "Every Day"
    case weekly = "Weekly"

    var displayName: String { rawValue }
}

struct CheckInSchedule: Codable, Identifiable, Hashable {
    let id: UUID
    var message: String
    var time: Date
    var frequency: CheckInFrequency
    var activeDays: Set<Int>

    init(
        id: UUID = UUID(),
        message: String = "",
        time: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
        frequency: CheckInFrequency = .daily,
        activeDays: Set<Int> = Set(1...7)
    ) {
        self.id = id
        self.message = message
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
    
    var displayMessage: String {
        message.isEmpty ? formattedTime : message
    }

    func isScheduled(weekday: Int) -> Bool {
        if frequency == .daily { return true }
        return activeDays.contains(weekday)
    }
    
    func toFirestore() -> [String: Any] {
        [
            "id": id.uuidString,
            "message": message,
            "hour": hour,
            "minute": minute,
            "frequency": frequency.rawValue,
            "activeDays": Array(activeDays).sorted()
        ]
    }
     
        
    static func fromFirestore(_ data: [String: Any]) -> CheckInSchedule {
        let id = (data["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        let message = data["message"] as? String ?? ""
        let hour = data["hour"] as? Int ?? 9
        let minute = data["minute"] as? Int ?? 0
        let frequencyRaw = data["frequency"] as? String ?? CheckInFrequency.daily.rawValue
        let frequency = CheckInFrequency(rawValue: frequencyRaw) ?? .daily
        let activeDaysArray = data["activeDays"] as? [Int] ?? Array(1...7)
 
        let time = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
 
        return CheckInSchedule(id: id, message: message, time: time, frequency: frequency, activeDays: Set(activeDaysArray))
    }
}

// MARK: - Pairing
struct Pairing: Identifiable, Codable {
    let id: UUID
    let checkerUsername: String
    let checkInUsername: String
    var schedules: [CheckInSchedule]
    var checkIns: [CheckIn]
    var currentStreak: Int // streak tracker
    var pairedAt: Date

    init(
        id: UUID = UUID(),
        checkerUsername: String,
        checkInUsername: String,
        schedules: [CheckInSchedule] = [CheckInSchedule()],
        checkIns: [CheckIn] = [],
        currentStreak: Int = 0,
        pairedAt: Date = Date()
    ) {
        self.id = id
        self.checkerUsername = checkerUsername
        self.checkInUsername = checkInUsername
        self.schedules = schedules
        self.checkIns = checkIns
        self.currentStreak = currentStreak
        self.pairedAt = pairedAt
    }
    
    // Schedules that apply on the given date, sorted by time.
    func schedules(forDate date: Date) -> [CheckInSchedule] {
        let weekday = Calendar.current.component(.weekday, from: date)
        return schedules.filter { $0.isScheduled(weekday: weekday) }
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    func checkIn(forDate date: Date, scheduleId: UUID) -> CheckIn? {
        let calendar = Calendar.current
        return checkIns.first { ci in
            guard calendar.isDate(ci.date, inSameDayAs: date) else { return false }
            return ci.scheduleId == scheduleId
        }
    }


    func status(for date: Date, scheduleId: UUID) -> CheckInStatus? {
        checkIn(forDate: date, scheduleId: scheduleId)?.status
    }
    
    func status(for date: Date) -> CheckInStatus? {
        let calendar = Calendar.current
    
        if calendar.startOfDay(for: date) < calendar.startOfDay(for: pairedAt) {
            return nil
        }
        
        let activeSchedules = schedules(forDate: date)
        guard !activeSchedules.isEmpty else { return nil }

        let statuses = activeSchedules.map { self.status(for: date, scheduleId: $0.id) }

        if statuses.allSatisfy({ $0 == .checkedIn }) { return .checkedIn }

        let isPast = calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
        if isPast && statuses.contains(where: { $0 != .checkedIn }) { return .missed }

        return .pending
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
    
    // Next upcoming scheduled time across all schedules.
    var nextScheduledOccurrence: Date? {
        let calendar = Calendar.current
        let now = Date()
        var candidates: [Date] = []
        for schedule in schedules {
            for offset in 0...7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                let weekday = calendar.component(.weekday, from: day)
                guard schedule.isScheduled(weekday: weekday) else { continue }
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = schedule.hour
                components.minute = schedule.minute
                guard let occurrence = calendar.date(from: components) else { continue }
                if occurrence > now {
                    candidates.append(occurrence)
                    break
                }
            }
        }
        return candidates.min()
    }

    var nextScheduledFormatted: String {
        guard let next = nextScheduledOccurrence else { return "—" }
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(next) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: next)
        }
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: next)
    }
    
}
