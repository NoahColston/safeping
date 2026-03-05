import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if !authViewModel.isAuthenticated {
                NavigationStack {
                    LoginView()
                }
            } else if authViewModel.needsOnboarding {
                RoleSelectionView()
            } else {
                HomeView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.needsOnboarding)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
