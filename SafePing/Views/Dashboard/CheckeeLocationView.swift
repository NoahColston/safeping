import SwiftUI
import MapKit

struct CheckeeLocationView: View {
    let pairing: Pairing

    @State private var selectedCheckIn: CheckIn?
    @State private var position: MapCameraPosition = .automatic

    private var locationCheckIns: [CheckIn] {
        pairing.checkIns
            .filter { $0.latitude != nil && $0.longitude != nil }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        if locationCheckIns.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                Map(position: $position) {
                    ForEach(locationCheckIns) { ci in
                        if let lat = ci.latitude, let lon = ci.longitude {
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                                pinView(for: ci)
                                    .onTapGesture {
                                        withAnimation { selectedCheckIn = ci }
                                    }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                if let ci = selectedCheckIn ?? locationCheckIns.first {
                    detailBar(for: ci)
                }
            }
            .onAppear {
                if let ci = locationCheckIns.first,
                   let lat = ci.latitude, let lon = ci.longitude {
                    position = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
        }
    }

    @ViewBuilder
    private func pinView(for ci: CheckIn) -> some View {
        let isSelected = selectedCheckIn?.id == ci.id
        ZStack {
            Circle()
                .fill(ci.status == .checkedIn ? Color.safePingGreenMid : Color.safePingError)
                .frame(width: isSelected ? 18 : 12, height: isSelected ? 18 : 12)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            if isSelected {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 18, height: 18)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
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
                Text(ci.status == .checkedIn ? "Checked in" : "Missed")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.safePingDark)
                Text(formattedDate(ci.date))
                    .font(.system(size: 12))
                    .foregroundColor(.safePingTextMuted)
            }

            Spacer()

            Text("\(locationCheckIns.count) pinned")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.safePingTextMuted)
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
            Text("No location history")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.safePingDark)
            Text("Your check-in locations will appear here once you allow location access and check in.")
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
