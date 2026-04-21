// SafePing  CheckeePairingView.swift
// Shows the 6-igit pairing code for the check in user to share with their checker
// PairingViewModel generates and stores the code in Firestore

import SwiftUI

struct CheckeePairingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Handles generating the code and loading/error state and Firestore sync
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
            
            // Show loading while code is being generated/fetched
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                // Main pairing code display
                Text(viewModel.generatedCode)
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Share system sheet for sending code to checker
                ShareLink(item: "My Safe Ping pairing code is: \(viewModel.generatedCode)") {
                    Label("Share Code", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.teal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                
                // Regenerate a new pairing code if needed
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
            
            // Show error if Firestore or generation fails
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Finish onboarding step and enter app
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
        // Auto generate code when screen appears
        .task {
            await viewModel.generateCode(
                for: authViewModel.currentUser?.username ?? ""
            )
        }
    }
}
