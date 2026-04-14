import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationService: NotificationService

    var body: some View {
        Group {
            if authViewModel.isLoading && !authViewModel.isAuthenticated {
                // Session restore in progress - show splash to avoid login flash
                ZStack {
                    Color.safePingBg.ignoresSafeArea()
                    BrandHeader()
                }
            } else if !authViewModel.isAuthenticated {
                NavigationStack {
                    LoginView()
                }
            } else if authViewModel.needsRoleSelection {
                RoleSelectionView()
            } else if !authViewModel.onboardingComplete {
                NotificationPermissionView(notificationService: notificationService)
            } else if !authViewModel.pairingComplete {
                PairingFlowView()
            } else {
                switch authViewModel.currentUser?.role {
                case .checker:
                    CheckerDashboardView()
                case .checkInUser:
                    CheckInUserDashboardView()
                case .none:
                    RoleSelectionView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.onboardingComplete)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.pairingComplete)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
