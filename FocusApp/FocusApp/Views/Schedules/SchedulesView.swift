import SwiftUI

struct ScheduleEditTarget: Identifiable {
    var schedule: FocusSchedule
    var isNew: Bool
    var id: UUID { schedule.id }
}

struct SchedulesView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: ScheduleEditTarget?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    ScreenHeader("Schedules", subtitle: "Recurring focus, on autopilot") {
                        addMenu
                    }
                    .padding(.bottom, DS.Space.s)

                    if model.schedules.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.schedules) { schedule in
                            ScheduleCard(schedule: schedule, now: context.date) {
                                editing = ScheduleEditTarget(schedule: schedule, isNew: false)
                            }
                        }
                    }

                    if !model.screenTime.isAuthorized {
                        Text("Without Screen Time, schedules start a Strict Focus Lock when you open the app, and you'll get a reminder when each one begins.")
                            .font(DS.Typography.footnote)
                            .foregroundStyle(DS.Palette.tertiary)
                            .padding(.horizontal, 4)
                            .padding(.top, DS.Space.s)
                    }
                }
                .padding(.horizontal, DS.Space.gutter)
                .padding(.bottom, DS.Space.xl)
            }
            .scrollIndicators(.hidden)
            .background(DS.Palette.background.ignoresSafeArea())
        }
        .sheet(item: $editing) { target in
            ScheduleEditorView(schedule: target.schedule, isNew: target.isNew)
        }
    }

    private var addMenu: some View {
        Menu {
            Button {
                editing = ScheduleEditTarget(schedule: blankSchedule, isNew: true)
            } label: {
                Label("Blank schedule", systemImage: "plus")
            }
            Section("Presets") {
                ForEach(FocusSchedule.presets) { preset in
                    Button("\(preset.name) · \(preset.timeLabel)") {
                        editing = ScheduleEditTarget(schedule: preset, isNew: true)
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.Palette.text)
                .frame(width: DS.Size.touch - 8, height: DS.Size.touch - 8)
                .background(DS.Palette.raised, in: Circle())
        }
    }

    private var blankSchedule: FocusSchedule {
        FocusSchedule(name: "", start: .init(hour: 9, minute: 0), end: .init(hour: 11, minute: 0),
                      days: Weekday.workdays)
    }

    private var emptyState: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text("No schedules yet")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Palette.text)
                Text("Start from a preset, then adjust times, apps and Hard Mode.")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Palette.secondary)
                VStack(spacing: DS.Space.s) {
                    ForEach(FocusSchedule.presets) { preset in
                        Button {
                            editing = ScheduleEditTarget(schedule: preset, isNew: true)
                        } label: {
                            HStack {
                                Text(preset.name).foregroundStyle(DS.Palette.text)
                                Spacer()
                                Text(preset.timeLabel)
                                    .font(DS.Typography.footnote.monospacedDigit())
                                    .foregroundStyle(DS.Palette.secondary)
                            }
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Card

private struct ScheduleCard: View {
    @Environment(AppModel.self) private var model
    let schedule: FocusSchedule
    let now: Date
    let onEdit: () -> Void

    var body: some View {
        let window = schedule.activeWindow(at: now)
        let locked = schedule.hardMode && window != nil

        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(schedule.name)
                                .font(DS.Typography.headline)
                                .foregroundStyle(DS.Palette.text)
                                .lineLimit(1)
                            if window != nil {
                                Circle().fill(DS.Palette.accent).frame(width: 7, height: 7)
                            }
                        }
                        Text(schedule.timeLabel)
                            .font(DS.Typography.subheadline.monospacedDigit())
                            .foregroundStyle(DS.Palette.secondary)
                    }
                    Spacer()
                    Toggle("Enabled", isOn: Binding(
                        get: { schedule.isEnabled },
                        set: { model.setEnabled(schedule, $0) }
                    ))
                    .labelsHidden()
                    .tint(DS.Palette.accent)
                    .disabled(locked)
                }

                HStack(spacing: 6) {
                    ForEach(Weekday.displayOrder) { day in
                        let on = schedule.days.contains(day)
                        Text(day.initial)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(on ? Color.black : DS.Palette.tertiary)
                            .frame(width: 28, height: 28)
                            .background(on ? DS.Palette.text : DS.Palette.raised, in: Circle())
                    }
                }

                if schedule.hardMode || schedule.timeLimit != .off {
                    HStack(spacing: 6) {
                        if schedule.hardMode { Badge(text: "Hard Mode", systemImage: "lock.fill") }
                        if schedule.timeLimit != .off {
                            Badge(text: "\(schedule.timeLimit.label) allowance", systemImage: "hourglass")
                        }
                    }
                }

                if locked, let window {
                    Label("Locked until \(TimeFormat.clock(window.upperBound))", systemImage: "lock.fill")
                        .font(DS.Typography.footnote.weight(.medium))
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        }
        .opacity(schedule.isEnabled ? 1 : 0.55)
        .contentShape(Rectangle())
        .onTapGesture { if !locked { onEdit() } }
    }
}
