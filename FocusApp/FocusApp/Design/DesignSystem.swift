import SwiftUI
import UIKit

/// Design tokens tuned for the iPhone 13 Pro Max (428 × 926 pt, 6.7" notch display).
enum DS {
    enum Palette {
        static let background = Color.black                     // #000000 pure OLED
        static let card = Color(hex: 0x121212)                   // #121212 cards
        static let raised = Color.white.opacity(0.06)
        static let stroke = Color.white.opacity(0.07)
        static let text = Color.white
        static let secondary = Color.white.opacity(0.56)
        static let tertiary = Color.white.opacity(0.32)
        static let accent = Color(hex: 0x8A9BB0)                 // single muted steel accent
        static let danger = Color(hex: 0xC27C74)
    }

    enum Space {
        /// Side gutter: 22pt leaves a 384pt content column on the 428pt-wide screen.
        static let gutter: CGFloat = 22
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 26
        static let xl: CGFloat = 40
    }

    enum Radius {
        static let card: CGFloat = 22
        static let control: CGFloat = 18
    }

    enum Size {
        /// Comfortable thumb target on a large phone (Apple minimum is 44).
        static let touch: CGFloat = 56
        static let primaryButton: CGFloat = 62
        static let ring: CGFloat = 304
    }

    enum Typography {
        static func timer(_ size: CGFloat) -> Font {
            .system(size: size, weight: .thin, design: .rounded).monospacedDigit()
        }
        static let largeTitle = Font.system(size: 36, weight: .semibold, design: .default)
        static let headline = Font.system(size: 18, weight: .semibold)
        static let body = Font.system(size: 17)
        static let subheadline = Font.system(size: 15)
        static let footnote = Font.system(size: 13)
        static let caption = Font.system(size: 12, weight: .semibold)
        static let quote = Font.system(size: 19, weight: .regular, design: .serif)
    }

    /// Black, hairline-separated system bars.
    static func configureAppearance() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = .black
        tab.shadowColor = UIColor(white: 1, alpha: 0.07)
        let item = UITabBarItemAppearance()
        item.normal.iconColor = UIColor(white: 1, alpha: 0.32)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 1, alpha: 0.32),
                                           .font: UIFont.systemFont(ofSize: 11, weight: .medium)]
        item.selected.iconColor = .white
        item.selected.titleTextAttributes = [.foregroundColor: UIColor.white,
                                             .font: UIFont.systemFont(ofSize: 11, weight: .semibold)]
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = .black
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}

enum TimeFormat {
    static func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func minutes(_ value: Int) -> String {
        guard value >= 60 else { return "\(value)m" }
        return value % 60 == 0 ? "\(value / 60)h" : "\(value / 60)h \(value % 60)m"
    }
}
