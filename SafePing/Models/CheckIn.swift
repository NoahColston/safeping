import Foundation

enum CheckInStatus: String, Codable {
    case checkedIn
    case missed
    case pending
}

struct CheckIn: Identifiable, Codable {
    let id: UUID
    let pairingId: UUID
    let date: Date
    var status: CheckInStatus
    var latitude: Double?
    var longitude: Double?

    init(
        id: UUID = UUID(),
        pairingId: UUID,
        date: Date,
        status: CheckInStatus,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.pairingId = pairingId
        self.date = date
        self.status = status
        self.latitude = latitude
        self.longitude = longitude
    }
}
