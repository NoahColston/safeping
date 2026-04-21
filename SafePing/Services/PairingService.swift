// SafePing  PairingService.swift

// Handles Firestore reads and writes for pairing codes and pairing documents
// Used to create, redeem, and remove user pairings
//
import Foundation
import FirebaseFirestore

// PairingService
// Stateless service responsible for Firestore pairing logic
//
// [OOP] Class used as a service layer
//
class PairingService {
    private let db = Firestore.firestore()
    
    // MARK: Checkee: generate pairing code
    
    // Generates a 6 digit pairing code and stores it in Firestore
    // [Procedural] Step-by-step data creation and database write
    func generatePairingCode(for checkeeUsername: String) async throws -> String {
        let code = String(format: "%06d", Int.random(in: 0...999999))
        let now = Date()
        let expiresAt = now.addingTimeInterval(86400)
        
        let data: [String: Any] = [
            "code": code,
            "checkeeUsername": checkeeUsername,
            "createdAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: expiresAt),
            "isUsed": false
        ]
        
        try await db.collection("pairingCodes")
            .document(code)
            .setData(data)
        
        return code
    }
    
    
    // Validates a code and creates a pairing between two users
    func redeemPairingCode(_ code: String, checkerUsername: String) async throws -> Pairing {
        let doc = try await db.collection("pairingCodes")
            .document(code)
            .getDocument()
        
        guard doc.exists, let data = doc.data() else {
            throw PairingError.invalidCode
        }
        
        let isUsed = data["isUsed"] as? Bool ?? false
        guard !isUsed else { throw PairingError.alreadyUsed }
        
        let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
        guard expiresAt > Date() else { throw PairingError.expired }
        
        let checkeeUsername = data["checkeeUsername"] as? String ?? ""
        
        // Check for existing pairing
        let existing = try await db.collection("pairs")
            .whereField("checkerUsername", isEqualTo: checkerUsername)
            .whereField("checkInUsername", isEqualTo: checkeeUsername)
            .getDocuments()
        guard existing.documents.isEmpty else { throw PairingError.alreadyPaired }
        
        // Mark code as used
        try await db.collection("pairingCodes")
            .document(code)
            .updateData(["isUsed": true])
        
        let defaultSchedules = [CheckInSchedule()]
        let now = Date()
        
        // Create new pairing object
        let pairing = Pairing(
            checkerUsername: checkerUsername,
            checkInUsername: checkeeUsername,
            schedules: defaultSchedules,
            pairedAt: now
        )
        
        let pairingData: [String: Any] = [
            "id": pairing.id.uuidString,
            "checkerUsername": pairing.checkerUsername,
            "checkInUsername": pairing.checkInUsername,
            "pairedAt": Timestamp(date: now),
            "isActive": true,
            "schedules": defaultSchedules.map { $0.toFirestore() },
            "currentStreak": 0
        ]
        
        try await db.collection("pairs")
            .document(pairing.id.uuidString)
            .setData(pairingData)
        
        return pairing
    }
    
    
    // Deletes a pairing from Firestore
    func removePairing(pairingId: UUID) async throws {
        try await db.collection("pairs")
            .document(pairingId.uuidString)
            .delete()
    }
}

// PairingError
// Represents possible errors during pairing operations
enum PairingError: LocalizedError {
    case invalidCode
    case alreadyUsed
    case expired
    case alreadyPaired
    
    var errorDescription: String? {
        switch self {
        case .invalidCode: return "That code doesn't exist. Double-check and try again."
        case .alreadyUsed: return "This code has already been used."
        case .expired:     return "This code has expired. Ask for a new one."
        case .alreadyPaired: return "You are already paired with that user."
        }
    }
}
