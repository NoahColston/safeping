// SafePing  CryptoUtils.swift

// Provides helper functions for cryptographic operations
// Used to hash passwords consistently across the app
//
import Foundation
import CryptoKit

// CryptoUtils
// Utility container for cryptographic functions.
//
enum CryptoUtils {

    // hashPassword
    // Converts a password into a SHA-256 hashed string.
    //
    // Parameters:
    // - password: plain text password
    //
    // Returns:
    // - hashed password as a hex string
    //
    static func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)

        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
