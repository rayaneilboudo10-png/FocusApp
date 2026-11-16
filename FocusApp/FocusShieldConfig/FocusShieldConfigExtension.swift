import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the system block screen shown when a shielded app or site is opened.
/// Reads the theme, quote and Hard Mode state from the shared App Group.
final class FocusShieldConfigExtension: ShieldConfigurationDataSource {
    private let store = SharedStore.shared

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(blockedName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(blockedName: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(blockedName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(blockedName: webDomain.domain ?? category.localizedDisplayName)
    }

    // MARK: -

    private func makeConfiguration(blockedName: String?) -> ShieldConfiguration {
        let palette = store.theme.palette
        let quote = store.currentQuote().text
        let hardLockEnd = store.hardLockEndDate()

        var subtitle = "“\(quote)”"
        if let blockedName, !blockedName.isEmpty {
            subtitle = "\(blockedName) is blocked right now.\n\n" + subtitle
        }
        if let hardLockEnd {
            subtitle += "\n\nHard Mode · unlocks at \(Self.timeFormatter.string(from: hardLockEnd))"
        }

        let icon = UIImage(systemName: hardLockEnd == nil ? "moon.fill" : "lock.fill",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .light))?
            .withTintColor(palette.uiAccent, renderingMode: .alwaysOriginal)

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: palette.uiBackground,
            icon: icon,
            title: .init(text: hardLockEnd == nil ? "Stay focused." : "Locked.", color: palette.uiText),
            subtitle: .init(text: subtitle, color: palette.uiSecondary),
            primaryButtonLabel: .init(text: "Close", color: palette.uiOnAccent),
            primaryButtonBackgroundColor: palette.uiAccent,
            // Hard Mode: no secondary button at all, so there is nothing to tap to escape.
            secondaryButtonLabel: hardLockEnd == nil
                ? .init(text: "End focus", color: palette.uiSecondary)
                : nil
        )
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
