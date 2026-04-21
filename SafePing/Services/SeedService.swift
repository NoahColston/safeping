import Foundation
import Combine
import FirebaseFirestore

// SeedService
// Orchestrates seeding of all sample data into Firestore for demo/testing purposes
//
// [OOP] ObservableObject exposes seeding state to the UI layer
//
@MainActor
final class SeedService: ObservableObject {
    @Published var isSeeding = false
    @Published var seedMessage: String?

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    // Public entry point  delegates to the full seeding pipeline
    func seedSampleUsers() async {
        await seedAllSampleData()
    }

    // Main seeding pipeline for all sample data
    // [OOP] Service orchestrates app wide data initialization
    func seedAllSampleData() async {
        isSeeding = true
        seedMessage = nil

        do {
            let today = startOfDay(Date())
            // Pairings are backdated 14 days to provide meaningful historical check in data
            let fourteenDaysAgo = addDays(today, -14)

            let users = makeUsers()
            let pairings = makePairings(pairedAt: fourteenDaysAgo)

            // Build historical check in records for each pairing + schedule combination
            var historicalCheckIns: [SeedCheckInRecord] = []
            for pairing in pairings {
                for schedule in pairing.schedules {
                    let missedOffsets = getMissedOffsets(
                        checkerUsername: pairing.checkerUsername,
                        checkInUsername: pairing.checkInUsername,
                        scheduleMessage: schedule.message
                    )

                    let records = generateCheckIns(
                        pairing: pairing,
                        schedule: schedule,
                        missedDayOffsets: missedOffsets,
                        today: today
                    )

                    historicalCheckIns.append(contentsOf: records)
                }
            }

            // Generate todays check ins separately
            let todayCheckIns = generateTodayCheckIns(
                pairings: pairings,
                today: today,
                now: Date()
            )

            // All writes are batched into a single atomic commit
            let batch = db.batch()

            // User writes each user document to the users collection
            // [Functional] map like transformation of user models into Firestore docs
            for user in users {
                let ref = db.collection("users").document(user.username)
                batch.setData([
                    "id": user.id,
                    "username": user.username,
                    "password": user.passwordHash,
                    "role": user.role
                ], forDocument: ref)
            }

            // Pairs each pairing has its streak calculated before being written
            // [Procedural] streak computed from historical check ins before batch write
            for pairing in pairings {
                let pairingCheckIns = historicalCheckIns.filter { $0.pairingID == pairing.id }
                let streak = computeStreak(
                    pairing: pairing,
                    allCheckIns: pairingCheckIns,
                    today: today
                )

                let ref = db.collection("pairs").document(pairing.id)
                batch.setData([
                    "id": pairing.id,
                    "checkerUsername": pairing.checkerUsername,
                    "checkInUsername": pairing.checkInUsername,
                    "pairedAt": Timestamp(date: pairing.pairedAt),
                    "isActive": true,
                    // [Functional] Schedules mapped inline to Firestore compatible dictionaries
                    "schedules": pairing.schedules.map { schedule in
                        [
                            "id": schedule.id,
                            "message": schedule.message,
                            "hour": schedule.hour,
                            "minute": schedule.minute,
                            "frequency": schedule.frequency,
                            "activeDays": schedule.activeDays,
                            "gracePeriodMinutes": schedule.gracePeriodMinutes
                        ] as [String: Any]
                    },
                    "currentStreak": streak
                ], forDocument: ref)
            }

            // Historical check ins
            for checkIn in historicalCheckIns {
                let ref = db.collection("checkIns").document(checkIn.docID)
                batch.setData(checkIn.firestoreData, forDocument: ref)
            }

            // Todays check ins
            for checkIn in todayCheckIns {
                let ref = db.collection("checkIns").document(checkIn.docID)
                batch.setData(checkIn.firestoreData, forDocument: ref)
            }

            try await batch.commit()

            let totalCheckIns = historicalCheckIns.count + todayCheckIns.count
            seedMessage = "Seeded \(users.count) users, \(pairings.count) pairings, and \(totalCheckIns) check-in records successfully."
        } catch {
            seedMessage = "Seed failed: \(error.localizedDescription)"
        }

        isSeeding = false
    }


