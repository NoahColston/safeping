// SafePing BrandHeader.swift
// Shared logo and wordmark header used across onboarding and auth screens

import SwiftUI

struct BrandHeader: View {
    // Controls whether tagline is shown below the logo
    var showTagline: Bool = true

    var body: some View {
        VStack(spacing: 10) {
            
            // App icon display
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

            // App wordmark with gradient accent on "Ping"
            HStack(spacing: 0) {
                Text("Safe")
                    .foregroundColor(.safePingDark)
                
                Text("Ping")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.safePingGreenStart, .safePingGreenEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .font(.system(size: 28, weight: .heavy, design: .rounded))

            // Optional tagline shown on onboarding/auth screens
            if showTagline {
                Text("Stay connected. Stay safe.")
                    .font(.system(size: 14))
                    .foregroundColor(.safePingTextMuted)
            }
        }
    }
}

#Preview {
    BrandHeader()
}
