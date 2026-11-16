import Foundation

/// Resolves the App Group used to share state between the app and its extensions.
///
/// The identifier is injected into every target's Info.plist (`FocusAppGroupIdentifier`)
/// from the `APP_GROUP_ID` build setting, so changing `BUNDLE_ID_PREFIX` keeps all
/// targets in sync. If the group is unavailable at runtime (e.g. a re-signer renamed or
/// stripped it), `SharedStore` falls back to standard `UserDefaults`.
enum AppGroup {
    static let fallbackIdentifier = "group.com.focusapp.focus"

    static var identifier: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "FocusAppGroupIdentifier") as? String,
              !value.isEmpty, !value.contains("$(")
        else { return fallbackIdentifier }
        return value
    }
}