    // Generates the fixed set of demo users, all sharing the same hashed password
    // [Functional] Pure data generator no side effects
    private func makeUsers() -> [SeedUser] {
        let passwordHash = CryptoUtils.hashPassword("password")

        return [
            SeedUser(id: randomID(), username: "mom", passwordHash: passwordHash, role: "checker"),
            SeedUser(id: randomID(), username: "dr_robby", passwordHash: passwordHash, role: "checker"),
            SeedUser(id: randomID(), username: "coach_mike", passwordHash: passwordHash, role: "checker"),
            SeedUser(id: randomID(), username: "jane", passwordHash: passwordHash, role: "checkInUser"),
            SeedUser(id: randomID(), username: "john", passwordHash: passwordHash, role: "checkInUser"),
            SeedUser(id: randomID(), username: "ruth", passwordHash: passwordHash, role: "checkInUser"),
            SeedUser(id: randomID(), username: "george", passwordHash: passwordHash, role: "checkInUser"),
            SeedUser(id: randomID(), username: "sarah", passwordHash: passwordHash, role: "checkInUser")
        ]
    }

    // Builds sample pairings for the demo dataset
    // [Functional] Pure factory  returns value types with no external dependencies
    private func makePairings(pairedAt: Date) -> [SeedPairing] {
        [
            SeedPairing(
                id: randomID(),
                checkerUsername: "mom",
                checkInUsername: "jane",
                pairedAt: pairedAt,
                schedules: [
                    makeSchedule(message: "Morning check-in", hour: 9, minute: 0, gracePeriodMinutes: 15),
                    makeSchedule(message: "Evening check-in", hour: 20, minute: 0, gracePeriodMinutes: 30)
                ]
            ),
            SeedPairing(
                id: randomID(),
                checkerUsername: "mom",
                checkInUsername: "john",
                pairedAt: pairedAt,
                schedules: [
                    makeSchedule(
                        message: "After school",
                        hour: 15,
                        minute: 30,
                        frequency: "Weekly",
                        activeDays: [2, 3, 4, 5, 6],
                        gracePeriodMinutes: 20
                    )
                ]
            ),
            SeedPairing(
                id: randomID(),
                checkerUsername: "dr_robby",
                checkInUsername: "ruth",
                pairedAt: pairedAt,
                schedules: [
                    makeSchedule(message: "Morning meds", hour: 5, minute: 0, gracePeriodMinutes: 10),
                    makeSchedule(message: "Evening meds", hour: 19, minute: 0, gracePeriodMinutes: 15)
                ]
            ),
            SeedPairing(
                id: randomID(),
                checkerUsername: "dr_robby",
                checkInUsername: "george",
                pairedAt: pairedAt,
                schedules: [
                    makeSchedule(message: "Daily wellness", hour: 6, minute: 0, gracePeriodMinutes: 15)
                ]
            ),
            SeedPairing(
                id: randomID(),
                checkerUsername: "dr_robby",
                checkInUsername: "sarah",
                pairedAt: pairedAt,
                schedules: [
                    makeSchedule(message: "Post-op check", hour: 12, minute: 0, gracePeriodMinutes: 60)
                ]
            ),
            SeedPairing(
                id: randomID(),
                checkerUsername: "coach_mike",
                checkInUsername: "sarah",
                pairedAt: pairedAt,
                schedules: [
                    makeSchedule(
                        message: "Morning walk",
                        hour: 5,
                        minute: 30,
                        frequency: "Weekly",
                        activeDays: [2, 4, 6],
                        gracePeriodMinutes: 5
                    )
                ]
            )
        ]
    }

    // Creates a schedule value with sensible defaults
    // [Functional] Pure constructor all parameters explicit, no side effects
    private func makeSchedule(
        message: String,
        hour: Int,
        minute: Int,
        frequency: String = "Every Day",
        activeDays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        gracePeriodMinutes: Int = 15
    ) -> SeedSchedule {
        SeedSchedule(
            id: randomID(),
            message: message,
            hour: hour,
            minute: minute,
            frequency: frequency,
            activeDays: activeDays.sorted(),
            gracePeriodMinutes: gracePeriodMinutes
        )
    }


