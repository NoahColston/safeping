// SafePing — LoginView.swift
// Username + password login screen. Uses SafePingTextField (Theme.swift) so the
// password field gets the eye-icon toggle for free.
// [OOP] Delegates auth logic to AuthViewModel via @EnvironmentObject.

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                BrandHeader()

                // Card
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.safePingDark)
                        Text("Sign in to continue.")
                            .font(.system(size: 15))
                            .foregroundColor(.safePingTextMuted)
                    }

                    // Error alert
                    if let error = authViewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                            Text(error)
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.safePingError)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.safePingErrorBg)
                        .cornerRadius(10)
                    }

                    SafePingTextField(
                        label: "Username",
                        placeholder: "Enter your username",
                        text: $username
                    ).foregroundColor(.black)

                    SafePingTextField(
                        label: "Password",
                        placeholder: "Enter your password",
                        text: $password,
                        isSecure: true
                    ).foregroundColor(.black)

                    SafePingButton(title: "Sign In", isLoading: authViewModel.isLoading) {
                        authViewModel.login(username: username, password: password)
                    }

                    // Register link
                    HStack {
                        Spacer()
                        Text("Don't have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(.safePingTextMuted)
                        NavigationLink("Create one") {
                            RegisterView()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.safePingGreenEnd)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(28)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 16, y: 4)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .background(Color.safePingBg.ignoresSafeArea())
        .onAppear {
            authViewModel.errorMessage = nil
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
