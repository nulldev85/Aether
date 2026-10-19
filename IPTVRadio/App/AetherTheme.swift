import SwiftUI

/// Lineup iPhone reference: 97ce5e768b4f33f3271e9f2c27eec2beda93ab3f.
/// One fixed dark palette for every Aether screen, sheet and player surface.
enum AetherTheme {
    static func rgb(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    static let uiCanvas = rgb(0x1C1C1E)
    static let uiNavigationSurface = rgb(0x2C2C2E)
    static let uiPrimaryText = rgb(0xFFFFFF)
    static let uiMutedIcon = rgb(0x9E9EA5)
    static let uiAccent = rgb(0xFF3347)
    static let canvas = Color(uiColor: uiCanvas)
    static let surface = Color(uiColor: uiNavigationSurface)
    static let navigationSurface = surface
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.66)
    static let caption = Color(uiColor: rgb(0xCCCCCC))
    static let mutedIcon = Color(uiColor: uiMutedIcon)
    static let accent = Color(uiColor: uiAccent)
    static let onAccent = Color.white
    // LineupAccent.red.soft: 45% white mixed into broadcast red.
    static let accentSoft = Color(uiColor: rgb(0xFF8F9A))
    static let selected = Color(uiColor: rgb(0x3A3A3C))
    static let divider = Color(uiColor: rgb(0x404043))
    static let border = Color.white.opacity(0.09)
    static let destructive = Color(uiColor: rgb(0xFF453A))
    static let tabBar = surface
    static let raisedSurface = surface
    static let background = canvas
    static let logoShadow = Color.white.opacity(0.48)
    static let panelRadius: CGFloat = 24
    static let compactRadius: CGFloat = 14
    static let margin: CGFloat = 20
    static let panelInset: CGFloat = 20
    static let panelGap: CGFloat = 14
    static let displayFont = Font.radio(.largeTitle, .heavy)
    static let sectionFont = Font.radio(.title3, .bold)

    static func roundedUIFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: size)
    }
}

extension Font {
    /// Matches Lineup's current .inter helpers, which use SF Pro Rounded.
    static func radio(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func radio(_ style: Font.TextStyle, _ weight: Font.Weight? = nil) -> Font {
        .system(style, design: .rounded, weight: weight ?? (style == .headline ? .semibold : .regular))
    }
}

enum AetherNavigationLayout {
    // MobileLineupNavigationLayout: 20-point margins, 4-point padding,
    // 54-point items, and a 20-point physical bottom gap on home-indicator phones.
    static let sideMargin: CGFloat = 20
    static let padding: CGFloat = 4
    static let itemHeight: CGFloat = 54
    static let navigationHeight: CGFloat = 62
    static let playerGap: CGFloat = 8

    static func bottomGap(safeAreaBottom: CGFloat) -> CGFloat { safeAreaBottom > 0 ? 20 : 8 }

    static func reservedHeight(hasPlayer: Bool, playerHeight: CGFloat, safeAreaBottom: CGFloat) -> CGFloat {
        max(0, navigationHeight + bottomGap(safeAreaBottom: safeAreaBottom)
            + (hasPlayer ? playerHeight + playerGap : 0) - max(0, safeAreaBottom))
    }
}