    // Generates historical check in records over the 13 days preceding today
    private func generateCheckIns(
        pairing: SeedPairing,
        schedule: SeedSchedule,
        missedDayOffsets: [Int],
        today: Date
    ) -> [SeedCheckInRecord] {
        let missedSet = Set(missedDayOffsets)
        var records: [SeedCheckInRecord] = []

        for offset in -13 ... -1 {
            let date = addDays(today, offset)
            let weekdayValue = weekday(date)

            // Skip days outside the schedule's active window
            let isDaily = schedule.frequency == "Every Day"
            let isActiveDay = schedule.activeDays.contains(weekdayValue)
            if !isDaily && !isActiveDay { continue }

            let status = missedSet.contains(offset) ? "missed" : "checkedIn"

            guard let checkInDate = calendar.date(
                bySettingHour: schedule.hour,
                minute: schedule.minute,
                second: 0,
                of: date
            ) else {
                continue
            }

            let dk = dayKey(date)
            let docID = "\(pairing.id)_\(schedule.id)_\(dk)"

            var latitude: Double?
            var longitude: Double?

            // Conditionally attach location data based on per user rules
            if status == "checkedIn" && shouldIncludeLocation(username: pairing.checkInUsername, offset: offset) {
                if let location = userLocations[pairing.checkInUsername] {
                    latitude = jitter(location.lat)
                    longitude = jitter(location.lng)
                }
            }

            records.append(
                SeedCheckInRecord(
                    id: randomID(),
                    docID: docID,
                    pairingID: pairing.id,
                    scheduleID: schedule.id,
                    username: pairing.checkInUsername,
                    date: checkInDate,
                    status: status,
                    latitude: latitude,
                    longitude: longitude
                )
            )
        }

        return records
    }

    // Generates todays check in records for pairings that have already passed their scheduled time
    // [Procedural] Guards against future dated check-ins by comparing now against scheduled time
    private func generateTodayCheckIns(
        pairings: [SeedPairing],
        today: Date,
        now: Date
    ) -> [SeedCheckInRecord] {
        var records: [SeedCheckInRecord] = []

        for pairing in pairings {
            // Only seed today s check in for jane s morning schedule as a representative example
            guard pairing.checkInUsername == "jane",
                  let schedule = pairing.schedules.first(where: { $0.message == "Morning check-in" }),
                  let checkInDate = calendar.date(bySettingHour: schedule.hour, minute: schedule.minute + 2, second: 0, of: today),
                  now > checkInDate,
                  let location = userLocations["jane"] else {
                continue
            }

            let dk = dayKey(today)

            records.append(
                SeedCheckInRecord(
                    id: randomID(),
                    docID: "\(pairing.id)_\(schedule.id)_\(dk)",
                    pairingID: pairing.id,
                    scheduleID: schedule.id,
                    username: "jane",
                    date: checkInDate,
                    status: "checkedIn",
                    latitude: jitter(location.lat),
                    longitude: jitter(location.lng)
                )
            )
        }

        return records
    }

    // Returns per user, per schedule list of day offsets that should be marked as missed
    // [Functional] Pure lookup no mutation, driven entirely by input parameters
    private func getMissedOffsets(
        checkerUsername: String,
        checkInUsername: String,
        scheduleMessage: String
    ) -> [Int] {
        if checkInUsername == "jane" && scheduleMessage == "Morning check-in" {
            return []
        }
        if checkInUsername == "jane" && scheduleMessage == "Evening check-in" {
            return [-3, -9]
        }
        if checkInUsername == "john" {
            return []
        }
        if checkInUsername == "ruth" && scheduleMessage == "Morning meds" {
            return [-2, -7, -11]
        }
        if checkInUsername == "ruth" && scheduleMessage == "Evening meds" {
            return []
        }
        if checkInUsername == "george" {
            return [-4, -10]
        }
        if checkInUsername == "sarah" && scheduleMessage == "Post-op check" {
            return [-1, -3, -5, -8, -12]
        }
        if checkInUsername == "sarah" && scheduleMessage == "Morning walk" {
            return [-6]
        }
        return []
    }

