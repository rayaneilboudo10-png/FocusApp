import SwiftUI
import UIKit

/// Deliberately jarring full-screen penalty shown after leaving during Hard Mode.
/// The dismiss button stays disabled for 5 seconds.
struct BreachView: View {
    let event: BreachEvent
    let onAcknowledge: () -> Void

    @State private var countdown = 5
    @State private var pulse = false

    private let alarmRed = Color(hex: 0xFF3B30)

    var body: some View {
        ZStack {
            Color(hex: 0x140000).ignoresSafeArea()
            alarmRed.opacity(pulse ? 0.22 : 0.04).ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 76, weight: .bold))
                    .foregroundStyle(alarmRed)
                    .scaleEffect(pulse ? 1.08 : 0.94)

                VStack(spacing: 10) {
                    Text("FOCUS\nBREACHED")
                        .font(.system(size: 54, weight: .black))
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white)
                    Text("You left for \(Self.awayText(event.awayFor)).")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                }

                VStack(spacing: 10) {
                    if event.addedMinutes > 0 {
                        penaltyRow("plus.circle.fill", "+\(event.addedMinutes) minutes added to your timer")
                    }
                    if event.streakReset {
                        penaltyRow("flame.fill", event.lostStreak > 0
                                   ? "\(event.lostStreak)-day streak lost"
                                   : "Streak reset to zero")
                    }
                    if event.addedMinutes == 0 && !event.streakReset {
                        penaltyRow("exclamationmark.triangle.fill", "Logged as a breach")
                    }
                }
                .padding(.horizontal, DS.Space.gutter)

                Text("Hard Mode means staying. Every exit costs you.")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(Color.white.opacity(0.5))

                Spacer()

                Button(action: onAcknowledge) {
                    Text(countdown > 0 ? "Back to focus in \(countdown)" : "Back to focus")
                }
                .buttonStyle(PrimaryButtonStyle(fill: countdown > 0 ? Color.white.opacity(0.12) : Color.white,
                                                foreground: countdown > 0 ? Color.white.opacity(0.5) : Color.black))
                .disabled(countdown > 0)
                .padding(.horizontal, DS.Space.gutter)
                .padding(.bottom, DS.Space.m)
            }
        }
        .statusBarHidden()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { pulse = true }
        }
        .task {
            for _ in 0..<3 {
                await MainActor.run { UINotificationFeedbackGenerator().notificationOccurred(.error) }
                try? await Task.sleep(for: .milliseconds(350))
            }
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                countdown -= 1
            }
        }
    }

    private func penaltyRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(alarmRed)
            Text(text).foregroundStyle(Color.white)
            Spacer(minLength: 0)
        }
        .font(.system(size: 17, weight: .semibold))
        .padding(.horizontal, 18)
        .frame(minHeight: DS.Size.touch)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
    }

    static func awayText(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if seconds < 60 { return "\(seconds) seconds" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m \(seconds % 60)s" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
