// SafePing — NotificationPermissionView.swift
// Onboarding step that requests UNUserNotificationCenter authorization.
// [OOP] Delegates permission request to NotificationService via @EnvironmentObject.

import SwiftUI

struct NotificationPermissionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var locationService: LocationService
    @ObservedObject var notificationService: NotificationService

    @State private var hasResponded = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Bell icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.safePingGreenStart.opacity(0.15), .safePingGreenEnd.opacity(0.10)],
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

            // Copy
            VStack(spacing: 10) {
                Text("Stay on track")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.safePingDark)

                Text("SafePing needs notifications to remind you when it's time to check in. Your location is only captured when you check in and will only be shared if you miss a check in.")
                    .font(.system(size: 15))
                    .foregroundColor(.safePingTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                SafePingButton(title: "Enable Permissions") {
                    Task {
                        await notificationService.requestPermission()
                        locationService.requestPermission()
                        hasResponded = true
                    }
                }

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
