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
