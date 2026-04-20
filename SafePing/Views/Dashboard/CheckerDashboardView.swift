// SafePing — CheckerDashboardView.swift
// Dashboard for checkers: shows paired users, their status, calendar, and map.
// [OOP] Delegates data fetching and pairing mutations to CheckInViewModel.

import SwiftUI
import MapKit

struct CheckerDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var checkInViewModel = CheckInViewModel()

    @State private var showAddPairing = false
    @State private var showUnpairConfirm = false
    @State private var pairingToRemove: Pairing?
    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 0) {
                Text("Safe")
                    .foregroundColor(.safePingDark)

                Text("Ping")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.safePingGreenStart, .safePingGreenEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .font(.system(size: 22, weight: .bold, design: .rounded))
            
            if let error = checkInViewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            if selectedTab == 2 {
                CheckerMapView(checkInViewModel: checkInViewModel)
            } else if selectedTab == 1 {
                EscalationsView(checkInViewModel: checkInViewModel)
            } else if selectedTab == 3 {
                SettingsView()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Story 12: User tabs row + "+" add button
                        if checkInViewModel.pairings.isEmpty {
                            checkerEmptyState
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                        else {
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
                .refreshable {
                    if let user = authViewModel.currentUser {
                        await checkInViewModel.loadData(for: user.username, role: .checker)
                    }
                }
            }
            BottomTabBar(
                selectedTab: $selectedTab,
                icons: ["house.fill", "exclamationmark.triangle.fill", "map.fill", "gearshape.fill"]
            )
        }
        .background(Color.safePingBg.ignoresSafeArea())
        .onAppear {
            if let user = authViewModel.currentUser {
                Task {
                    await checkInViewModel.loadData(for: user.username, role: .checker)
                }
            }
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
                .environmentObject(notificationService)
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
    private var checkerEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.safePingGreenEnd)

            VStack(spacing: 6) {
                Text("Add your first user")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.safePingDark)

                Text("Pair with someone to start tracking their check-ins and reminders.")
                    .font(.system(size: 14))
                    .foregroundColor(.safePingTextMuted)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showAddPairing = true }) {
                Label("Add User", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.safePingDark)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
    @Binding var selectedTab: Int
    var icons: [String] = ["house.fill", "person.2.fill", "map.fill", "gearshape.fill"]

    var body: some View {
        HStack {
            ForEach(icons.indices, id: \.self) { i in
                TabBarItem(icon: icons[i], isSelected: selectedTab == i) { selectedTab = i }
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
        .environmentObject(NotificationService())
}
