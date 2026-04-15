import SwiftUI

struct CheckInCalendarView: View {
    let pairing: Pairing
    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let daySymbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        VStack(spacing: 16) {
            // Month/year navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.safePingDark)
                        .frame(width: 32, height: 32)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(monthString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.safePingDark)

                    Text(yearString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.safePingTextMuted)
                }

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.safePingDark)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 4)

            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(daySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.safePingTextMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            status: pairing.status(for: date),
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                        )
                    } else {
                        Text("")
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Helpers
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: displayedMonth)
    }

    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: displayedMonth)
    }

    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        }
    }

    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmpty = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        // Trailing days to fill the grid
        let remaining = (7 - (days.count % 7)) % 7
        if remaining > 0, let lastNonNil = days.compactMap({ $0 }).last {
            for offset in 1...remaining {
                if let date = calendar.date(byAdding: .day, value: offset, to: lastNonNil) {
                    days.append(date)
                }
            }
        }

        return days
    }
}

// MARK: - Individual Day Cell
struct DayCell: View {
    let date: Date
    let status: CheckInStatus?
    let isToday: Bool
    let isCurrentMonth: Bool

    private let calendar = Calendar.current

    var body: some View {
        let dayNumber = calendar.component(.day, from: date)
        let isFuture = date > Date() && !isToday

        ZStack {
            // Background circle for status
            if let status = status, !isFuture {
                Circle()
                    .fill(backgroundColor(for: status))
                    .frame(width: 34, height: 34)
            } else if isToday {
                Circle()
                    .stroke(Color.safePingGreenMid, lineWidth: 2)
                    .frame(width: 34, height: 34)
            }

            Text("\(dayNumber)")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(textColor(isFuture: isFuture))
        }
        .frame(height: 36)
        .opacity(isCurrentMonth ? 1.0 : 0.35)
    }

    private func backgroundColor(for status: CheckInStatus) -> Color {
        switch status {
        case .checkedIn: return .safePingGreenMid.opacity(0.85)
        case .missed: return .safePingError.opacity(0.85)
        case .pending: return .safePingBorder.opacity(0.5)
        }
    }

    private func textColor(isFuture: Bool) -> Color {
        if isFuture { return .safePingTextMuted.opacity(0.5) }
        if let status = status {
            switch status {
            case .checkedIn, .missed: return .white
            case .pending: return .safePingDark
            }
        }
        return isCurrentMonth ? .safePingDark : .safePingTextMuted
    }
}

#Preview {
    let calendar = Calendar.current
    let pairingId = UUID()
    let scheduleId = UUID()
    let pairing = Pairing(
        id: pairingId,
        checkerUsername: "checker",
        checkInUsername: "John",
        schedules: [CheckInSchedule(id: scheduleId)],
        checkIns: [
            CheckIn(pairingId: pairingId, scheduleId: scheduleId,
                    date: calendar.date(byAdding: .day, value: -1, to: Date())!, status: .checkedIn),
            CheckIn(pairingId: pairingId, scheduleId: scheduleId,
                    date: calendar.date(byAdding: .day, value: -2, to: Date())!, status: .checkedIn),
            CheckIn(pairingId: pairingId, scheduleId: scheduleId,
                    date: calendar.date(byAdding: .day, value: -3, to: Date())!, status: .missed),
        ]
    )
    CheckInCalendarView(pairing: pairing)
        .padding()
        .background(Color.safePingBg)
}
