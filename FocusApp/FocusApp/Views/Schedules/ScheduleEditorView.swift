import FamilyControls
import SwiftUI

struct ScheduleEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    @State private var draft: FocusSchedule
    @State private var selection: FamilyActivitySelection
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var showPicker = false
    @State private var confirmDelete = false

    init(schedule: FocusSchedule, isNew: Bool) {
        self.isNew = isNew
        _draft = State(initialValue: schedule)
        _selection = State(initialValue: ShieldController.decode(schedule.selectionData) ?? FamilyActivitySelection())
        _startTime = State(initialValue: schedule.start.date(on: Date()))
        _endTime = State(initialValue: schedule.end.date(on: Date()))
    }

    private var duration: Int {
        var copy = draft
        copy.start = TimeOfDay(date: startTime)
        copy.end = TimeOfDay(date: endTime)
        return copy.durationMinutes
    }

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && !draft.days.isEmpty && duration >= 15
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    nameSection
                    timeSection
                    daysSection
                    blockingSection
                    if !isNew {
                        Button("Delete schedule") { confirmDelete = true }
                            .buttonStyle(SecondaryButtonStyle(foreground: DS.Palette.danger))
                    }
                }
                .padding(.horizontal, DS.Space.gutter)
                .padding(.vertical, DS.Space.m)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(DS.Palette.background.ignoresSafeArea())
            .navigationTitle(isNew ? "New schedule" : "Edit schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DS.Palette.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .foregroundStyle(isValid ? DS.Palette.text : DS.Palette.tertiary)
                        .disabled(!isValid)
                }
            }
            .confirmationDialog("Delete \"\(draft.name)\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.delete(draft)
                    dismiss()
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        }
        .preferredColorScheme(.dark)
        .presentationBackground(DS.Palette.background)
    }

    // MARK: Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Name")
            Card {
                TextField("After School / Work", text: $draft.name)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.text)
                    .padding(.horizontal, 16)
                    .frame(height: DS.Size.touch + 4)
                    .submitLabel(.done)
            }
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Time")
            Card {
                DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 60)
                RowDivider(inset: 16)
                DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 60)
            }
            .font(DS.Typography.body.weight(.medium))
            .foregroundStyle(DS.Palette.text)
            .tint(DS.Palette.accent)

            Text(durationCaption)
                .font(DS.Typography.footnote)
                .foregroundStyle(duration < 15 ? DS.Palette.danger : DS.Palette.tertiary)
                .padding(.leading, 4)
        }
    }

    private var durationCaption: String {
        if duration < 15 { return "Schedules need to be at least 15 minutes." }
        let overnight = TimeOfDay(date: endTime).totalMinutes <= TimeOfDay(date: startTime).totalMinutes
        return TimeFormat.minutes(duration) + (overnight ? " · ends the next morning" : "")
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Repeat")
            Card(padding: 12) {
                HStack(spacing: 0) {
                    ForEach(Weekday.displayOrder) { day in
                        let on = draft.days.contains(day)
                        Button {
                            if on { draft.days.remove(day) } else { draft.days.insert(day) }
                        } label: {
                            Text(day.initial)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(on ? Color.black : DS.Palette.secondary)
                                .frame(width: 42, height: 42)
                                .background(on ? DS.Palette.text : DS.Palette.raised, in: Circle())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: on)
                    }
                }
            }
        }
    }

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Blocking")
            Card {
                if model.screenTime.isAuthorized {
                    NavRow(title: "Apps & sites", value: selection.summary, systemImage: "square.grid.2x2") {
                        showPicker = true
                    }
                    RowDivider()
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            IconBadge(systemImage: "hourglass")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Allowance")
                                    .font(DS.Typography.body.weight(.medium))
                                    .foregroundStyle(DS.Palette.text)
                                Text(draft.timeLimit == .off
                                     ? "Block as soon as the schedule starts"
                                     : "Block after \(draft.timeLimit.label) of use in this window")
                                    .font(DS.Typography.footnote)
                                    .foregroundStyle(DS.Palette.secondary)
                            }
                        }
                        ChipPicker(options: TimeLimit.allCases, selection: $draft.timeLimit,
                                   label: { $0 == .off ? "None" : $0.label })
                    }
                    .padding(16)
                } else {
                    Text("Screen Time isn't connected, so this schedule will start a Strict Focus Lock instead of blocking specific apps.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Palette.secondary)
                        .padding(16)
                }
                RowDivider()
                ToggleRow(title: "Hard Mode",
                          subtitle: "Can't be stopped, edited or disabled while active",
                          systemImage: "lock",
                          isOn: $draft.hardMode)
            }
        }
    }

    // MARK: Save

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        draft.start = TimeOfDay(date: startTime)
        draft.end = TimeOfDay(date: endTime)
        draft.selectionData = selection.isEmptySelection ? nil : ShieldController.encode(selection)
        model.save(draft)
        dismiss()
    }
}
