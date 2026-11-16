import SwiftUI
import UIKit

// MARK: - Guided Access

struct GuidedAccessGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isOn = UIAccessibility.isGuidedAccessEnabled

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    GuideIntro(
                        icon: "lock.iphone",
                        status: isOn ? "Guided Access is active right now" : nil,
                        text: "Apps installed with a free Apple ID can't lock your whole iPhone. iOS's built-in Guided Access can: it pins the screen to Focus and disables the Home gesture, app switching, Control Center and notifications until you enter a passcode."
                    )

                    GuideSection(title: "One-time setup") {
                        GuideStep(1, "Open **Settings › Accessibility › Guided Access** and turn it on.")
                        GuideStep(2, "Tap **Passcode Settings › Set Guided Access Passcode**. Turn **Face ID off** there so a glance can't end it.")
                        GuideStep(3, "Turn on **Accessibility Shortcut** so a triple-click of the side button starts it.")
                    }

                    GuideSection(title: "Each Hard Mode session") {
                        GuideStep(1, "Start the session in Focus.")
                        GuideStep(2, "**Triple-click the side button**, then tap **Start** (top right).")
                        GuideStep(3, "When the timer reaches zero, triple-click again and enter the passcode.")
                    }

                    GuideNote(text: "For a truly unbreakable lock, have someone else type the Guided Access passcode. In an emergency, a force restart (volume up, volume down, then hold the side button) always ends Guided Access.")

                    Button("Open Settings", action: openSettings)
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, DS.Space.gutter)
                .padding(.vertical, DS.Space.m)
            }
            .guideChrome(title: "Guided Access", dismiss: dismiss)
        }
        .preferredColorScheme(.dark)
        .presentationBackground(DS.Palette.background)
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.guidedAccessStatusDidChangeNotification)) { _ in
            isOn = UIAccessibility.isGuidedAccessEnabled
        }
    }

    private func openSettings() {
        // Accessibility deep link works on most iOS versions; fall back to Settings itself.
        let fallback = URL(string: UIApplication.openSettingsURLString)
        guard let url = URL(string: "App-prefs:ACCESSIBILITY") else { return }
        UIApplication.shared.open(url) { opened in
            if !opened, let fallback { UIApplication.shared.open(fallback) }
        }
    }
}

// MARK: - Shortcuts redirects

struct ShortcutsGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    GuideIntro(
                        icon: "arrow.uturn.backward",
                        status: nil,
                        text: "A Shortcuts automation can bounce you straight back to Focus whenever you open a distracting app during a session. It needs no Screen Time access and works with a free Apple ID."
                    )

                    GuideSection(title: "Create the automation") {
                        GuideStep(1, "Open **Shortcuts › Automation**, tap **+**, then choose **App**.")
                        GuideStep(2, "Pick the apps you waste time in (Instagram, TikTok, YouTube…), select **Is Opened** and **Run Immediately**. Turn off **Notify When Run**.")
                        GuideStep(3, "Tap **Next › New Blank Automation** and add the **Is Focus Locked** action (search “Focus”).")
                        GuideStep(4, "Add an **If** action: *If Is Focus Locked is true*.")
                        GuideStep(5, "Inside the If, add **Open Focus Lock**. Tap **Done**.")
                    }

                    GuideSection(title: "Make it stricter") {
                        GuideStep(1, "Add **Settings** to the app list so you can't change the clock or Guided Access mid-session.")
                        GuideStep(2, "Add **App Store** so you can't reinstall a deleted app.")
                        GuideStep(3, "Combine with **Guided Access** during Hard Mode for a true system-level lock.")
                    }

                    GuideNote(text: "Outside a session, Is Focus Locked returns false and your apps open normally. Every redirect is counted and shown on the lock screen.")

                    Button("Open Shortcuts") {
                        if let url = URL(string: "shortcuts://") { openURL(url) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, DS.Space.gutter)
                .padding(.vertical, DS.Space.m)
            }
            .guideChrome(title: "App redirects", dismiss: dismiss)
        }
        .preferredColorScheme(.dark)
        .presentationBackground(DS.Palette.background)
    }
}

// MARK: - Building blocks

private struct GuideIntro: View {
    let icon: String
    let status: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            IconBadge(systemImage: icon, tint: DS.Palette.accent)
            if let status {
                Label(status, systemImage: "checkmark.circle.fill")
                    .font(DS.Typography.footnote.weight(.semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GuideSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel(title)
            Card(padding: 18) {
                VStack(alignment: .leading, spacing: 18) { content }
            }
        }
    }
}

private struct GuideStep: View {
    let number: Int
    let text: LocalizedStringKey

    init(_ number: Int, _ text: LocalizedStringKey) {
        self.number = number
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(Color.black)
                .frame(width: 24, height: 24)
                .background(DS.Palette.text, in: Circle())
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GuideNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundStyle(DS.Palette.accent)
            Text(text)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.raised, in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
    }
}

private extension View {
    func guideChrome(title: String, dismiss: DismissAction) -> some View {
        self
            .scrollIndicators(.hidden)
            .background(DS.Palette.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Palette.text)
                }
            }
    }
}

// MARK: - Row with live Guided Access status

struct GuidedAccessRow: View {
    let action: () -> Void
    @State private var isOn = UIAccessibility.isGuidedAccessEnabled

    var body: some View {
        NavRow(title: "Guided Access",
               value: isOn ? "Active" : "Set up",
               systemImage: "lock.iphone",
               action: action)
            .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.guidedAccessStatusDidChangeNotification)) { _ in
                isOn = UIAccessibility.isGuidedAccessEnabled
            }
    }
}
