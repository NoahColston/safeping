// SafePing — CryptoUtils.swift
// Shared cryptographic helpers. Centralizes password hashing so both
// AuthViewModel and SeedService produce identical digests.

import Foundation
import CryptoKit

// [OOP] Namespace enum — groups related utility functions without instantiation
enum CryptoUtils {

    // [Procedural] Utility: one-way SHA-256 digest used for password storage
    static func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        // [Functional] compactMap transforms each byte into a hex string
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
