// SafePing  EscalationsView.swift
// Lists pairings that have missed check-ins so the checker can take action
//

// This view is a pure projection of CheckInViewModel state:
// any pairing with overdue/missed schedules is surfaced here.
//

import SwiftUI

struct EscalationsView: View {

    // Source of truth for all pairings and check in state
    @ObservedObject var checkInViewModel: CheckInViewModel

    // We flatten only pairings that currently have missed schedules
    private var escalatedPairings: [(pairing: Pairing, schedules: [CheckInSchedule])] {
        checkInViewModel.pairings.compactMap { p in
            let missed = p.escalatedSchedules()
            return missed.isEmpty ? nil : (p, missed)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // EMPTY STATE (NO ESCALATIONS)
                if escalatedPairings.isEmpty {
                    allClearState
                        .padding(.top, 60)
                } else {

                    // ESCALATION SECTION HEADER
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Needs attention")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.safePingTextMuted)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // ESCALATION CARDS (ONE PER PAIRING)
                        ForEach(escalatedPairings, id: \.pairing.id) { item in
                            EscalationCard(
                                pairing: item.pairing,
                                missedSchedules: item.schedules
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.safePingBg)
    }

    private var allClearState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.safePingGreenMid)

            Text("All clear")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.safePingDark)

            Text("No one has missed their check-in window.")
                .font(.system(size: 14))
                .foregroundColor(.safePingTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

// Displays:
// - who is affected
// - how overdue they are
// - which schedules were missed
private struct EscalationCard: View {

    let pairing: Pairing
    let missedSchedules: [CheckInSchedule]

    // Computes how long since the earliest missed escalation deadline
    private var timeSinceMissed: String {
        let now = Date()

        // Convert each schedule into its escalation deadline time
        let deadlines = missedSchedules.compactMap { $0.escalationTime(for: now) }

        guard let earliest = deadlines.min() else { return "" }

        let interval = now.timeIntervalSince(earliest)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        // overdue formatting
        if hours >= 24 {
            let days = hours / 24
            return "Overdue by \(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "Overdue by \(hours) hr\(hours == 1 ? "" : "s") \(minutes) min"
        } else {
            return "Overdue by \(minutes) min"
        }
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            // HEADER ROW
            HStack(spacing: 10) {

                // Warning icon container
                ZStack {
                    Circle()
                        .fill(Color.safePingErrorBg)
                        .frame(width: 40, height: 40)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.safePingError)
                }

                // User and urgency info
                VStack(alignment: .leading, spacing: 2) {
                    Text(pairing.checkInUsername)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.safePingDark)

                    Text(timeSinceMissed)
                        .font(.system(size: 12))
                        .foregroundColor(.safePingError.opacity(0.8))
                }

                Spacer()

                // Count badge
                Text("\(missedSchedules.count) missed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.safePingError)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.safePingErrorBg)
                    .cornerRadius(8)
            }

            Divider()

            // MISSED SCHEDULE LIST
            VStack(spacing: 6) {
                ForEach(missedSchedules) { schedule in
                    HStack {

                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.safePingError.opacity(0.7))

                        Text(schedule.displayMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.safePingDark)

                        Spacer()

                        Text("due \(schedule.formattedTime)")
                            .font(.system(size: 11))
                            .foregroundColor(.safePingTextMuted)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)

        // subtle red tint shadow to reinforce urgency
        .shadow(color: Color.safePingError.opacity(0.08), radius: 8, y: 2)

        // visual escalation border
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.safePingError.opacity(0.2), lineWidth: 1)
        )
    }
}
