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
                // Check-in users see the notification permission screen
                NotificationPermissionView(notificationService: notificationService)
            } else {
                HomeView()
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
