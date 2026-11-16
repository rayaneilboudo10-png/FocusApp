import FamilyControls
import SwiftUI

struct FocusView: View {
    @Environment(AppModel.self) private var model
    @State private var showAppPicker = false
    @State private var showLimitPicker = false
    @State private var confirmHardMode = false

    private let presets = [15, 25, 45, 60, 90, 120]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                ScreenHeader("Focus", subtitle: model.sessions.active == nil ? "Pick a length. Begin." : "In session")

                if let done = model.sessions.justCompleted {
                    CompletionBanner(session: done) { model.sessions.acknowledgeCompletion() }
                }

                if let active = model.sessions.active {
                    ActiveSessionPanel(session: active)
                } else {
                    setupPanel
                }

                blockingSection
                dailyLimitSection
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.bottom, DS.Space.xl)
        }
        .scrollIndicators(.hidden)
        .background(DS.Palette.background.ignoresSafeArea())
        .confirmationDialog("Start in Hard Mode?", isPresented: $confirmHardMode, titleVisibility: .visible) {
            Button("Lock for \(TimeFormat.minutes(model.focusMinutes))", role: .destructive) { model.startFocus() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("There is no stop button in Hard Mode. Everything stays locked until the timer reaches zero — even if you close or force-quit the app.")
        }
    }

    // MARK: Setup

    @ViewBuilder
    private var setupPanel: some View {
        @Bindable var model = model
        let strictBinding = Binding(
            get: { model.strictLockEnabled || model.strictLockForced },
            set: { model.strictLockEnabled = $0 }
        )

        VStack(spacing: DS.Space.l) {
            DurationDial(minutes: $model.focusMinutes)

            ChipPicker(options: presets, selection: $model.focusMinutes, label: { TimeFormat.minutes($0) })

            Card {
                ToggleRow(title: "Hard Mode",
                          subtitle: "No stop button until the timer ends",
                          systemImage: "lock",
                          isOn: $model.hardModeEnabled)
                RowDivider()
                ToggleRow(title: "Strict Focus Lock",
                          subtitle: model.strictLockForced
                            ? "Always on while Screen Time is unavailable"
                            : "Full-screen timer, nudges if you leave",
                          systemImage: "rectangle.portrait.inset.filled",
                          isOn: strictBinding,
                          disabled: model.strictLockForced)
            }

            Button {
                if model.hardModeEnabled { confirmHardMode = true } else { model.startFocus() }
            } label: {
                Label(model.hardModeEnabled ? "Start locked session" : "Start focus",
                      systemImage: model.hardModeEnabled ? "lock.fill" : "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: model.sessions.active?.id)
        }
    }

    // MARK: Blocked apps

    private var blockingSection: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Blocked during focus")
            Card {
                if model.screenTime.isAuthorized {
                    NavRow(title: "Apps & sites",
                           value: model.focusSelection.summary,
                           systemImage: "square.grid.2x2",
                           disabled: model.sessions.active != nil) {
                        showAppPicker = true
                    }
                } else {
                    ScreenTimeConnectRow()
                }
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $model.focusSelection)
    }

    // MARK: Daily limit

    private var dailyLimitSection: some View {
        @Bindable var model = model
        let locked = model.hardLockEnd != nil
        let available = model.screenTime.isAuthorized

        return VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Daily limit")
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text(available
                         ? "Allow a daily allowance, then block automatically."
                         : "Requires Screen Time access.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Palette.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    ChipPicker(options: TimeLimit.allCases,
                               selection: $model.dailyLimit.limit,
                               label: { $0.label },
                               disabled: locked || !available)
                        .padding(.horizontal, 16)

                    RowDivider(inset: 16)

                    NavRow(title: "Limited apps",
                           value: model.dailyLimitSelection.summary,
                           systemImage: "hourglass",
                           disabled: locked || !available) {
                        showLimitPicker = true
                    }
                }
            }
            if locked {
                Text("Locked while Hard Mode is active.")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Palette.tertiary)
                    .padding(.leading, 4)
            }
        }
        .familyActivityPicker(isPresented: $showLimitPicker, selection: $model.dailyLimitSelection)
    }
}

// MARK: - Duration dial

