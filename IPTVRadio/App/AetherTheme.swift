import SwiftUI

/// Graphite: dim neutral surfaces and restrained cool-gray chrome.
/// SF Pro Rounded and the always-dark appearance are intentionally unchanged.
enum AetherTheme {
    static func rgb(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    static let uiCanvas = rgb(0x101113)
    static let uiNavigationSurface = rgb(0x181A1D)
    static let uiPrimaryText = rgb(0xC7CBD1)
    static let uiMutedIcon = rgb(0x959DA8)
    static let uiAccent = rgb(0x9CA5B1)
    static let canvas = Color(uiColor: uiCanvas)
    static let surface = Color(uiColor: uiNavigationSurface)
    static let navigationSurface = surface
    static let primaryText = Color(uiColor: uiPrimaryText)
    static let secondaryText = Color(uiColor: rgb(0xA2AAB5))
    static let caption = Color(uiColor: rgb(0xAEB6C1))
    static let mutedIcon = Color(uiColor: uiMutedIcon)
    static let accent = Color(uiColor: uiAccent)
    static let onAccent = primaryText
    static let accentSoft = Color(uiColor: rgb(0xAEB6C1))
    static let selected = Color(uiColor: rgb(0x292D33))
    static let divider = Color(uiColor: rgb(0x30353C))
    static let border = divider
    static let destructive = Color(uiColor: rgb(0xB28D92))
    static let warning = Color(uiColor: rgb(0xA69A88))
    static let tabBar = surface
    static let raisedSurface = Color(uiColor: rgb(0x1D2024))
    static let background = canvas
    static let logoShadow = Color.white.opacity(0.14)
    static let panelRadius: CGFloat = 12
    static let compactRadius: CGFloat = 10
    static let margin: CGFloat = 20
    static let panelInset: CGFloat = 18
    static let panelGap: CGFloat = 24
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
    // The new dock retains the tested single-owner clearance and safe-area
    // arithmetic. Appearance must not recreate the old navigation overlap.
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
