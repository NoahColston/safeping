// SafePing NotificationPermissionView.swift
// Onboarding step that requests UNUserNotificationCenter authorization
// This screen explains why notifications and location permissions are needed before first use
//


// - Uses NotificationService to request system notification permission
// - Uses LocationService for optional location access
// - Completes onboarding regardless of user choice

import SwiftUI

struct NotificationPermissionView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var locationService: LocationService

    // Notification service is observed directly
    @ObservedObject var notificationService: NotificationService

    // Tracks whether user has made a decision (enable or skip)
    @State private var hasResponded = false

    var body: some View {
        VStack(spacing: 28) {

            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.safePingGreenStart.opacity(0.15),
                                     .safePingGreenEnd.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.safePingGreenStart, .safePingGreenEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Explains why permissions are needed in user friendly terms
            VStack(spacing: 10) {
                Text("Stay on track")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.safePingDark)

                Text(
                    "SafePing needs notifications to remind you when it's time to check in. " +
                    "Your location is only captured when you check in and will only be shared if you miss a check in."
                )
                .font(.system(size: 15))
                .foregroundColor(.safePingTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 20)
            }

            Spacer()

            VStack(spacing: 12) {

                // Primary action: request system permissions
                SafePingButton(title: "Enable Permissions") {
                    Task {
                        await notificationService.requestPermission()
                        locationService.requestPermission()

                        // Mark onboarding step complete locally
                        hasResponded = true
                    }
                }

                // Secondary action: skip permissions for now
                Button("Maybe later") {
                    hasResponded = true
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.safePingTextMuted)
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }

        .background(Color.safePingBg.ignoresSafeArea())

        // Advances app flow regardless of permission choice
        .onChange(of: hasResponded) {
            if hasResponded {
                authViewModel.completeOnboarding()
            }
        }
    }
}

#Preview {
    NotificationPermissionView(notificationService: NotificationService())
        .environmentObject(AuthViewModel())
        .environmentObject(LocationService())
}
