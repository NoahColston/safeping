import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            BrandHeader(showTagline: false)

            // Card
            VStack(spacing: 20) {
                Text("Welcome, \(authViewModel.currentUser?.username ?? "User")!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.safePingDark)

                Text("You're all set. Your SafePing dashboard is coming soon.")
                    .font(.system(size: 15))
                    .foregroundColor(.safePingTextMuted)
                    .multilineTextAlignment(.center)

                Button(action: { authViewModel.logout() }) {
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.safePingGreenEnd)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.safePingGreenEnd, lineWidth: 2)
                        )
                }
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 16, y: 4)
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.safePingBg.ignoresSafeArea())
    }
}

#Preview {
    let vm = AuthViewModel()
    vm.currentUser = User(username: "testuser", password: "")
    vm.isAuthenticated = true
    return HomeView().environmentObject(vm)
}
