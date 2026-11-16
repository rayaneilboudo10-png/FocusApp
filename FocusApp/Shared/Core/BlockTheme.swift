import SwiftUI
import UIKit

/// Block-screen themes, shared by the in-app lock, the Live Activity and the
/// ManagedSettings shield extension.
enum BlockTheme: String, Codable, CaseIterable, Identifiable {
    case pureOLED, midnightSlate, deepAmber, forestNight

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pureOLED: return "Pure OLED"
        case .midnightSlate: return "Midnight Slate"
        case .deepAmber: return "Deep Amber"
        case .forestNight: return "Forest Night"
        }
    }

    var subtitle: String {
        switch self {
        case .pureOLED: return "True black, cool steel accent"
        case .midnightSlate: return "Ink blue, quiet and cold"
        case .deepAmber: return "Warm low light for evenings"
        case .forestNight: return "Muted green, calm and grounded"
        }
    }

    var palette: BlockPalette {
        switch self {
        case .pureOLED:
            return BlockPalette(backgroundHex: 0x000000, surfaceHex: 0x121212, textHex: 0xFFFFFF,
                                secondaryHex: 0x8E8E93, accentHex: 0x8A9BB0, onAccentHex: 0x000000)
        case .midnightSlate:
            return BlockPalette(backgroundHex: 0x0A0E16, surfaceHex: 0x141B26, textHex: 0xE6EAF2,
                                secondaryHex: 0x7D8799, accentHex: 0x7385AD, onAccentHex: 0x0A0E16)
        case .deepAmber:
            return BlockPalette(backgroundHex: 0x0C0804, surfaceHex: 0x1A130B, textHex: 0xF5E9D8,
                                secondaryHex: 0x9C8B74, accentHex: 0xC8924A, onAccentHex: 0x0C0804)
        case .forestNight:
            return BlockPalette(backgroundHex: 0x050A07, surfaceHex: 0x101914, textHex: 0xE3EDE6,
                                secondaryHex: 0x7E9186, accentHex: 0x7FA88E, onAccentHex: 0x050A07)
        }
    }
}

struct BlockPalette {
    let backgroundHex: UInt32
    let surfaceHex: UInt32
    let textHex: UInt32
    let secondaryHex: UInt32
    let accentHex: UInt32
    let onAccentHex: UInt32

    var background: Color { Color(hex: backgroundHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var text: Color { Color(hex: textHex) }
    var secondary: Color { Color(hex: secondaryHex) }
    var accent: Color { Color(hex: accentHex) }
    var onAccent: Color { Color(hex: onAccentHex) }

    var uiBackground: UIColor { UIColor(hex: backgroundHex) }
    var uiSurface: UIColor { UIColor(hex: surfaceHex) }
    var uiText: UIColor { UIColor(hex: textHex) }
    var uiSecondary: UIColor { UIColor(hex: secondaryHex) }
    var uiAccent: UIColor { UIColor(hex: accentHex) }
    var uiOnAccent: UIColor { UIColor(hex: onAccentHex) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}
