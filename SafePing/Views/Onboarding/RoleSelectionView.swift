// SafePing — RoleSelectionView.swift
// Onboarding step where the user picks Checker or Check-In User.
// [OOP] Writes the selected role to AuthViewModel, which persists it to Firestore.

import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedRole: UserRole?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                BrandHeader(showTagline: false)

                Text("How will you use SafePing?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.safePingDark)
                    .padding(.top, 16)

                Text("You can change this later in settings.")
                    .font(.system(size: 14))
                    .foregroundColor(.safePingTextMuted)
            }

            // Role cards
            VStack(spacing: 14) {
                RoleCard(
                    role: .checker,
                    isSelected: selectedRole == .checker
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRole = .checker
                    }
                }

                RoleCard(
                    role: .checkInUser,
                    isSelected: selectedRole == .checkInUser
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRole = .checkInUser
                    }
                }
            }
            .padding(.horizontal, 24)

            // Continue button
            SafePingButton(title: "Continue") {
                if let role = selectedRole {
                    authViewModel.setRole(role)
                    // If checker, onboarding is already marked complete in setRole
                    // If check-in user, ContentView routes to NotificationPermissionView
                }
            }
            .opacity(selectedRole == nil ? 0.4 : 1.0)
            .disabled(selectedRole == nil)
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .background(Color.safePingBg.ignoresSafeArea())
    }
}

// MARK: - Role Card Component
struct RoleCard: View {
    let role: UserRole
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                            ? LinearGradient(colors: [.safePingGreenStart, .safePingGreenEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.safePingBg, Color.safePingBg], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: role.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .white : .safePingTextMuted)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(role.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.safePingDark)

                    Text(role.description)
                        .font(.system(size: 13))
                        .foregroundColor(.safePingTextMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Checkmark
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.safePingGreenEnd : Color.safePingBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.safePingGreenEnd)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(18)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.safePingGreenEnd : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: isSelected ? 12 : 8, y: isSelected ? 4 : 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoleSelectionView()
        .environmentObject(AuthViewModel())
}
