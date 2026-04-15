import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var onboardingComplete = false
    @Published var pairingComplete: Bool = false
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private var pairsListener: ListenerRegistration?
    
    init() {
        Task {
            await restoreSession()
        }
    }

    /// True when the user is logged in but has not yet selected a role
    var needsRoleSelection: Bool {
        guard let user = currentUser else { return false }
        return user.role == nil
    }

    /// True when the user has a role but onboarding isn't finished
    var needsOnboarding: Bool {
        guard isAuthenticated, let user = currentUser else { return false }
        if user.role == nil { return true }
        if !onboardingComplete { return true }
        return false
    }

    // MARK: - Session Restore
    func restoreSession() async {
        guard let savedUsername = UserDefaults.standard.string(forKey: "currentUsername") else { return }
        isLoading = true
        do {
            let doc = try await db.collection(usersCollection).document(savedUsername).getDocument()
            if let data = doc.data(), let user = userFromFirestore(data) {
                currentUser = user
                isAuthenticated = true
                onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete_\(savedUsername)")
                loadPairingState()
                startPairsListener()
            } else {
                // Account no longer exists in Firebase - clear stale session
                UserDefaults.standard.removeObject(forKey: "currentUsername")
            }
        } catch {
            // Network unavailable - clear session so user can log in again
            UserDefaults.standard.removeObject(forKey: "currentUsername")
        }
        isLoading = false
    }

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

        isLoading = true
        Task {
            do {
                let doc = try await db.collection(usersCollection).document(username).getDocument()
                if let data = doc.data(), let user = userFromFirestore(data), user.password == password {
                    currentUser = user
                    isAuthenticated = true
                    onboardingComplete = user.role != nil &&
                        UserDefaults.standard.bool(forKey: "onboardingComplete_\(username)")
                    UserDefaults.standard.set(username, forKey: "currentUsername")
                    loadPairingState()
                    startPairsListener()
                } else {
                    errorMessage = "Invalid username or password."
                }
            } catch {
                errorMessage = "Login failed. Please check your connection."
            }
            isLoading = false
        }
    }

    // MARK: - Pairing
    func completePairing() {
        pairingComplete = true
    }

    func loadPairingState() {
        guard let username = currentUser?.username else {
            pairingComplete = false
            return
        }
        pairingComplete = UserDefaults.standard.bool(forKey: "pairingComplete_\(username)")
    }
    
    private func startPairsListener() {
        pairsListener?.remove()
        pairsListener = nil

        guard let user = currentUser, let role = user.role else { return }
        let field = role == .checker ? "checkerUsername" : "checkInUsername"

        pairsListener = db.collection("pairs")
            .whereField(field, isEqualTo: user.username)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                let hasPairs = !(snapshot?.documents.isEmpty ?? true)
                Task { @MainActor in
                    self.pairingComplete = hasPairs
                    // Cache so the next cold launch can show the right screen
                    // immediately, before the listener's first snapshot arrives.
                    UserDefaults.standard.set(
                        hasPairs,
                        forKey: "pairingComplete_\(user.username)"
                    )
                }
            }
    }

    private func stopPairsListener() {
        pairsListener?.remove()
        pairsListener = nil
    }

    // MARK: - Register (field validation is synchronous; Firebase write is async)
    func register(username: String, password: String, confirmPassword: String) -> ValidationResult {
        errorMessage = nil

        let validation = validateRegistration(
            username: username,
            password: password,
            confirmPassword: confirmPassword
        )

        guard validation.isValid else { return validation }

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)

        isLoading = true
        Task {
            do {
                let existing = try await db.collection(usersCollection).document(trimmedUsername).getDocument()
                if existing.exists {
                    errorMessage = "That username is already taken."
                    isLoading = false
                    return
                }

                let newUser = User(username: trimmedUsername, password: password)
                try await db.collection(usersCollection)
                    .document(trimmedUsername)
                    .setData(userToFirestore(newUser))

                currentUser = newUser
                isAuthenticated = true
                onboardingComplete = false
                pairingComplete = false
                UserDefaults.standard.set(trimmedUsername, forKey: "currentUsername")
                startPairsListener()
            } catch {
                errorMessage = "Registration failed. Please try again."
            }
            isLoading = false
        }

        return ValidationResult(isValid: true)
    }

    // MARK: - Role Selection
    func setRole(_ role: UserRole) {
        guard var user = currentUser else { return }
        user.role = role
        currentUser = user

        Task {
            try? await db.collection(usersCollection)
                .document(user.username)
                .updateData(["role": role.rawValue])
        }

        // Checkers don't need the notification step - finish onboarding
        if role == .checker {
            onboardingComplete = true
            UserDefaults.standard.set(true, forKey: "onboardingComplete_\(user.username)")
        }
        startPairsListener()
    }

    // MARK: - Complete Onboarding
    func completeOnboarding() {
        onboardingComplete = true
        if let username = currentUser?.username {
            UserDefaults.standard.set(true, forKey: "onboardingComplete_\(username)")
        }
    }

    // MARK: - Logout
    func logout() {
        stopPairsListener()
        if let username = currentUser?.username {
                UserDefaults.standard.removeObject(forKey: "pairingComplete_\(username)")
        }
        UserDefaults.standard.removeObject(forKey: "currentUsername")
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        onboardingComplete = false
        pairingComplete = false
    }

    // MARK: - Firestore Helpers
    private func userToFirestore(_ user: User) -> [String: Any] {
        var data: [String: Any] = [
            "id": user.id.uuidString,
            "username": user.username,
            "password": user.password
        ]
        if let role = user.role {
            data["role"] = role.rawValue
        }
        return data
    }

    private func userFromFirestore(_ data: [String: Any]) -> User? {
        guard
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let username = data["username"] as? String,
            let password = data["password"] as? String
        else { return nil }

        let role = (data["role"] as? String).flatMap(UserRole.init(rawValue:))
        return User(id: id, username: username, password: password, role: role)
    }
}
