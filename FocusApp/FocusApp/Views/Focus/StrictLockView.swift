import SwiftUI

/// Full-screen Strict Focus Lock. In Hard Mode there is no exit control at all.
struct StrictLockView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let palette = model.theme.palette

        ZStack(alignment: .bottom) {
            if let session = model.sessions.active {
                BlockScreenView(theme: model.theme,
                                quote: model.currentQuote.text,
                                startDate: session.startDate,
                                endDate: session.endDate,
                                hardMode: session.hardMode)

                Group {
                    if model.sessions.canStop {
                        HoldToEndButton(palette: palette) { model.sessions.stop() }
                    } else {
                        Text("No early exit in Hard Mode")
                            .font(DS.Typography.footnote)
                            .foregroundStyle(palette.secondary)
                            .frame(height: DS.Size.primaryButton)
                    }
                }
                .padding(.horizontal, DS.Space.gutter)
                .padding(.bottom, DS.Space.m)
            } else {
                palette.background.ignoresSafeArea()
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
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
