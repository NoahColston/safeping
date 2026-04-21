import SwiftUI

// SafePing  PairingFlowView.swift
// Onboarding pairing step: routes user to the correct pairing screen based on role


struct PairingFlowView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        // Role based onboarding routing
        // This is a pure function of authViewModel.currentUser.role
        switch authViewModel.currentUser?.role {
        
        // Check-in users generate and share a pairing code
        case .checkInUser:
            CheckeePairingView()
            
        // Checkers redeem a code to connect to a check-in user
        case .checker:
            CheckerPairingView()
            
        // Fallback if role hasn’t been set yet
        case .none:
            RoleSelectionView()
        }
    }
}
