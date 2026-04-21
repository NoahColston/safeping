// SafePing ContentView.swift
// Root routing view: decides whether to show auth flow or main app dashboard
// Everything here is reactive UI is a direct function of auth state

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationService: NotificationService

    var body: some View {
        Group {

            // Session restore/loading state
            // Prevents login screen flash while checking persisted auth session
            if authViewModel.isLoading && !authViewModel.isAuthenticated {
                ZStack {
                    Color.safePingBg.ignoresSafeArea()
                    BrandHeader()
                }

            // User not logged in → auth flow
            } else if !authViewModel.isAuthenticated {
                NavigationStack {
                    LoginView()
                }

            // User exists but hasn't picked a role yet
            } else if authViewModel.needsRoleSelection {
                RoleSelectionView()

            // User hasn't completed notification permission onboarding
            } else if !authViewModel.onboardingComplete {
                NotificationPermissionView(notificationService: notificationService)

            // User hasn't completed pairing step yet
            } else if !authViewModel.pairingComplete {
                PairingFlowView()

            // Main app routing based on role
            } else if authViewModel.currentUser?.role == .checker {
                CheckerDashboardView()

            } else if authViewModel.currentUser?.role == .checkInUser {
                CheckInUserDashboardView()

            // Fallback safety state
            } else {
                RoleSelectionView()
            }
        }

        // Smooth transitions between auth states
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.onboardingComplete)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.pairingComplete)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(NotificationService())
}
