import Foundation
import FirebaseFirestore

class PairingService {
    private let db = Firestore.firestore()
    
    // MARK: Checkee: generate a 6-digit code and save to Firebase
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
    
    // MARK: Checker: look up code and create the pair
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
        
        // Mark code as used
        try await db.collection("pairingCodes")
            .document(code)
            .updateData(["isUsed": true])
        
        let defaultSchedule = CheckInSchedule()
        // Create the pair
        let pairing = Pairing(
            checkerUsername: checkerUsername,
            checkInUsername: checkeeUsername,
            schedule: defaultSchedule
        )
        
        let pairingData: [String: Any] = [
            "id": pairing.id.uuidString,
            "checkerUsername": pairing.checkerUsername,
            "checkInUsername": pairing.checkInUsername,
            "pairedAt": Timestamp(date: Date()),
            "isActive": true,
            "schedule": defaultSchedule.toFirestore()
        ]
        
        try await db.collection("pairs")
            .document(pairing.id.uuidString)
            .setData(pairingData)
        
        return pairing
    }
    
    // MARK: Remove a pairing (Story 13)
    func removePairing(pairingId: UUID) async throws {
        try await db.collection("pairs")
            .document(pairingId.uuidString)
            .delete()
    }
    
    // MARK: - Fetch all pairings for a checker
    func fetchPairings(for checkerUsername: String) async throws -> [Pairing] {
        let snapshot = try await db.collection("pairs")
            .whereField("checkerUsername", isEqualTo: checkerUsername)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let checkerUsername = data["checkerUsername"] as? String,
                let checkInUsername = data["checkInUsername"] as? String
            else { return nil }
            
            let scheduleData = data["schedule"] as? [String: Any]
            let schedule = scheduleData.map { CheckInSchedule.fromFirestore($0) } ?? CheckInSchedule()
            
            return Pairing(
                checkerUsername: checkerUsername,
                checkInUsername: checkInUsername,
                schedule: schedule
            )
        }
    }
}

enum PairingError: LocalizedError {
    case invalidCode
    case alreadyUsed
    case expired
    
    var errorDescription: String? {
        switch self {
        case .invalidCode: return "That code doesn't exist. Double-check and try again."
        case .alreadyUsed: return "This code has already been used."
        case .expired:     return "This code has expired. Ask for a new one."
        }
    }
}
