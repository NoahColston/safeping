import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationService: NotificationService

    @State private var showDeleteConfirm = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // MARK: - Account
                SettingsSection(title: "Account") {
                    // Username
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

                    // Role
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

                    Divider().padding(.leading, 52)

                    // Change role — stubbed until role-switching is implemented
                    SettingsRow(
                        icon: "arrow.left.arrow.right",
                        iconColor: .safePingTextMuted,
                        label: "Change Role"
                    ) {
                        HStack(spacing: 4) {
                            Text("Coming soon")
                                .font(.system(size: 12))
                                .foregroundColor(.safePingTextMuted)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.safePingBorder)
                        }
                    }
                    .opacity(0.5)
                }

                // MARK: - Notifications (check-in users only)
                if authViewModel.currentUser?.role == .checkInUser &&
                   notificationService.permissionStatus == .denied {
                    SettingsSection(title: "Notifications") {
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

                // MARK: - About
                SettingsSection(title: "About") {
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

                // MARK: - Danger Zone
                SettingsSection(title: "Account Actions") {
                    Button(action: {
                        notificationService.cancelAllNotifications()
                        authViewModel.logout() }) {
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

                    Button(action: { showDeleteConfirm = true }) {
                        SettingsRow(
                            icon: "trash.fill",
                            iconColor: .safePingError,
                            label: "Delete Account"
                        ) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundColor(.safePingBorder)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.safePingBg.ignoresSafeArea())
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                // TODO: implement account deletion
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove your account and all check-in history. This cannot be undone.")
        }
        .task {
            await notificationService.refreshPermissionStatus()
        }
    }
}

// MARK: - Settings Section Container
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.safePingTextMuted)
                .tracking(0.5)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }
}

// MARK: - Settings Row
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let label: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
            }

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.safePingDark)

            Spacer()

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
