// SafePing  CheckeeLocationView.swift
// Displays the check in users most recent known location on a map for the checker

import SwiftUI
import MapKit

struct CheckeeLocationView: View {
    let pairing: Pairing

    @State private var position: MapCameraPosition = .automatic

    private var lastCheckIn: CheckIn? {
        pairing.checkIns
            .filter { $0.latitude != nil && $0.longitude != nil }
            .sorted { $0.date > $1.date }
            .first
    }

    var body: some View {
        if let ci = lastCheckIn, let lat = ci.latitude, let lon = ci.longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            VStack(spacing: 0) {
                Map(position: $position) {
                    Annotation("", coordinate: coord) {
                        pinView(for: ci)
                    }
                }
                .frame(maxHeight: .infinity)
                .onAppear {
                    position = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }

                detailBar(for: ci)
            }
        } else {
            emptyState
        }
    }

    private func pinView(for ci: CheckIn) -> some View {
        ZStack {
            Circle()
                .fill(ci.status == .checkedIn ? Color.safePingGreenMid : Color.safePingError)
                .frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 18, height: 18)
        }
    }

    private func detailBar(for ci: CheckIn) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ci.status == .checkedIn ? Color.safePingSuccessBg : Color.safePingErrorBg)
                    .frame(width: 40, height: 40)
                Image(systemName: ci.status == .checkedIn ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ci.status == .checkedIn ? .safePingGreenEnd : .safePingError)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ci.status == .checkedIn ? "Last check-in" : "Last missed")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.safePingDark)
                Text(formattedDate(ci.date))
                    .font(.system(size: 12))
                    .foregroundColor(.safePingTextMuted)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, y: -2)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.safePingTextMuted)
            Text("No location yet")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.safePingDark)
            Text("Check-in locations will appear here once location access is enabled and a check-in is recorded.")
                .font(.system(size: 14))
                .foregroundColor(.safePingTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        return formatter.string(from: date)
    }
}
