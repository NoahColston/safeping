import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?

    /// True when the user is logged in but has not yet selected a role
    var needsOnboarding: Bool {
        guard let user = currentUser else { return false }
        return user.role == nil
    }

    // MARK: - In-memory user store (replace with real persistence later)
    private var users: [String: User] = [
        "admin": User(username: "admin", password: "password")
    ]

    // MARK: - Validation
    struct ValidationResult {
        var isValid: Bool
        var usernameError: String?
        var passwordError: String?
        var confirmPasswordError: String?
    }

    func validateRegistration(username: String, password: String, confirmPassword: String) -> ValidationResult {
        var result = ValidationResult(isValid: true)

        if username.trimmingCharacters(in: .whitespaces).count < 3 {
            result.usernameError = "Username must be at least 3 characters."
            result.isValid = false
        }

        if password.count < 6 {
            result.passwordError = "Password must be at least 6 characters."
            result.isValid = false
        }

        if password != confirmPassword {
            result.confirmPasswordError = "Passwords do not match."
            result.isValid = false
        }

        return result
    }

    // MARK: - Login
    func login(username: String, password: String) {
        errorMessage = nil

        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your username and password."
            return
        }

        if let user = users[username], user.password == password {
            currentUser = user
            isAuthenticated = true
        } else {
            errorMessage = "Invalid username or password."
        }
    }

    // MARK: - Register (auto-login on success)
    func register(username: String, password: String, confirmPassword: String) -> ValidationResult {
        errorMessage = nil

        let validation = validateRegistration(
            username: username,
            password: password,
            confirmPassword: confirmPassword
        )

        guard validation.isValid else { return validation }

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)

        if users[trimmedUsername] != nil {
            errorMessage = "That username is already taken."
            return ValidationResult(isValid: false, usernameError: "That username is already taken.")
        }

        // Create account and auto-login (role is nil — triggers onboarding)
        let newUser = User(username: trimmedUsername, password: password)
        users[trimmedUsername] = newUser
        currentUser = newUser
        isAuthenticated = true

        return ValidationResult(isValid: true)
    }

    // MARK: - Role Selection
    func setRole(_ role: UserRole) {
        guard var user = currentUser else { return }
        user.role = role
        currentUser = user
        // Persist back to the in-memory store
        users[user.username] = user
    }

    // MARK: - Logout
    func logout() {
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
    }
}
