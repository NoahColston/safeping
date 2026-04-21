// SafePing Theme.swift
// Centralizes app styling: colors, reusable gradient, text field, and button components

import SwiftUI

extension Color {
    // Primary brand green gradient
    static let safePingGreenStart = Color(red: 107/255, green: 212/255, blue: 37/255)
    static let safePingGreenEnd   = Color(red: 61/255,  green: 166/255, blue: 0/255)
    static let safePingGreenMid   = Color(red: 82/255,  green: 185/255, blue: 21/255)

    // Primary dark text color
    static let safePingDark       = Color(red: 26/255,  green: 26/255,  blue: 26/255)

    // Background and UI system colors
    static let safePingBg         = Color(red: 247/255, green: 248/255, blue: 246/255)
    static let safePingTextMuted  = Color(red: 113/255, green: 117/255, blue: 110/255)
    static let safePingBorder     = Color(red: 224/255, green: 226/255, blue: 220/255)

    // Error + success states
    static let safePingError      = Color(red: 214/255, green: 57/255,  blue: 43/255)
    static let safePingErrorBg    = Color(red: 254/255, green: 240/255, blue: 238/255)
    static let safePingSuccessBg  = Color(red: 234/255, green: 250/255, blue: 222/255)
}

// Reusable brand gradient component
struct SafePingGradient: View {
    var body: some View {
        LinearGradient(
            colors: [.safePingGreenStart, .safePingGreenEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// Reusable styled text field with optional password toggle
struct SafePingTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var errorMessage: String? = nil

    @FocusState private var isFocused: Bool
    @State private var showPassword = false

    // Switches between SecureField and TextField based on visibility state
    @ViewBuilder private var fieldInput: some View {
        if isSecure && !showPassword {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Field label
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.safePingTextMuted)
                .tracking(0.5)

            // Input field container
            fieldInput
                .padding(14)
                .padding(.trailing, isSecure ? 44 : 0)
                .background(Color.safePingBg)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            errorMessage != nil ? Color.safePingError :
                            isFocused ? Color.safePingGreenMid : Color.safePingBorder,
                            lineWidth: 1.5
                        )
                )
                .focused($isFocused)

                // Eye toggle for secure fields
                .overlay(alignment: .trailing) {
                    if isSecure {
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.system(size: 16))
                                .foregroundColor(.safePingTextMuted)
                        }
                        .padding(.trailing, 14)
                    }
                }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.safePingError)
            }
        }
    }
}

// Primary call to action button with gradient styling
struct SafePingButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: { if !isLoading { action() } }) {

            // Switches between text and spinner
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50) // keeps layout stable during loading
            .background(SafePingGradient())
            .cornerRadius(10)
            .shadow(
                color: .safePingGreenEnd.opacity(isLoading ? 0.1 : 0.25),
                radius: 6,
                y: 3
            )
            .opacity(isLoading ? 0.8 : 1.0)
        }
        .disabled(isLoading)
    }
}
