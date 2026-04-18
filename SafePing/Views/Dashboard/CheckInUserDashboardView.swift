import SwiftUI

struct CheckInUserDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var checkInViewModel = CheckInViewModel()
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var locationService: LocationService
    @StateObject private var pairingViewModel = PairingViewModel()
    
    @State private var pulsingScheduleId: UUID?
    @State private var showPairingCode = false
    @State private var selectedTab = 0
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: { showSettings = true }) {
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
            
            if selectedTab == 3 {
                SettingsView()
            } else if selectedTab == 2 {
                if let pairing = checkInViewModel.selectedPairing {
                    CheckeeLocationView(pairing: pairing)
                } else {
                    noPairingPlaceholder
                }
            } else if selectedTab == 1 {
                if let pairing = checkInViewModel.selectedPairing {
                    CheckInLogView(pairing: pairing)
                } else {
                    noPairingPlaceholder
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Greeting
                        VStack(spacing: 4) {
                            Text("Hey, \(authViewModel.currentUser?.username ?? "there")!")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.safePingDark)
                        }
                        .padding(.top, 8)
                        
                        if checkInViewModel.pairings.isEmpty {
                            // No checkers yet — show inline pairing code
                            inlinePairingCodeState
                                .padding(.horizontal, 20)
                        } else {
                            if checkInViewModel.pairings.count > 1 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(checkInViewModel.pairings) { pairing in
                                            UserTab(
                                                name: pairing.checkerUsername,
                                                isSelected: pairing.id == (checkInViewModel.selectedPairingId ?? checkInViewModel.pairings.first?.id)
                                            ) {
                                                checkInViewModel.selectPairing(pairing)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            if let pairing = checkInViewModel.selectedPairing {
                                Text("Checked in with \(pairing.checkerUsername)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.safePingTextMuted)
                                
                                // Status cards row
                                HStack(spacing: 12) {
                                    InfoCard(
                                        title: "Next Check-In",
                                        value: pairing.nextScheduledFormatted,
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
                                
                                todaysCheckInsCard(pairing: pairing)
                                    .padding(.horizontal, 20)
                                // Calendar
                                CheckInCalendarView(pairing: pairing)
                                    .padding(.horizontal, 20)
                                
                            }
                            Spacer().frame(height: 20)
                        }
                    }
                }
                
                .refreshable {
                    if let user = authViewModel.currentUser {
                        await checkInViewModel.loadData(for: user.username, role: .checkInUser)
                    }
                }
            }
            BottomTabBar(
                selectedTab: $selectedTab,
                icons: ["house.fill", "list.bullet.clipboard.fill", "location.fill", "gearshape.fill"]
            )
        }
        .background(Color.safePingBg.ignoresSafeArea())
        .onAppear {
            if let user = authViewModel.currentUser {
                Task {
                    await checkInViewModel.loadData(for: user.username, role: .checkInUser)
                    // Schedule reminder with checker's custom message (Story 14)
                    if checkInViewModel.pairings.isEmpty {
                        await pairingViewModel.generateCode(for: user.username)
                    } else {
                        // Ensure notifications are always scheduled on launch,
                        // not just when pairingsFingerprint changes.
                        notificationService.scheduleAllReminders(
                            for: checkInViewModel.pairings,
                            username: user.username
                        )
                        notificationService.scheduleEscalationNotifications(
                            for: checkInViewModel.pairings,
                            username: user.username
                        )
                    }
                }
            }
        }
        .onDisappear {
                    checkInViewModel.stopListening()
        }
        .onChange(of: pairingsFingerprint) { _, _ in
            guard let username = authViewModel.currentUser?.username else { return }
            notificationService.scheduleAllReminders(
                for: checkInViewModel.pairings,
                username: username
            )
            notificationService.scheduleEscalationNotifications(
                for: checkInViewModel.pairings,
                username: username
            )
        }
        .onChange(of: checkInViewModel.selectedPairing?.id) { _, newValue in
            guard newValue == nil, let username = authViewModel.currentUser?.username else { return }
            
            Task {
                await pairingViewModel.generateCode(for: username)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authViewModel)
                .environmentObject(notificationService)
                .environmentObject(locationService)
        }
        // Story 12: Sheet to generate a new pairing code for another checker
        .sheet(isPresented: $showPairingCode) {
            GetPairingCodeSheet()
                .environmentObject(authViewModel)
                .environmentObject(notificationService)
                .environmentObject(locationService)
        }
    }
    
    private var noPairingPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.safePingTextMuted)
            Text("No checker yet")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.safePingDark)
            Text("Pair with a checker first to see this data.")
                .font(.system(size: 14))
                .foregroundColor(.safePingTextMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.safePingBg)
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
                    .foregroundStyle(.black)
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
    /// Cheap fingerprint of the fields that should trigger a notification
    /// reschedule when they change.
    private var pairingsFingerprint: String {
        checkInViewModel.pairings.map { pairing in
            let scheduleParts = pairing.schedules.map {
                "\($0.id.uuidString):\($0.hour):\($0.minute):\($0.frequency.rawValue):\($0.activeDays.sorted()):\($0.message):\($0.gracePeriodMinutes)"
            }.joined(separator: "|")
            return "\(pairing.id.uuidString)#\(scheduleParts)"
        }.joined(separator: "/")
    }

    // MARK: - Today's check-ins card (per-slot buttons)
    @ViewBuilder
    private func todaysCheckInsCard(pairing: Pairing) -> some View {
        let today = Date()
        let todaysSchedules = pairing.schedules(forDate: today)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.safePingDark)

                Spacer()

                if !todaysSchedules.isEmpty {
                    let doneCount = todaysSchedules.filter {
                        pairing.status(for: today, scheduleId: $0.id) == .checkedIn
                    }.count
                    Text("\(doneCount) of \(todaysSchedules.count) done")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.safePingTextMuted)
                }
            }

            if todaysSchedules.isEmpty {
                Text("No check-ins scheduled for today.")
                    .font(.system(size: 14))
                    .foregroundColor(.safePingTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(todaysSchedules) { schedule in
                        TodaySlotRow(
                            schedule: schedule,
                            status: pairing.status(for: today, scheduleId: schedule.id),
                            isPulsing: pulsingScheduleId == schedule.id,
                            checkerUsername: pairing.checkerUsername,
                            isAvailable: checkInViewModel.isCheckInAvailable(for: schedule),
                            opensAt: checkInViewModel.checkInOpensAt(for: schedule),
                            onCheckIn: { performCheckIn(scheduleId: schedule.id) }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private func performCheckIn(scheduleId: UUID) {
        locationService.captureLocation()
        let coordinate = locationService.currentLocation?.coordinate
        let pairingId = checkInViewModel.selectedPairing?.id
        Task {
            await checkInViewModel.performCheckIn(
                username: authViewModel.currentUser?.username ?? "",
                scheduleId: scheduleId,
                location: coordinate
            )
            notificationService.simulateCheckerAlert(
                checkeeName: authViewModel.currentUser?.username ?? "User"
            )
            if let pairingId {
                notificationService.cancelEscalationForSchedule(
                    pairingId: pairingId,
                    scheduleId: scheduleId
                )
            }
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            pulsingScheduleId = scheduleId
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if pulsingScheduleId == scheduleId {
                pulsingScheduleId = nil
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - Today slot row (one per scheduled check-in for the day)
private struct TodaySlotRow: View {
    let schedule: CheckInSchedule
    let status: CheckInStatus?
    let isPulsing: Bool
    let checkerUsername: String
    let isAvailable: Bool
    let opensAt: String
    let onCheckIn: () -> Void

    private var alreadyCheckedIn: Bool { status == .checkedIn }
    private var wasMissed: Bool { status == .missed }
    private var tooEarly: Bool { !alreadyCheckedIn && !wasMissed && !isAvailable }

    var body: some View {
        Button(action: { if !alreadyCheckedIn { onCheckIn() } }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 38, height: 38)
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.displayMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.safePingDark)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.safePingTextMuted)
                }

                Spacer()

                if !alreadyCheckedIn {
                    Text(tooEarly ? "Opens \(opensAt)" : "Check In")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            tooEarly
                            ? LinearGradient(
                                colors: [.safePingTextMuted.opacity(0.4), .safePingTextMuted.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [.safePingGreenStart, .safePingGreenEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                }
            }
            .padding(12)
            .background(rowBackground)
            .cornerRadius(12)
            .scaleEffect(isPulsing ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(alreadyCheckedIn || tooEarly)
    }

    private var subtitle: String {
        if alreadyCheckedIn { return "Done · \(checkerUsername) notified" }
        if wasMissed { return "Missed · \(schedule.formattedTime)" }
        if tooEarly { return "Available at \(opensAt)" }
        return schedule.formattedTime
    }

    private var iconName: String {
        if alreadyCheckedIn { return "checkmark.circle.fill" }
        if wasMissed { return "exclamationmark.circle.fill" }
        if tooEarly { return "lock.fill" }
        return "clock.fill"
    }

    private var iconColor: Color {
        if alreadyCheckedIn { return .safePingGreenEnd }
        if wasMissed { return .safePingError }
        if tooEarly { return .safePingTextMuted }
        return .safePingGreenMid
    }

    private var iconBackground: Color {
        if alreadyCheckedIn { return Color.safePingSuccessBg }
        if wasMissed { return Color.safePingErrorBg }
        return Color.safePingGreenMid.opacity(0.12)
    }

    private var rowBackground: Color {
        alreadyCheckedIn ? Color.safePingSuccessBg.opacity(0.6) : Color.safePingBg.opacity(0.5)
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
                    .foregroundStyle(.indigo)

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
                            .background(.indigo)
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
    return CheckInUserDashboardView()
        .environmentObject(vm)
        .environmentObject(NotificationService())
        .environmentObject(LocationService())
}
