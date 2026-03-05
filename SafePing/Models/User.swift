import Foundation

enum UserRole: String, Codable {
    case checker
    case checkInUser

    var displayName: String {
        switch self {
        case .checker: return "Checker"
        case .checkInUser: return "Check-In User"
        }
    }

    var description: String {
        switch self {
        case .checker:
            return "Monitor your loved ones and get notified if they miss a check-in."
        case .checkInUser:
            return "Check in daily so your people know you're safe."
        }
    }

    var iconName: String {
        switch self {
        case .checker: return "eye.circle.fill"
        case .checkInUser: return "hand.wave.fill"
        }
    }
}

struct User: Identifiable, Codable {
    let id: UUID
    var username: String
    var password: String
    var role: UserRole?

    init(id: UUID = UUID(), username: String, password: String, role: UserRole? = nil) {
        self.id = id
        self.username = username
        self.password = password
        self.role = role
    }
}
