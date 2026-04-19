// SafePing — PairingViewModel.swift
// Generates and redeems 6-digit pairing codes via Firestore.
// [OOP] Thin VM layer that delegates storage to PairingService.

import SwiftUI

@MainActor
class PairingViewModel: ObservableObject {
    
    // Checkee state
    @Published var generatedCode: String = ""
    
    // Checker state
    @Published var enteredCode: String = ""
    @Published var isPaired: Bool = false
    @Published var pairedWithUsername: String = ""
    
    // Shared
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let pairingService = PairingService()
    
    // MARK: - Checkee: generate code
    func generateCode(for username: String) async {
        isLoading = true
        errorMessage = nil
        do {
            generatedCode = try await pairingService.generatePairingCode(for: username)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Checker: redeem code
    func redeemCode(checkerUsername: String) async {
        guard enteredCode.count == 6 else {
            errorMessage = "Please enter a 6-digit code."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let pairing = try await pairingService.redeemPairingCode(
                enteredCode,
                checkerUsername: checkerUsername
            )
            pairedWithUsername = pairing.checkInUsername
            isPaired = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
