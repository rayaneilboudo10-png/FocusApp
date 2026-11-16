import ActivityKit
import Foundation

/// Lock Screen Live Activity for a running focus session.
struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var hardMode: Bool
        var quote: String
    }

    var title: String
    var themeRaw: String

    var theme: BlockTheme { BlockTheme(rawValue: themeRaw) ?? .pureOLED }
}
