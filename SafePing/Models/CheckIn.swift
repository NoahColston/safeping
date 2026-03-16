import Foundation

enum CheckInStatus: String, Codable {
    case checkedIn
    case missed
    case pending
}

struct CheckIn: Identifiable, Codable {
    let id: UUID
    let date: Date
    var status: CheckInStatus

    init(id: UUID = UUID(), date: Date, status: CheckInStatus) {
        self.id = id
        self.date = date
        self.status = status
    }
}
