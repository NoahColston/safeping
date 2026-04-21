// SafePing CheckerPairingView.swift
// Onboarding screen where the checker enters the check in users 6 digit code
// PairingViewModel redeems the code and creates the Firestore pairing document

import SwiftUI

struct CheckerPairingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Handles code input state, redemption request, loading, and pairing result
    @StateObject private var viewModel = PairingViewModel()
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.indigo)
            
            VStack(spacing: 8) {
                Text("Enter pairing code")
                    .font(.title2.bold())
                
                Text("Ask the person you're checking on for their 6-digit code.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Success state after pairing is completed
            if viewModel.isPaired {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    
                    Text("Paired with \(viewModel.pairedWithUsername)!")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            } else {
                
                // 6-digit code input field
                TextField("000000", text: $viewModel.enteredCode)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .tracking(8)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .onChange(of: viewModel.enteredCode) { _, new in
                        // Hard limit input to 6 digits
                        if new.count > 6 {
                            viewModel.enteredCode = String(new.prefix(6))
                        }
                    }
                
                // Show Firestore / validation error if pairing fails
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                
                // Submit pairing request
                Button {
                    Task {
                        await viewModel.redeemCode(
                            checkerUsername: authViewModel.currentUser?.username ?? ""
                        )
                    }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Pair with checkee")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.enteredCode.count == 6 ? .indigo : Color(.tertiarySystemBackground))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.enteredCode.count < 6 || viewModel.isLoading)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Either continue after pairing or allow skipping onboarding step
            Button {
                authViewModel.completePairing()
            } label: {
                Text(viewModel.isPaired ? "Continue to app" : "Skip for now")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isPaired ? Color.indigo : Color(.tertiarySystemBackground))
                    .foregroundStyle(viewModel.isPaired ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        // Automatically advance onboarding shortly after successful pairing
        .onChange(of: viewModel.isPaired) { _, paired in
            if paired {
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    authViewModel.completePairing()
                }
            }
        }
    }
}
