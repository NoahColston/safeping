import SwiftUI

struct CheckInUserDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var checkInViewModel = CheckInViewModel()
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var pairingViewModel = PairingViewModel()

    @State private var justCheckedIn = false
    @State private var showPairingCode = false

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

                // Story 12: tap profile icon to get a new pairing code
                Button(action: { showPairingCode = true }) {
                    Circle()
                        .fill(Color.safePingBorder)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.safePingTextMuted)
                        )
                }
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
                            InfoCard(
                                title: "Next Check-In",
                                value: pairing.schedule.formattedTime,
                                icon: "clock.fill",
                                color: .safePingGreenMid
                            )
                            InfoCard(
                                title: "Current Streak",
                                value: "\(pairing.currentStreak) days",
                                icon: "flame.fill",
                                color: .orange
                            )
                        }
                        .padding(.horizontal, 20)

                        // Calendar
                        CheckInCalendarView(pairing: pairing)
                            .padding(.horizontal, 20)
                    } else {
                        inlinePairingCodeState
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 20)
                }
            }

            // Story 15: Check-in button pinned above the tab bar — always visible, no scrolling needed
            if let pairing = checkInViewModel.selectedPairing {
                pinnedCheckInButton(pairing: pairing)
            }

            BottomTabBar()
        }
        .background(Color.safePingBg.ignoresSafeArea())
        .onAppear {
            if let user = authViewModel.currentUser {
                Task {
                    await checkInViewModel.loadData(for: user.username, role: .checkInUser)
                    // Schedule reminder with checker's custom message (Story 14)
                    if let pairing = checkInViewModel.selectedPairing {
                        let msg = pairing.customReminderMessage.isEmpty ? nil : pairing.customReminderMessage
                        notificationService.scheduleCheckInReminder(
                            message: msg,
                            hour: pairing.schedule.hour,
                            minute: pairing.schedule.minute,
                            username: authViewModel.currentUser?.username ?? ""
                        )
                    } else {
                        await pairingViewModel.generateCode(for: user.username)
                    }
                }
            }
        }
        .onChange(of: checkInViewModel.selectedPairing?.id) { _, newValue in
            guard newValue == nil, let username = authViewModel.currentUser?.username else { return }

            Task {
                await pairingViewModel.generateCode(for: username)
            }
        }
        // Story 12: Sheet to generate a new pairing code for another checker
        .sheet(isPresented: $showPairingCode) {
            GetPairingCodeSheet()
                .environmentObject(authViewModel)
        }
    }
    
    private var inlinePairingCodeState: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 52))
                .foregroundStyle(.teal)

            VStack(spacing: 8) {
                Text("Your pairing code")
                    .font(.title2.bold())
                    .foregroundColor(.safePingDark)

                Text("Share this code with your checker so they can monitor your check-ins.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if pairingViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.vertical, 24)
            } else {
                Text(pairingViewModel.generatedCode)
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                ShareLink(item: "My Safe Ping pairing code is: \(pairingViewModel.generatedCode)") {
                    Label("Share Code", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.teal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button("Generate a new code") {
                    Task {
                        await pairingViewModel.generateCode(
                            for: authViewModel.currentUser?.username ?? ""
                        )
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let error = pairingViewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Pinned check-in button (Story 15)
    @ViewBuilder
    private func pinnedCheckInButton(pairing: Pairing) -> some View {
        let todayStatus = pairing.status(for: Date())
        let alreadyCheckedIn = todayStatus == .checkedIn

        VStack(spacing: 6) {
            Button(action: {
                if !alreadyCheckedIn {
                    Task {
                        await checkInViewModel.performCheckIn(
                            username: authViewModel.currentUser?.username ?? ""
                        )
                        notificationService.simulateCheckerAlert(
                            checkeeName: authViewModel.currentUser?.username ?? "User"
                        )
                    }
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
            .padding(.top, 12)
            .padding(.bottom, 4)

            if alreadyCheckedIn {
                Text("Your checker has been notified")
                    .font(.system(size: 13))
                    .foregroundColor(.safePingGreenEnd)
                    .padding(.bottom, 6)
            }
        }
        .background(Color.safePingBg)
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

// MARK: - Story 12: Get Pairing Code Sheet (checkee shares code with another checker)
struct GetPairingCodeSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = PairingViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.teal)

                VStack(spacing: 8) {
                    Text("Add another checker")
                        .font(.title2.bold())

                    Text("Share this code with someone else who should monitor your check-ins.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if vm.isLoading {
                    ProgressView().scaleEffect(1.5)
                } else {
                    Text(vm.generatedCode)
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .tracking(8)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    ShareLink(item: "My SafePing pairing code is: \(vm.generatedCode)") {
                        Label("Share Code", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.teal)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    Button("Generate a new code") {
                        Task {
                            await vm.generateCode(for: authViewModel.currentUser?.username ?? "")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if let error = vm.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Pairing Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await vm.generateCode(for: authViewModel.currentUser?.username ?? "")
            }
        }
    }
}

#Preview {
    let vm = AuthViewModel()
    vm.currentUser = User(username: "Noah", password: "", role: .checkInUser)
    vm.isAuthenticated = true
    vm.onboardingComplete = true
    return CheckInUserDashboardView().environmentObject(vm)
}
