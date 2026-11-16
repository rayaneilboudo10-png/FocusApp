import SwiftUI

/// The in-app block screen. Mirrors the ManagedSettings shield so the experience
/// is identical whether Screen Time or Strict Focus Lock is doing the blocking.
struct BlockScreenView: View {
    let theme: BlockTheme
    let quote: String
    var startDate: Date? = nil
    var endDate: Date? = nil
    var hardMode: Bool = false
    /// Scales everything down for the Themes preview card.
    var scale: CGFloat = 1

    var body: some View {
        let palette = theme.palette

        ZStack {
            palette.background.ignoresSafeArea()
            RadialGradient(colors: [palette.accent.opacity(0.12), .clear],
                           center: .top, startRadius: 0, endRadius: 460 * scale)
                .ignoresSafeArea()

            VStack(spacing: 30 * scale) {
                Spacer()

                Image(systemName: hardMode ? "lock.fill" : "moon.fill")
                    .font(.system(size: 26 * scale, weight: .light))
                    .foregroundStyle(palette.accent)

                if let endDate {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(TimeFormat.countdown(endDate.timeIntervalSince(context.date)))
                            .font(DS.Typography.timer(80 * scale))
                            .foregroundStyle(palette.text)
                    }
                } else {
                    Text("Not now.")
                        .font(.system(size: 44 * scale, weight: .light, design: .rounded))
                        .foregroundStyle(palette.text)
                }

                Text("“\(quote)”")
                    .font(.system(size: 21 * scale, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(4 * scale)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.text.opacity(0.86))
                    .padding(.horizontal, 44 * scale)

                Text(statusLine)
                    .font(.system(size: 12 * scale, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondary)

                Spacer()
                Spacer()
            }
        }
    }

    private var statusLine: String {
        switch (hardMode, endDate) {
        case let (true, end?): return "Hard Mode · until \(TimeFormat.clock(end))"
        case let (false, end?): return "Focusing · until \(TimeFormat.clock(end))"
        default: return "This app is blocked"
        }
    }
}
