import SwiftUI
import UIKit

/// Full-screen Strict Focus Lock.
/// - Can't be swiped away or dismissed by any code path while the timer runs
///   (see the guarded binding in `RootView`).
/// - Hides the status bar and home indicator, and defers system edge gestures so the
///   first swipe from any edge only reveals the indicator instead of acting.
/// - In Hard Mode there is no exit control at all.
struct StrictLockView: View {
    @Environment(AppModel.self) private var model
    @State private var guidedAccessOn = UIAccessibility.isGuidedAccessEnabled

    var body: some View {
        let palette = model.theme.palette
        let sessions = model.sessions

        ZStack {
            if let session = sessions.active {
                BlockScreenView(theme: model.theme,
                                quote: model.currentQuote.text,
                                startDate: session.startDate,
                                endDate: session.endDate,
                                hardMode: session.hardMode)

                VStack {
                    statusStrip(session: session, palette: palette)
                    Spacer()
                    Group {
                        if sessions.canStop {
                            HoldToEndButton(palette: palette) { sessions.stop() }
                        } else {
                            Text("No early exit in Hard Mode")
                                .font(DS.Typography.footnote)
                                .foregroundStyle(palette.secondary)
                                .frame(height: DS.Size.primaryButton)
                        }
                    }
                    .padding(.horizontal, DS.Space.gutter)
                    .padding(.bottom, DS.Space.m)
                }
            } else {
                palette.background.ignoresSafeArea()
            }

            if let event = sessions.breachEvent {
                BreachView(event: event) { sessions.acknowledgeBreach() }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sessions.breachEvent)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .interactiveDismissDisabled()
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.guidedAccessStatusDidChangeNotification)) { _ in
            guidedAccessOn = UIAccessibility.isGuidedAccessEnabled
        }
    }

    @ViewBuilder
    private func statusStrip(session: FocusSession, palette: BlockPalette) -> some View {
        let counter = model.sessions.counter
        HStack(spacing: 10) {
            if guidedAccessOn {
                Label("Guided Access on", systemImage: "lock.iphone")
            } else if session.hardMode {
                Label("Triple-click the side button to pin this screen", systemImage: "hand.tap")
            }
            Spacer(minLength: 0)
            if counter.redirects > 0 {
                Label("\(counter.redirects)", systemImage: "arrow.uturn.backward")
            }
            if counter.breaches > 0 {
                Label("\(counter.breaches)", systemImage: "exclamationmark.octagon")
            }
        }
        .font(DS.Typography.footnote.weight(.medium))
        .foregroundStyle(palette.secondary)
        .padding(.horizontal, DS.Space.gutter)
        .padding(.top, DS.Space.m)
    }
}

/// Adds friction to ending a soft session: press and hold for 2.5 s.
private struct HoldToEndButton: View {
    let palette: BlockPalette
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(palette.surface)
            GeometryReader { geo in
                Capsule()
                    .fill(palette.accent.opacity(0.35))
                    .frame(width: geo.size.width * progress)
            }
            Text(holding ? "Keep holding…" : "Hold to end session")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.text.opacity(0.8))
                .frame(maxWidth: .infinity)
        }
        .frame(height: DS.Size.primaryButton)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: 2.5, maximumDistance: 40) {
            action()
        } onPressingChanged: { pressing in
            holding = pressing
            withAnimation(pressing ? .linear(duration: 2.5) : .easeOut(duration: 0.2)) {
                progress = pressing ? 1 : 0
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: holding)
    }
}
