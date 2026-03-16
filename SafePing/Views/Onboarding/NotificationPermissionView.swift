import SwiftUI

struct NotificationPermissionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
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

                Text("SafePing sends you a gentle reminder when it's time to check in, so your loved ones always know you're okay.")
                    .font(.system(size: 15))
                    .foregroundColor(.safePingTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                SafePingButton(title: "Enable Notifications") {
                    Task {
                        await notificationService.requestPermission()
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
}
