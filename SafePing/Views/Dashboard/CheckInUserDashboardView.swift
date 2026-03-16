import SwiftUI

struct CheckInUserDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var checkInViewModel = CheckInViewModel()

    @State private var justCheckedIn = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: {}) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(.safePingDark)
                }

                Spacer()

                Text("SafePing")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.safePingDark)

                Spacer()

                Circle()
                    .fill(Color.safePingBorder)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.safePingTextMuted)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 20) {
                    // Greeting
                    VStack(spacing: 4) {
                        Text("Hey, \(authViewModel.currentUser?.username ?? "there")!")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.safePingDark)

                        if let pairing = checkInViewModel.selectedPairing {
                            Text("Paired with \(pairing.checkerUsername)")
                                .font(.system(size: 14))
                                .foregroundColor(.safePingTextMuted)
                        }
                    }
                    .padding(.top, 8)

                    // Status cards row
                    if let pairing = checkInViewModel.selectedPairing {
                        HStack(spacing: 12) {
                            // Next check-in
                            InfoCard(
                                title: "Next Check-In",
                                value: pairing.schedule.formattedTime,
                                icon: "clock.fill",
                                color: .safePingGreenMid
                            )

                            // Streak
                            InfoCard(
                                title: "Current Streak",
                                value: "\(pairing.currentStreak) days",
                                icon: "flame.fill",
                                color: .orange
                            )
                        }
                        .padding(.horizontal, 20)

                        // Check-in button
                        VStack(spacing: 12) {
                            let todayStatus = pairing.status(for: Date())
                            let alreadyCheckedIn = todayStatus == .checkedIn

                            Button(action: {
                                if !alreadyCheckedIn {
                                    checkInViewModel.performCheckIn()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                        justCheckedIn = true
                                    }
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: alreadyCheckedIn ? "checkmark.circle.fill" : "hand.wave.fill")
                                        .font(.system(size: 22))

                                    Text(alreadyCheckedIn ? "You're all checked in!" : "Check In Now")
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    alreadyCheckedIn
                                    ? LinearGradient(colors: [.safePingGreenEnd, .safePingGreenEnd], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.safePingGreenStart, .safePingGreenEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .cornerRadius(14)
                                .shadow(color: .safePingGreenEnd.opacity(0.3), radius: 8, y: 4)
                                .scaleEffect(justCheckedIn ? 1.03 : 1.0)
                            }
                            .disabled(alreadyCheckedIn)
                            .opacity(alreadyCheckedIn ? 0.85 : 1.0)
                            .padding(.horizontal, 20)

                            if alreadyCheckedIn {
                                Text("Your checker has been notified")
                                    .font(.system(size: 13))
                                    .foregroundColor(.safePingGreenEnd)
                            }
                        }

                        // Calendar
                        CheckInCalendarView(pairing: pairing)
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 20)
                }
            }

            // Bottom tab bar
            BottomTabBar()
        }
        .background(Color.safePingBg.ignoresSafeArea())
        .onAppear {
            if let user = authViewModel.currentUser {
                checkInViewModel.loadMockData(for: user.username, role: .checkInUser)
            }
        }
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.safePingTextMuted)
                .textCase(.uppercase)
                .tracking(0.3)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.safePingDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

#Preview {
    let vm = AuthViewModel()
    vm.currentUser = User(username: "Noah", password: "", role: .checkInUser)
    vm.isAuthenticated = true
    vm.onboardingComplete = true
    return CheckInUserDashboardView().environmentObject(vm)
}
