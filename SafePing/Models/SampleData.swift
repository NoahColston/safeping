// SafePing — SampleData.swift
// Defines the 8 hardcoded demo users (4 checkers + 4 check-in users) used
// for seeding Firestore and populating SwiftUI previews.

import Foundation

// [OOP] Namespace enum groups related sample-data constants
enum SampleData {

    // Default password for all sample accounts (stored as SHA-256 hash via CryptoUtils)
    static let samplePassword = "SafePing1"

    // [Functional] map produces User structs from raw tuples
    static let checkers: [User] = [
        ("alice_checker", UserRole.checker),
        ("bob_checker",   UserRole.checker),
        ("carol_checker", UserRole.checker),
        ("dave_checker",  UserRole.checker)
    ].map { username, role in
        User(username: username, password: CryptoUtils.hashPassword(samplePassword), role: role)
    }

    // [Functional] same pattern for check-in users
    static let checkInUsers: [User] = [
        ("emma_user",  UserRole.checkInUser),
        ("frank_user", UserRole.checkInUser),
        ("grace_user", UserRole.checkInUser),
        ("henry_user", UserRole.checkInUser)
    ].map { username, role in
        User(username: username, password: CryptoUtils.hashPassword(samplePassword), role: role)
    }

    // All 8 users combined
    static var all: [User] { checkers + checkInUsers }
}