private struct DurationDial: View {
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 0) {
            step("minus") { minutes = max(5, minutes - 5) }
            Spacer()
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(DS.Typography.timer(104))
                    .foregroundStyle(DS.Palette.text)
                    .contentTransition(.numericText(value: Double(minutes)))
                Text("minutes")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Palette.secondary)
            }
            Spacer()
            step("plus") { minutes = min(480, minutes + 5) }
        }
        .padding(.top, DS.Space.m)
        .sensoryFeedback(.selection, trigger: minutes)
    }

    private func step(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(DS.Palette.text)
                .frame(width: DS.Size.touch, height: DS.Size.touch)
                .background(DS.Palette.raised, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active session

private struct ActiveSessionPanel: View {
    @Environment(AppModel.self) private var model
    let session: FocusSession
    @State private var confirmStop = false

    var body: some View {
        VStack(spacing: DS.Space.l) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ZStack {
                    Circle()
                        .stroke(DS.Palette.raised, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: 1 - session.progress(at: context.date))
                        .stroke(DS.Palette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: context.date)
                    VStack(spacing: 10) {
                        Text(TimeFormat.countdown(session.remaining(at: context.date)))
                            .font(DS.Typography.timer(68))
                            .foregroundStyle(DS.Palette.text)
                        Label("Until \(TimeFormat.clock(session.endDate))",
                              systemImage: session.hardMode ? "lock.fill" : "moon.fill")
                            .font(DS.Typography.footnote)
                            .foregroundStyle(DS.Palette.secondary)
                    }
                }
                .frame(width: DS.Size.ring, height: DS.Size.ring)
                .frame(maxWidth: .infinity)
            }

            Text("“\(model.currentQuote.text)”")
                .font(DS.Typography.quote)
                .italic()
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.Palette.secondary)
                .padding(.horizontal, DS.Space.m)

            VStack(spacing: DS.Space.s) {
                if session.strictLock {
                    Button("Open Focus Lock") { model.sessions.presentLock() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                if model.sessions.canStop {
                    Button("Stop session") { confirmStop = true }
                        .buttonStyle(SecondaryButtonStyle(foreground: DS.Palette.danger))
                } else {
                    // Hard Mode: no stop / cancel / unblock control is rendered at all.
                    Label("Hard Mode — unlocks at \(TimeFormat.clock(session.endDate))", systemImage: "lock.fill")
                        .font(DS.Typography.footnote.weight(.medium))
                        .foregroundStyle(DS.Palette.accent)
                        .frame(height: DS.Size.touch)
                }
            }
        }
        .padding(.top, DS.Space.s)
        .alert("End this session early?", isPresented: $confirmStop) {
            Button("End session", role: .destructive) { model.sessions.stop() }
            Button("Keep focusing", role: .cancel) {}
        }
    }
}

// MARK: - Completion banner

private struct CompletionBanner: View {
    let session: FocusSession
    let onDismiss: () -> Void

    var body: some View {
        Card(padding: 16) {
            HStack(spacing: 14) {
                IconBadge(systemImage: "checkmark", tint: DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session complete")
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(DS.Palette.text)
                    Text("You focused for \(TimeFormat.minutes(Int(session.duration / 60))).")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Palette.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Palette.tertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Screen Time connect row

struct ScreenTimeConnectRow: View {
    @Environment(AppModel.self) private var model
    @State private var connecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                IconBadge(systemImage: "hourglass.badge.plus")
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(DS.Palette.text)
                    Text(message)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                connecting = true
                Task {
                    await model.connectScreenTime()
                    connecting = false
                }
            } label: {
                Text(connecting ? "Connecting…" : "Connect Screen Time")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(connecting)
        }
        .padding(16)
    }

    private var title: String {
        switch model.screenTime.state {
        case .unavailable: return "Screen Time unavailable"
        case .denied: return "Screen Time access denied"
        default: return "System-wide blocking"
        }
    }

    private var message: String {
        switch model.screenTime.state {
        case .unavailable:
            return "This build can't use Screen Time — usually because it's signed with a free Apple ID. Focus uses Strict Focus Lock instead."
        case .denied:
            return "Allow access in Settings › Screen Time. Until then, Strict Focus Lock keeps you on track."
        default:
            return "Connect to block distracting apps across your iPhone. Without it, Strict Focus Lock is used."
        }
    }
}