    // Computes the current consecutive check-in streak for a pairing
    // [Procedural] Walks backwards from yesterday, breaking on the first missed day
    private func computeStreak(
        pairing: SeedPairing,
        allCheckIns: [SeedCheckInRecord],
        today: Date
    ) -> Int {
        var streak = 0

        for offset in stride(from: -1, through: -13, by: -1) {
            let date = addDays(today, offset)
            let weekdayValue = weekday(date)

            // Only count days where at least one schedule was active
            let activeSchedules = pairing.schedules.filter { schedule in
                if schedule.frequency == "Every Day" { return true }
                return schedule.activeDays.contains(weekdayValue)
            }

            if activeSchedules.isEmpty { continue }

            // Streak continues only if every active schedule was checked in on this day
            let allCheckedIn = activeSchedules.allSatisfy { schedule in
                allCheckIns.contains { record in
                    record.scheduleID == schedule.id &&
                    record.status == "checkedIn" &&
                    calendar.isDate(record.date, inSameDayAs: date)
                }
            }

            if allCheckedIn {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }


    // Generates a unique uppercase UUID string
    private func randomID() -> String {
        UUID().uuidString.uppercased()
    }

    // Returns the start of the given date's calendar day
    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    // Offsets a date by a given number of days (negative = past, positive = future)
    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    // Returns a stable integer key for a calendar day, used as part of Firestore doc IDs
    private func dayKey(_ date: Date) -> Int {
        Int(startOfDay(date).timeIntervalSince1970)
    }

    // Returns the weekday integer for a given date
    private func weekday(_ date: Date) -> Int {
        calendar.component(.weekday, from: date)
    }

    // Adds a small random offset to a coordinate to simulate natural GPS variance
    private func jitter(_ base: Double, range: Double = 0.005) -> Double {
        base + Double.random(in: (-range / 2)...(range / 2))
    }

    // Determines whether a location should be included for a given user and day offset
    private func shouldIncludeLocation(username: String, offset: Int) -> Bool {
        if username == "george" { return false }
        if username == "sarah" { return offset % 2 == 0 }
        return true
    }

    // Fixed seed coordinates per check-in user, approximating real Virginia locations
    private let userLocations: [String: SeedLocation] = [
        "jane": SeedLocation(lat: 37.2296, lng: -80.4139),
        "john": SeedLocation(lat: 37.1318, lng: -80.4089),
        "ruth": SeedLocation(lat: 37.2710, lng: -79.9414),
        "sarah": SeedLocation(lat: 38.0293, lng: -78.4767)
    ]
}


// Lightweight user model used only during seeding
private struct SeedUser {
    let id: String
    let username: String
    let passwordHash: String
    let role: String
}

// Coordinate pair for seeding location data
private struct SeedLocation {
    let lat: Double
    let lng: Double
}

// Represents a single check in schedule within a seeded pairing
private struct SeedSchedule {
    let id: String
    let message: String
    let hour: Int
    let minute: Int
    let frequency: String
    let activeDays: [Int]
    let gracePeriodMinutes: Int
}

// Represents a checker checkInUser relationship with one or more schedules
private struct SeedPairing {
    let id: String
    let checkerUsername: String
    let checkInUsername: String
    let pairedAt: Date
    let schedules: [SeedSchedule]
}

// Represents a single check in event to be written to Firestore
private struct SeedCheckInRecord {
    let id: String
    let docID: String
    let pairingID: String
    let scheduleID: String
    let username: String
    let date: Date
    let status: String
    let latitude: Double?
    let longitude: Double?

    // Converts record to Firestore-compatible dictionary
    // [Functional] Pure computed property derives output from stored values only
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "pairingId": pairingID,
            "scheduleId": scheduleID,
            "username": username,
            "date": Timestamp(date: date),
            "status": status
        ]

        // Location fields omitted entirely when nil rather than written as null
        if let latitude {
            data["latitude"] = latitude
        }

        if let longitude {
            data["longitude"] = longitude
        }

        return data
    }
}
