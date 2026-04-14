import SwiftUI

struct CheckInSettingsView: View {
    @ObservedObject var viewModel: CheckInViewModel
    @State private var draftMessage: String = ""
    @State private var messageSaved: Bool = false

    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Check-In Settings")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.safePingDark)

            HStack(spacing: 12) {
                // Time picker
                if let index = viewModel.selectedPairingIndex {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                guard index < viewModel.pairings.count else { return Date() }
                                return viewModel.pairings[index].schedule.time
                            },
                            set: { viewModel.updateScheduleTime($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.safePingBg)
                    .cornerRadius(10)
                }

                // Frequency picker
                if let index = viewModel.selectedPairingIndex {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Frequency")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.safePingGreenEnd)
                            .textCase(.uppercase)
                            .tracking(0.4)

                        Picker("", selection: Binding(
                            get: {
                                guard index < viewModel.pairings.count else { return CheckInFrequency.daily }
                                return viewModel.pairings[index].schedule.frequency
                            },
                            set: { viewModel.updateScheduleFrequency($0) }
                        )) {
                            ForEach(CheckInFrequency.allCases, id: \.self) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .labelsHidden()
                        .tint(.safePingDark)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.safePingBg)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.safePingGreenEnd, lineWidth: 1.5)
                    )
                }

                Spacer()
            }

            // Day-of-week selector (shown only for weekly)
            if let pairing = viewModel.selectedPairing, pairing.schedule.frequency == .weekly {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Days")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.safePingTextMuted)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { weekday in
                            let isActive = pairing.schedule.activeDays.contains(weekday)
                            Button(action: {
                                viewModel.toggleScheduleDay(weekday)
                            }) {
                                Text(dayLabels[weekday - 1])
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isActive ? .white : .safePingTextMuted)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        isActive
                                        ? AnyShapeStyle(LinearGradient(colors: [.safePingGreenStart, .safePingGreenEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(Color.safePingBg)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Story 14: Checker sets a custom reminder message for the check-in user
            VStack(alignment: .leading, spacing: 8) {
                Text("Reminder Message")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.safePingTextMuted)
                    .textCase(.uppercase)
                    .tracking(0.4)

                TextField("e.g. Hey, time to check in!", text: $draftMessage)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.safePingBg)
                    .cornerRadius(10)

                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            await viewModel.updateReminderMessage(draftMessage)
                            withAnimation { messageSaved = true }
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            withAnimation { messageSaved = false }
                        }
                    }) {
                        Text(messageSaved ? "Saved!" : "Save Message")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(messageSaved ? .safePingGreenEnd : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(messageSaved ? Color.safePingSuccessBg : Color.safePingDark)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPairing?.schedule.frequency)
        .onAppear {
            draftMessage = viewModel.selectedPairing?.customReminderMessage ?? ""
        }
        .onChange(of: viewModel.selectedPairingId) { _, _ in
            draftMessage = viewModel.selectedPairing?.customReminderMessage ?? ""
        }
        .onChange(of: viewModel.selectedPairing?.customReminderMessage) { _, newValue in
            if let newValue, draftMessage.isEmpty {
                draftMessage = newValue
            }
        }
    }
}

#Preview {
    let vm = CheckInViewModel()
    vm.pairings = [
        Pairing(checkerUsername: "me", checkInUsername: "John", schedule: CheckInSchedule(frequency: .weekly, activeDays: [2, 4, 6]))
    ]
    return CheckInSettingsView(viewModel: vm)
        .padding()
        .background(Color.safePingBg)
}
