import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var usernameError: String?
    @State private var passwordError: String?
    @State private var confirmError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                BrandHeader()

                // Card
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create your account")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.safePingDark)
                        Text("Get started in seconds — it's free.")
                            .font(.system(size: 15))
                            .foregroundColor(.safePingTextMuted)
                    }

                    // Server-side error
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
                        placeholder: "Choose a username",
                        text: $username,
                        errorMessage: usernameError
                    )
                    .onChange(of: username) { usernameError = nil }
                    .foregroundColor(.black)

                    SafePingTextField(
                        label: "Password",
                        placeholder: "Create a password",
                        text: $password,
                        isSecure: true,
                        errorMessage: passwordError
                    )
                    .onChange(of: password) { passwordError = nil }
                    .foregroundColor(.black)

                    SafePingTextField(
                        label: "Confirm Password",
                        placeholder: "Re-enter your password",
                        text: $confirmPassword,
                        isSecure: true,
                        errorMessage: confirmError
                    )
                    .onChange(of: confirmPassword) { confirmError = nil }
                    .foregroundColor(.black)

                    SafePingButton(title: "Create Account", isLoading: authViewModel.isLoading) {
                        attemptRegistration()
                    }

                    // Back to login
                    HStack {
                        Spacer()
                        Text("Already have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(.safePingTextMuted)
                        Button("Sign in") {
                            dismiss()
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.safePingGreenEnd)
                }
            }
        }
        .onAppear {
            authViewModel.errorMessage = nil
        }
    }

    private func attemptRegistration() {
        // Clear previous errors
        usernameError = nil
        passwordError = nil
        confirmError = nil

        let result = authViewModel.register(
            username: username,
            password: password,
            confirmPassword: confirmPassword
        )

        if !result.isValid {
            usernameError = result.usernameError
            passwordError = result.passwordError
            confirmError = result.confirmPasswordError
        }
        // If valid, AuthViewModel auto-logs in and ContentView switches to HomeView
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
