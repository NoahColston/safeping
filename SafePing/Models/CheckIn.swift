// SafePing  CheckIn.swift

// Defines the data models used to represent a users check in
// A CheckIn is stored per pairing and optionally
// linked to a schedule
//
import Foundation

// CheckInStatus
// Represents the state of a check-in for a given date.
//
// - checkedIn: User successfully checked in
// - missed: User failed to check in within the expected time
// - pending: Check-in is expected but not yet completed
//
enum CheckInStatus: String, Codable {
    case checkedIn
    case missed
    case pending
}

// Struct: CheckIn
// Represents a single check-in event for a user pairing.
//
// Properties:
// - id: Unique identifier for the check  in
// - pairingId: Identifies the paired users this check in belongs to
// - scheduleId: Optional reference to a schedule governing this check in
// - date: The date or time the check in is associated with
// - status: Current state of the check in
// - latitude/longitude: Optional location data when the check-in occurred
//
struct CheckIn: Identifiable, Codable {
    let id: UUID
    let pairingId: UUID
    var scheduleId: UUID?
    let date: Date
    var status: CheckInStatus
    var latitude: Double?
    var longitude: Double?

    // Initializer
    // Creates a new CheckIn instance.
    //
    // Parameters:
    // - id: Optional custom ID
    // - pairingId: Required pairing identifier
    // - scheduleId: Optional schedule association
    // - date: Date or time of the check in
    // - status: Initial status of the check in
    // - latitude/longitude: Optional location data
    //
    init(
        id: UUID = UUID(),
        pairingId: UUID,
        scheduleId: UUID? = nil,
        date: Date,
        status: CheckInStatus,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.pairingId = pairingId
        self.scheduleId = scheduleId
        self.date = date
        self.status = status
        self.latitude = latitude
        self.longitude = longitude
    }
}
