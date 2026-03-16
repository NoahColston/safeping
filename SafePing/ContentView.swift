import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationService = NotificationService()

    var body: some View {
        Group {
            if !authViewModel.isAuthenticated {
                NavigationStack {
                    LoginView()
                }
            } else if authViewModel.needsRoleSelection {
                RoleSelectionView()
            } else if !authViewModel.onboardingComplete {
                NotificationPermissionView(notificationService: notificationService)
            } else {
                // Route to the correct dashboard based on role
                switch authViewModel.currentUser?.role {
                case .checker:
                    CheckerDashboardView()
                case .checkInUser:
                    CheckInUserDashboardView()
                case .none:
                    // Fallback — shouldn't reach here
                    RoleSelectionView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.needsOnboarding)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.onboardingComplete)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
