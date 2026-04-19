// SafePing — BrandHeader.swift
// Shared logo + tagline header shown on auth screens.

import SwiftUI

struct BrandHeader: View {
    var showTagline: Bool = true

    var body: some View {
        VStack(spacing: 10) {
            // App icon
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

            // Wordmark
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
