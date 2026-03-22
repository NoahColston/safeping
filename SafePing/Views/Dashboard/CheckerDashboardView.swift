import SwiftUI

struct CheckerDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var checkInViewModel = CheckInViewModel()

    @State private var showAddPairing = false
    @State private var showUnpairConfirm = false
    @State private var pairingToRemove: Pairing?

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
                VStack(spacing: 16) {
                    // Story 12: User tabs row + "+" add button
                    HStack(spacing: 0) {
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
                            .padding(.leading, 20)
                            .padding(.trailing, 4)
                        }

                        Button(action: { showAddPairing = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.safePingDark)
                        }
                        .padding(.trailing, 20)
                        .padding(.leading, 8)
                    }

                    if let pairing = checkInViewModel.selectedPairing {
                        // Status card with Story 13 unpair button
                        StatusCard(pairing: pairing) {
                            pairingToRemove = pairing
                            showUnpairConfirm = true
                        }
                        .padding(.horizontal, 20)

                        CheckInCalendarView(pairing: pairing)
                            .padding(.horizontal, 20)

                        CheckInSettingsView(viewModel: checkInViewModel)
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }

            BottomTabBar()
        }
        .background(Color.safePingBg.ignoresSafeArea())
        .onAppear {
            if let user = authViewModel.currentUser {
                Task {
                    await checkInViewModel.loadData(for: user.username, role: .checker)
                }
            }
        }
        .onDisappear {
            checkInViewModel.stopListening()
        }
        // Story 12: Sheet to add a new pairing
        .sheet(isPresented: $showAddPairing, onDismiss: {
            if let user = authViewModel.currentUser {
                Task {
                    await checkInViewModel.loadData(for: user.username, role: .checker)
                }
            }
        }) {
            AddPairingSheet()
                .environmentObject(authViewModel)
        }
        // Story 13: Unpair confirmation
        .confirmationDialog(
            "Remove \(pairingToRemove?.checkInUsername ?? "this user")?",
            isPresented: $showUnpairConfirm,
            titleVisibility: .visible
        ) {
            Button("Unpair", role: .destructive) {
                if let pairing = pairingToRemove {
                    Task { await checkInViewModel.unpairUser(pairing) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will no longer appear in your dashboard.")
        }
    }
}

// MARK: User Tab Pill
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

// MARK: Status Card (Story 13: onUnpair callback)
struct StatusCard: View {
    let pairing: Pairing
    let onUnpair: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pairing.checkInUsername)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.safePingDark)

                Spacer()

                Button(action: onUnpair) {
                    Label("Unpair", systemImage: "person.badge.minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                }
            }

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

// MARK: Story 12: Add Pairing Sheet (checker adds another check-in user)
struct AddPairingSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = PairingViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 52))
                    .foregroundStyle(.indigo)

                VStack(spacing: 8) {
                    Text("Add another user")
                        .font(.title2.bold())

                    Text("Ask the person you're checking on for their 6-digit pairing code.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if vm.isPaired {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.green)

                        Text("Paired with \(vm.pairedWithUsername)!")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            dismiss()
                        }
                    }
                } else {
                    TextField("000000", text: $vm.enteredCode)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .tracking(8)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        .onChange(of: vm.enteredCode) { _, new in
                            if new.count > 6 { vm.enteredCode = String(new.prefix(6)) }
                        }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    Button {
                        Task {
                            await vm.redeemCode(
                                checkerUsername: authViewModel.currentUser?.username ?? ""
                            )
                        }
                    } label: {
                        Group {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Pair with user")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.enteredCode.count == 6 ? .indigo : Color(.tertiarySystemBackground))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(vm.enteredCode.count < 6 || vm.isLoading)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Add User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: Bottom Tab Bar
struct BottomTabBar: View {
    @State private var selectedTab = 0

    var body: some View {
        HStack {
            TabBarItem(icon: "house.fill", isSelected: selectedTab == 0) { selectedTab = 0 }
            TabBarItem(icon: "person.2.fill", isSelected: selectedTab == 1) { selectedTab = 1 }
            TabBarItem(icon: "arrow.counterclockwise", isSelected: selectedTab == 2) { selectedTab = 2 }
            TabBarItem(icon: "gearshape.fill", isSelected: selectedTab == 3) { selectedTab = 3 }
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
