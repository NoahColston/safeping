import SwiftUI

struct CheckerDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var checkInViewModel = CheckInViewModel()

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

                // Profile avatar placeholder
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
                VStack(spacing: 16) {
                    // Paired user tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(checkInViewModel.pairings) { pairing in
                                UserTab(
                                    name: pairing.checkInUsername,
                                    isSelected: pairing.id == (checkInViewModel.selectedPairingId ?? checkInViewModel.pairings.first?.id)
                                ) {
                                    checkInViewModel.selectPairing(pairing)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Status card
                    if let pairing = checkInViewModel.selectedPairing {
                        StatusCard(pairing: pairing)
                            .padding(.horizontal, 20)

                        // Calendar
                        CheckInCalendarView(pairing: pairing)
                            .padding(.horizontal, 20)

                        // Check-in settings
                        CheckInSettingsView(viewModel: checkInViewModel)
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }

            // Bottom tab bar
            BottomTabBar()
        }
        .background(Color.safePingBg.ignoresSafeArea())
        .onAppear {
            if let user = authViewModel.currentUser {
                checkInViewModel.loadMockData(for: user.username, role: .checker)
            }
        }
    }
}

// MARK: - User Tab Pill
struct UserTab: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .safePingDark)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isSelected ? Color.safePingDark : Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: 4, y: 2)
        }
    }
}

// MARK: - Status Card
struct StatusCard: View {
    let pairing: Pairing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pairing.checkInUsername)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.safePingDark)

            Text(pairing.timeSinceLastCheckIn)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.safePingDark)

            if !pairing.lastCheckInDescription.isEmpty {
                Text(pairing.lastCheckInDescription)
                    .font(.system(size: 13))
                    .foregroundColor(.safePingTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - Bottom Tab Bar
struct BottomTabBar: View {
    @State private var selectedTab = 0

    var body: some View {
        HStack {
            TabBarItem(icon: "house.fill", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            TabBarItem(icon: "person.2.fill", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            TabBarItem(icon: "arrow.counterclockwise", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
            TabBarItem(icon: "gearshape.fill", isSelected: selectedTab == 3) {
                selectedTab = 3
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
        )
    }
}

struct TabBarItem: View {
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .safePingDark : .safePingTextMuted)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    CheckerDashboardView()
        .environmentObject(AuthViewModel())
}
