// SafePing  User.swift

// Defines the core user models
// Includes user roles and user data stored in Firestore
//
import Foundation

// UserRole
// Represents the type of user in the system
//
// - checker: monitors another users check ins
// - checkInUser: performs check ins
//
enum UserRole: String, Codable {
    case checker
    case checkInUser

    // Display name for UI
    var displayName: String {
        switch self {
        case .checker: return "Checker"
        case .checkInUser: return "Check-In User"
        }
    }

    // Description shown in UI
    var description: String {
        switch self {
        case .checker:
            return "Monitor your loved ones and get notified if they miss a check-in."
        case .checkInUser:
            return "Check in daily so your people know you're safe."
        }
    }

    // Icon name used in UI
    var iconName: String {
        switch self {
        case .checker: return "eye.circle.fill"
        case .checkInUser: return "hand.wave.fill"
        }
    }
}

// Struct: User
// Represents a user account
//
// Properties:
// - id: unique user identifier
// - username: login username
// - password: user password
// - role: optional user role 
//
struct User: Identifiable, Codable {
    let id: UUID
    var username: String
    var password: String
    var role: UserRole?

    // Initializer
    // Creates a new user
    //
    // Parameters:
    // - id: optional custom ID
    // - username: user login name
    // - password: user password
    // - role: optional role assignment
    //
    init(id: UUID = UUID(), username: String, password: String, role: UserRole? = nil) {
        self.id = id
        self.username = username
        self.password = password
        self.role = role
    }
}
