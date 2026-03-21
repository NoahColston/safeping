import SwiftUI

struct CheckeePairingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = PairingViewModel()
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 60))
                .foregroundStyle(.teal)
            
            VStack(spacing: 8) {
                Text("Your pairing code")
                    .font(.title2.bold())
                
                Text("Share this code with your checker so they can monitor your check-ins.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                // Big code display
                Text(viewModel.generatedCode)
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Share button
                ShareLink(item: "My Safe Ping pairing code is: \(viewModel.generatedCode)") {
                    Label("Share Code", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.teal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                
                // Regenerate
                Button("Generate a new code") {
                    Task {
                        await viewModel.generateCode(
                            for: authViewModel.currentUser?.username ?? ""
                        )
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button {
                authViewModel.completePairing()
            } label: {
                Text("Continue to app")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.teal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .task {
            await viewModel.generateCode(
                for: authViewModel.currentUser?.username ?? ""
            )
        }
    }
}
