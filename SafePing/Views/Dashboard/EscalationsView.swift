// SafePing — EscalationsView.swift
// Lists pairings that have missed check-ins so the checker can take action.
// [Functional] View is a pure function of the CheckInViewModel's escalated pairings.

import SwiftUI

struct EscalationsView: View {
    @ObservedObject var checkInViewModel: CheckInViewModel

    private var escalatedPairings: [(pairing: Pairing, schedules: [CheckInSchedule])] {
        checkInViewModel.pairings.compactMap { p in
            let missed = p.escalatedSchedules()
            return missed.isEmpty ? nil : (p, missed)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if escalatedPairings.isEmpty {
                    allClearState
                        .padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Needs attention")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.safePingTextMuted)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        ForEach(escalatedPairings, id: \.pairing.id) { item in
                            EscalationCard(pairing: item.pairing, missedSchedules: item.schedules)
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

private struct EscalationCard: View {
    let pairing: Pairing
    let missedSchedules: [CheckInSchedule]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.safePingErrorBg)
                        .frame(width: 40, height: 40)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.safePingError)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(pairing.checkInUsername)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.safePingDark)
                    Text(pairing.timeSinceLastCheckIn)
                        .font(.system(size: 12))
                        .foregroundColor(.safePingTextMuted)
                }

                Spacer()

                Text("\(missedSchedules.count) missed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.safePingError)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.safePingErrorBg)
                    .cornerRadius(8)
            }

            Divider()

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
                        Text("Grace period passed")
                            .font(.system(size: 11))
                            .foregroundColor(.safePingTextMuted)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.safePingError.opacity(0.08), radius: 8, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.safePingError.opacity(0.2), lineWidth: 1)
        )
    }
}
