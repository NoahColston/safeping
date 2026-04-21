// SafePing — SettingsView.swift
// App settings: account info, notifications, about, sign out, and seed controls
// [UI Layer] Pure SwiftUI view driven by AuthViewModel and NotificationService state

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationService: NotificationService

    //Service used to populate mock data for development/testing
    @StateObject private var seedService = SeedService()

    // Controls confirmation dialog for destructive account deletion
    @State private var showDeleteConfirm = false


    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        ScrollView {

            // Main vertical stack for grouped settings sections
            VStack(spacing: 24) {

                // MARK: - Account Section (user identity + role display)
                SettingsSection(title: "Account") {

                    // Displays current logged-in username
                    SettingsRow(
                        icon: "person.fill",
                        iconColor: .safePingGreenMid,
                        label: "Username"
                    ) {
                        Text(authViewModel.currentUser?.username ?? "—")
                            .font(.system(size: 14))
                            .foregroundColor(.safePingTextMuted)
                    }

                    Divider().padding(.leading, 52)

                    // Displays user role
                    SettingsRow(
                        icon: authViewModel.currentUser?.role?.iconName ?? "questionmark",
                        iconColor: .safePingGreenMid,
                        label: "Role"
                    ) {
                        if let role = authViewModel.currentUser?.role {
                            Text(role.displayName)
                                .font(.system(size: 14))
                                .foregroundColor(.safePingTextMuted)
                        }
                    }
                }

                // Shown only when notifications are disabled at system level
                if authViewModel.currentUser?.role == .checkInUser &&
                   notificationService.permissionStatus == .denied {

                    SettingsSection(title: "Notifications") {

                        // Redirects user to iOS Settings app to enable notifications
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            SettingsRow(
                                icon: "exclamationmark.triangle.fill",
                                iconColor: .orange,
                                label: "Notifications Blocked"
                            ) {
                                HStack(spacing: 4) {
                                    Text("Open Settings")
                                        .font(.system(size: 13))
                                        .foregroundColor(.safePingGreenEnd)

                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(.safePingGreenEnd)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSection(title: "About") {

                    // App version/build display
                    SettingsRow(
                        icon: "info.circle.fill",
                        iconColor: .safePingTextMuted,
                        label: "Version"
                    ) {
                        Text("\(appVersion) (\(buildNumber))")
                            .font(.system(size: 14))
                            .foregroundColor(.safePingTextMuted)
                    }

                    Divider().padding(.leading, 52)

                    // Support email link
                    Link(destination: URL(string: "mailto:support@safeping.app")!) {
                        SettingsRow(
                            icon: "envelope.fill",
                            iconColor: .safePingTextMuted,
                            label: "Send Feedback"
                        ) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13))
                                .foregroundColor(.safePingBorder)
                        }
                    }
                    .buttonStyle(.plain)
                }

                #if DEBUG
                SettingsSection(title: "Developer") {

                    // Seeds sample users into backend for testing flows
                    Button(action: {
                        Task { await seedService.seedSampleUsers() }
                    }) {
                        SettingsRow(
                            icon: "person.3.fill",
                            iconColor: .indigo,
                            label: "Seed Sample Users"
                        ) {
                            if seedService.isSeeding {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.safePingBorder)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(seedService.isSeeding)

                    // Debug feedback from seeding process
                    if let msg = seedService.seedMessage {
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundColor(.safePingTextMuted)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }
                }
                #endif

                SettingsSection(title: "Account Actions") {

                    // Sign out: clears session and cancels scheduled notifications
                    Button(action: {
                        notificationService.cancelAllNotifications()
                        authViewModel.logout()
                    }) {
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            iconColor: .safePingError,
                            label: "Sign Out"
                        ) {
                            EmptyView()
                        }
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 52)

                    // Delete account trigger
                    Button(action: {
                        showDeleteConfirm = true
                    }) {
                        SettingsRow(
                            icon: "trash.fill",
                            iconColor: .safePingError,
                            label: "Delete Account"
                        ) {
                            if authViewModel.isDeleting {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(.safePingBorder)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(authViewModel.isDeleting)
                }

                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }

        // Background styling for entire settings screen
        .background(Color.safePingBg.ignoresSafeArea())

        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task {
                    notificationService.cancelAllNotifications()
                    await authViewModel.deleteAccount()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove your account and all check-in history. This cannot be undone.")
        }

        // Refresh notification permission state when view appears
        .task {
            await notificationService.refreshPermissionStatus()
        }
    }
}

// Reusable grouped container for settings categories
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Section header label
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.safePingTextMuted)
                .tracking(0.5)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            // Card style container for grouped rows
            VStack(spacing: 0) {
                content
            }
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }
}

// Reusable row component used across all settings sections
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let label: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {

            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
            }

            // Main label text
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.safePingDark)

            Spacer()

            // Right side content
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

#Preview {
    let auth = AuthViewModel()
    auth.currentUser = User(username: "noah", password: "", role: .checkInUser)
    auth.isAuthenticated = true

    return SettingsView()
        .environmentObject(auth)
        .environmentObject(NotificationService())
}
