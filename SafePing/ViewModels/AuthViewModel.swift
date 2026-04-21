// SafePing  AuthViewModel.swift
// Manages authentication state: login, registration, session restore, and role selection
// [OOP] @MainActor class encapsulates all auth state and Firestore operations.
// [Procedural] login() and register() sequence: validate → hash → read/write Firestore → update state.
// [Functional] Computed properties (needsRoleSelection, needsNotificationPermission) derive
//              booleans from published state without side effects.

import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
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

    // True when the user is logged in but has not yet selected a role
    var needsRoleSelection: Bool {
        guard let user = currentUser else { return false }
        return user.role == nil
    }

    // Restores user session from local storage and loads Firestore user data if available
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
                // Account no longer exists in Firebase  clear stale session
                UserDefaults.standard.removeObject(forKey: "currentUsername")
            }
        } catch {
            // Network unavailable clear session so user can log in again
            UserDefaults.standard.removeObject(forKey: "currentUsername")
        }
        isLoading = false
    }

    // Validates registration input before attempting Firestore write.
    struct ValidationResult {
        var isValid: Bool
        var usernameError: String?
        var passwordError: String?
        var confirmPasswordError: String?
    }

    // Checks username length, password strength, and password match.
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

    // Procedural flow: validate input → fetch Firestore user → hash compare → update session state.
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
                if let data = doc.data(), let user = userFromFirestore(data), user.password == CryptoUtils.hashPassword(password) {
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

    // Updates local pairing completion state
    func completePairing() {
        pairingComplete = true
    }

    // Loads cached pairing state from UserDefaults
    func loadPairingState() {
        guard let username = currentUser?.username else {
            pairingComplete = false
            return
        }
        pairingComplete = UserDefaults.standard.bool(forKey: "pairingComplete_\(username)")
    }
    
    // Starts Firestore listener to detect when user gets paired
    private func startPairsListener() {
        pairsListener?.remove()
        pairsListener = nil

        guard let user = currentUser, let role = user.role else { return }

        // If already paired, no need for a live listener
        // CheckInViewModel handles live updates on the dashboard
        if pairingComplete { return }

        let field = role == .checker ? "checkerUsername" : "checkInUsername"

        pairsListener = db.collection("pairs")
            .whereField(field, isEqualTo: user.username)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                let hasPairs = !(snapshot?.documents.isEmpty ?? true)
                Task { @MainActor in
                    self.pairingComplete = hasPairs
                    UserDefaults.standard.set(
                        hasPairs,
                        forKey: "pairingComplete_\(user.username)"
                    )
                    // Once paired, CheckInViewModel takes over
                    if hasPairs {
                        self.stopPairsListener()
                    }
                }
            }
    }

    // Stops Firestore listener when no longer needed
    private func stopPairsListener() {
        pairsListener?.remove()
        pairsListener = nil
    }

    // Procedural flow: validate → check existence → hash password → write user → update state.
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

                let newUser = User(username: trimmedUsername, password: CryptoUtils.hashPassword(password))
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

    // Updates user role in Firestore and local state.
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

    func completeOnboarding() {
        onboardingComplete = true
        if let username = currentUser?.username {
            UserDefaults.standard.set(true, forKey: "onboardingComplete_\(username)")
        }
    }

    // Clears local session state and stops active listeners.
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

    // Permanently deletes user data from Firestore (users, pairs, check-ins, codes).
    @Published var isDeleting = false

    func deleteAccount() async {
        guard let user = currentUser else { return }
        let username = user.username
        isDeleting = true
        errorMessage = nil

        do {
            // Find all pairings where this user is either side
            let asChecker = try await db.collection("pairs")
                .whereField("checkerUsername", isEqualTo: username)
                .getDocuments()
            let asCheckIn = try await db.collection("pairs")
                .whereField("checkInUsername", isEqualTo: username)
                .getDocuments()

            let allPairDocs = asChecker.documents + asCheckIn.documents
            let pairingIds = allPairDocs.map { $0.documentID }

            // Delete all check-ins for each pairing
            for pairingId in pairingIds {
                let checkInDocs = try await db.collection("checkIns")
                    .whereField("pairingId", isEqualTo: pairingId)
                    .getDocuments()

                for doc in checkInDocs.documents {
                    try await doc.reference.delete()
                }
            }

            // Delete all pairing documents
            for doc in allPairDocs {
                try await doc.reference.delete()
            }

            // Delete any pairing codes they generated
            let codes = try await db.collection("pairingCodes")
                .whereField("checkeeUsername", isEqualTo: username)
                .getDocuments()
            for doc in codes.documents {
                try await doc.reference.delete()
            }

            // Delete the user document
            try await db.collection(usersCollection).document(username).delete()

            // Clear local state
            stopPairsListener()
            UserDefaults.standard.removeObject(forKey: "pairingComplete_\(username)")
            UserDefaults.standard.removeObject(forKey: "onboardingComplete_\(username)")
            UserDefaults.standard.removeObject(forKey: "currentUsername")
            currentUser = nil
            isAuthenticated = false
            onboardingComplete = false
            pairingComplete = false
            isDeleting = false
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            isDeleting = false
        }
    }

    // Converts User model → Firestore dictionary
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

    // Converts Firestore dictionary → User model
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
