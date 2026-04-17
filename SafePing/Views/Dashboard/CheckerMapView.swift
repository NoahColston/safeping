//
//  CheckerMapView.swift
//  SafePing
//


import SwiftUI
import MapKit

struct CheckerMapView: View {
    @ObservedObject var checkInViewModel: CheckInViewModel

    @State private var selectedUserId: UUID?
    @State private var position: MapCameraPosition = .automatic

    private var displayedPairings: [Pairing] {
        checkInViewModel.pairings.filter { $0.isEscalated }
    }

    private var selectedPairing: Pairing? {
        if let id = selectedUserId {
            return displayedPairings.first { $0.id == id }
        }
        return displayedPairings.first
    }

    var body: some View {
        VStack(spacing: 0) {
            if displayedPairings.isEmpty {
                // No one is escalated
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.safePingGreenMid)

                    Text("Everyone is on track")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.safePingDark)

                    Text("Location data will appear here when a check-in user misses their window.")
                        .font(.system(size: 14))
                        .foregroundColor(.safePingTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // User pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayedPairings) { pairing in
                            UserTab(
                                name: pairing.checkInUsername,
                                isSelected: pairing.id == (selectedUserId ?? displayedPairings.first?.id)
                            ) {
                                selectedUserId = pairing.id
                                if let loc = pairing.lastKnownLocation {
                                    withAnimation {
                                        position = .region(MKCoordinateRegion(
                                            center: CLLocationCoordinate2D(
                                                latitude: loc.latitude,
                                                longitude: loc.longitude
                                            ),
                                            span: MKCoordinateSpan(
                                                latitudeDelta: 0.01,
                                                longitudeDelta: 0.01
                                            )
                                        ))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }

                // Map
                if let pairing = selectedPairing, let loc = pairing.lastKnownLocation {
                    Map(position: $position) {
                        Annotation(pairing.checkInUsername, coordinate: CLLocationCoordinate2D(
                            latitude: loc.latitude, longitude: loc.longitude
                        )) {
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.safePingError)
                                Circle()
                                    .fill(Color.safePingError.opacity(0.3))
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                    .onAppear {
                        position = .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: loc.latitude,
                                longitude: loc.longitude
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }

                    // Info bar
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(pairing.checkInUsername) — missed check-in")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.safePingError)
                        Text("Last known location from most recent check-in")
                            .font(.system(size: 12))
                            .foregroundColor(.safePingTextMuted)
                        Text(pairing.timeSinceLastCheckIn)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.safePingDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                } else if selectedPairing != nil {
                    // Escalated but no location data
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.safePingTextMuted)
                        Text("No location data available")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.safePingDark)
                        Text("This user's previous check-ins did not include location.")
                            .font(.system(size: 13))
                            .foregroundColor(.safePingTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                }
            }
        }
        .background(Color.safePingBg)
    }
}
