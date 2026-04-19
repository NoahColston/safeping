// SafePing — CheckInLogView.swift
// Chronological history of all check-in events for the selected pairing.
// [Functional] Derives sorted log entries from CheckIn records in the pairing.

import SwiftUI

struct CheckInLogView: View {
    let pairing: Pairing

    private var sortedCheckIns: [CheckIn] {
        pairing.checkIns.sorted { $0.date > $1.date }
    }

    private var groupedCheckIns: [(key: Date, entries: [CheckIn])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sortedCheckIns) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped
            .map { (key: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.key > $1.key }
    }

    var body: some View {
        if sortedCheckIns.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedCheckIns, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sectionHeader(for: group.key))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.safePingTextMuted)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal, 20)

                            VStack(spacing: 1) {
                                ForEach(group.entries) { ci in
                                    LogRow(checkIn: ci, pairing: pairing)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color.safePingBg)
        }
    }

    private func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.safePingTextMuted)
            Text("No check-ins yet")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.safePingDark)
            Text("Your check-in history will appear here.")
                .font(.system(size: 14))
                .foregroundColor(.safePingTextMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LogRow: View {
    let checkIn: CheckIn
    let pairing: Pairing

    private var scheduleName: String {
        guard let scheduleId = checkIn.scheduleId,
              let schedule = pairing.schedules.first(where: { $0.id == scheduleId })
        else { return "Check-in" }
        return schedule.displayMessage
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 34, height: 34)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(scheduleName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.safePingDark)
                Text(timeString)
                    .font(.system(size: 12))
                    .foregroundColor(.safePingTextMuted)
            }

            Spacer()

            HStack(spacing: 4) {
                if checkIn.latitude != nil {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.safePingTextMuted)
                }
                Text(statusLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(statusColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color.white)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: checkIn.date)
    }

    private var statusLabel: String {
        switch checkIn.status {
        case .checkedIn: return "Done"
        case .missed: return "Missed"
        case .pending: return "Pending"
        }
    }

    private var statusColor: Color {
        switch checkIn.status {
        case .checkedIn: return .safePingGreenEnd
        case .missed: return .safePingError
        case .pending: return .safePingTextMuted
        }
    }

    private var iconName: String {
        switch checkIn.status {
        case .checkedIn: return "checkmark.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        case .pending: return "clock.fill"
        }
    }

    private var iconColor: Color {
        switch checkIn.status {
        case .checkedIn: return .safePingGreenEnd
        case .missed: return .safePingError
        case .pending: return .safePingGreenMid
        }
    }

    private var iconBackground: Color {
        switch checkIn.status {
        case .checkedIn: return Color.safePingSuccessBg
        case .missed: return Color.safePingErrorBg
        case .pending: return Color.safePingGreenMid.opacity(0.12)
        }
    }
}
