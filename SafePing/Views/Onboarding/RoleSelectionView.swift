// SafePing  RoleSelectionView.swift
// Onboarding step where the user selects their role: Checker or CheckIn User
//

// - User selection is stored locally in @State
// - Final selection is committed to AuthViewModel
// - AuthViewModel persists role to backend
// - Navigation flow depends on selected role

import SwiftUI

struct RoleSelectionView: View {

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var selectedRole: UserRole?

    var body: some View {
        VStack(spacing: 28) {

            Spacer()

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

            // User must choose exactly one role before continuing
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

            // Only enabled once a role has been selected
            SafePingButton(title: "Continue") {
                if let role = selectedRole {

                    // Persist role selection to backend via AuthViewModel
                    authViewModel.setRole(role)

                    // Flow control is handled externally:
                    // - Checker to skips onboarding completion path
                    // - Check-in user to proceeds to notification permission step
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

// Reusable selection card representing a user role option
struct RoleCard: View {

    let role: UserRole
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {

            HStack(spacing: 16) {

                ZStack {
                    Circle()
                        .fill(
                            isSelected
                            ? LinearGradient(
                                colors: [.safePingGreenStart, .safePingGreenEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.safePingBg, Color.safePingBg],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: role.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .white : .safePingTextMuted)
                }

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

                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.safePingGreenEnd : Color.safePingBorder,
                            lineWidth: 2
                        )
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

            // Highlight selected state visually with border and stronger shadow
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.safePingGreenEnd : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: .black.opacity(isSelected ? 0.08 : 0.04),
                radius: isSelected ? 12 : 8,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoleSelectionView()
        .environmentObject(AuthViewModel())
}
