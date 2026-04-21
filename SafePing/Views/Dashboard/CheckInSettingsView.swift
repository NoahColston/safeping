// SafePing  CheckInSettingsView.swift
// Lets the checker configure schedules

// Each schedule controls when reminders fire and how check ins are evaluated
// [OOP] Mutations are delegated to CheckInViewModel which writes back to Firestore

import SwiftUI

struct CheckInSettingsView: View {
    // Binds to shared CheckInViewModel which is the single source of truth
    @ObservedObject var viewModel: CheckInViewModel
    
    // Tracks which schedule row is currently expanded for editing
    @State private var expandedScheduleId: UUID?
    
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header section with title and add-schedule action
            HStack {
                Text("Check-In Settings")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.safePingDark)
                
                Spacer()
                
                // Adds a new schedule to the current pairing
                Button(action: addSchedule) {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [.safePingGreenStart, .safePingGreenEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                }
            }
            
            // Main schedule list
            if let pairing = viewModel.selectedPairing {
                
                // Empty state when no schedules exist yet
                if pairing.schedules.isEmpty {
                    Text("No check-ins scheduled yet.")
                        .font(.system(size: 14))
                        .foregroundColor(.safePingTextMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    
                    // List of all schedules for this pairing
                    VStack(spacing: 10) {
                        ForEach(pairing.schedules) { schedule in
                            ScheduleRow(
                                schedule: schedule,
                                isExpanded: expandedScheduleId == schedule.id,
                                canDelete: pairing.schedules.count > 1,
                                
                                // Expand/collapse schedule editor
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        expandedScheduleId =
                                        (expandedScheduleId == schedule.id) ? nil : schedule.id
                                    }
                                },
                                
                                // Delete schedule
                                onDelete: {
                                    viewModel.removeSchedule(schedule.id)
                                    if expandedScheduleId == schedule.id {
                                        expandedScheduleId = nil
                                    }
                                },
                                
                                // Live update message stored in Firestore
                                onMessageChange: { newMessage in
                                    viewModel.updateScheduleMessage(newMessage, scheduleId: schedule.id)
                                },
                                
                                // Update scheduled time
                                onTimeChange: { newTime in
                                    viewModel.updateScheduleTime(newTime, scheduleId: schedule.id)
                                },
                                
                                // Change frequency
                                onFrequencyChange: { newFreq in
                                    viewModel.updateScheduleFrequency(newFreq, scheduleId: schedule.id)
                                },
                                
                                // Toggle active weekday for weekly schedules
                                onToggleDay: { weekday in
                                    viewModel.toggleScheduleDay(weekday, scheduleId: schedule.id)
                                },
                                
                                // Adjust grace period before escalation triggers
                                onGracePeriodChange: { minutes in
                                    viewModel.updateGracePeriod(minutes, scheduleId: schedule.id)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        
        // Reset expanded row when switching between pairings
        .onChange(of: viewModel.selectedPairingId) { _, _ in
            expandedScheduleId = nil
        }
    }
    
    // Creates a new default schedule and auto expands it in UI
    private func addSchedule() {
        viewModel.addSchedule()
        if let newId = viewModel.selectedPairing?.schedules.last?.id {
            withAnimation(.easeInOut(duration: 0.22)) {
                expandedScheduleId = newId
            }
        }
    }
}

// Each row represents one independent check in schedule configuration
private struct ScheduleRow: View {
    
    // Core schedule data model
    let schedule: CheckInSchedule
    
    // UI state (expanded/collapsed)
    let isExpanded: Bool
    
    // Controls whether delete button is shown
    let canDelete: Bool
    
    // User interactions
    let onTap: () -> Void
    let onDelete: () -> Void
    let onMessageChange: (String) -> Void
    let onTimeChange: (Date) -> Void
    let onFrequencyChange: (CheckInFrequency) -> Void
    let onToggleDay: (Int) -> Void
    let onGracePeriodChange: (Int) -> Void

    // Local draft state for smoother text editing
    @State private var draftMessage: String = ""

    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Collapsed header (always visible)
            Button(action: onTap) {
                HStack(spacing: 12) {
                    
                    // Icon representing schedule type
                    ZStack {
                        Circle()
                            .fill(Color.safePingGreenMid.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.safePingGreenMid)
                    }

                    // Summary text
                    VStack(alignment: .leading, spacing: 2) {
                        Text(schedule.displayMessage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.safePingDark)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.safePingTextMuted)
                    }

                    Spacer()

                    // Expanded indicator / completion badge
                    if isExpanded {
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient(
                                    colors: [.safePingGreenStart, .safePingGreenEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.safePingTextMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            // Expanded editor section
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    
                    // Editable message sent in notifications
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Label / Notification Message")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.safePingTextMuted)
                            .textCase(.uppercase)
                            .tracking(0.4)

                        TextField("e.g. Morning meds, Time for your walk", text: $draftMessage)
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.safePingBg)
                            .foregroundColor(.safePingTextMuted)
                            .cornerRadius(10)
                            .onChange(of: draftMessage) { _, newValue in
                                onMessageChange(newValue)
                            }
                    }

                    // Time and frequency configuration row
                    HStack(spacing: 10) {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { schedule.time },
                                set: { onTimeChange($0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.safePingBg)
                        .cornerRadius(10)

                        Picker(
                            "",
                            selection: Binding(
                                get: { schedule.frequency },
                                set: { onFrequencyChange($0) }
                            )
                        ) {
                            ForEach(CheckInFrequency.allCases, id: \.self) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .labelsHidden()
                        .tint(.safePingDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.safePingBg)
                        .cornerRadius(10)

                        Spacer()
                    }

                    // Weekly schedule day selector
                    if schedule.frequency == .weekly {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active Days")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.safePingTextMuted)
                                .textCase(.uppercase)
                                .tracking(0.4)

                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { weekday in
                                    let isActive = schedule.activeDays.contains(weekday)
                                    Button(action: { onToggleDay(weekday) }) {
                                        Text(dayLabels[weekday - 1])
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(isActive ? .white : .safePingTextMuted)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                isActive
                                                ? AnyShapeStyle(LinearGradient(
                                                    colors: [.safePingGreenStart, .safePingGreenEnd],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ))
                                                : AnyShapeStyle(Color.safePingBg)
                                            )
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Grace period controls before escalation triggers
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert Delay")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.safePingTextMuted)
                            .textCase(.uppercase)
                            .tracking(0.4)

                        HStack(spacing: 12) {
                            Text("\(schedule.gracePeriodMinutes) min")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.safePingDark)
                                .frame(width: 60)

                            Stepper(
                                "",
                                value: Binding(
                                    get: { schedule.gracePeriodMinutes },
                                    set: { onGracePeriodChange($0) }
                                ),
                                in: 5...120,
                                step: 5
                            )
                            .labelsHidden()
                        }

                        Text("You will be alerted if they don't check-in within \(schedule.gracePeriodMinutes) min of scheduled time.")
                            .font(.system(size: 11))
                            .foregroundColor(.safePingTextMuted)
                    }

                    // Delete schedule action
                    if canDelete {
                        HStack {
                            Spacer()
                            Button(action: onDelete) {
                                Label("Delete", systemImage: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.safePingError)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.safePingErrorBg)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color.safePingBg.opacity(0.4))
        .cornerRadius(12)
        
        // Initialize editable message when row appears
        .onAppear {
            draftMessage = schedule.message
        }
    }

    // Human readable summary shown in collapsed state
    private var subtitle: String {
        let timeStr = schedule.formattedTime
        if schedule.frequency == .daily {
            return "Every day at \(timeStr)"
        } else {
            let days = schedule.activeDays.sorted().map { dayLabels[$0 - 1] }.joined(separator: " · ")
            return "\(days) at \(timeStr)"
        }
    }
}
