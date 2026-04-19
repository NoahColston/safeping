// SafePing — PairingFlowView.swift
// Onboarding pairing step: routes to CheckerPairingView or CheckeePairingView
// based on the user's role.
// [Functional] Conditional rendering is a pure function of currentUser.role.

import SwiftUI

struct PairingFlowView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        switch authViewModel.currentUser?.role {
        case .checkInUser:
            CheckeePairingView()
        case .checker:
            CheckerPairingView()
        case .none:
            RoleSelectionView()
        }
    }
}
