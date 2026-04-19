// SafePing — SeedService.swift
// Writes SampleData users to Firestore. Call once from Settings (debug builds).
// Safe to call multiple times — uses setData(merge: false) which overwrites.

import Foundation
import FirebaseFirestore

// [OOP] Class with Firestore dependency injected at init
@MainActor
class SeedService: ObservableObject {
    @Published var isSeeding = false
    @Published var seedMessage: String?

    private let db = Firestore.firestore()

    // [Procedural] Iterates sample users and writes each to Firestore
    func seedSampleUsers() async {
        isSeeding = true
        seedMessage = nil

        do {
            // [Functional] forEach applies the write closure to each user
            for user in SampleData.all {
                let data: [String: Any] = [
                    "id": user.id.uuidString,
                    "username": user.username,
                    "password": user.password,
                    "role": user.role?.rawValue ?? ""
                ]
                try await db.collection("users")
                    .document(user.username)
                    .setData(data)
            }
            seedMessage = "Seeded \(SampleData.all.count) sample users successfully."
        } catch {
            seedMessage = "Seed failed: \(error.localizedDescription)"
        }

        isSeeding = false
    }
}
