import SwiftUI

/// The browsing shell is independent of AetherTheme, which remains the
/// unchanged visual contract for the mini player, record and full player.
enum AetherInterface {
    private static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        }
    }

    static let uiNavigationSurface = adaptive(light: 0xEAE4D9, dark: 0x20221F)
    static let uiPrimaryText = adaptive(light: 0x252421, dark: 0xF3EFE6)
    static let uiMutedIcon = adaptive(light: 0x6B6257, dark: 0xB7B0A3)
    static let uiAccent = adaptive(light: 0x8D4B1C, dark: 0xD2A262)
    static let canvas = Color(uiColor: adaptive(light: 0xF3EFE6, dark: 0x171916))
    static let surface = Color(uiColor: adaptive(light: 0xFFFCF6, dark: 0x22251F))
    static let navigationSurface = Color(uiColor: uiNavigationSurface)
    static let primaryText = Color(uiColor: uiPrimaryText)
    static let secondaryText = Color(uiColor: adaptive(light: 0x685F53, dark: 0xC3BBAE))
    static let mutedIcon = Color(uiColor: uiMutedIcon)
    static let accent = Color(uiColor: uiAccent)
    static let onAccent = Color(uiColor: adaptive(light: 0xFFFCF6, dark: 0x211D16))
    static let accentSoft = Color(uiColor: adaptive(light: 0xF0DFCA, dark: 0x3A3021))
    static let destructive = Color(uiColor: adaptive(light: 0x9B372D, dark: 0xF2ACA1))
    static let border = Color(uiColor: adaptive(light: 0xD6CDBE, dark: 0x42473C))
    static let tabBar = navigationSurface
    static let raisedSurface = surface
    static let background = canvas
    static let displayFont = Font.system(.largeTitle, design: .default).weight(.bold)
    static let sectionFont = Font.system(.title3, design: .default).weight(.semibold)
}

/// A simple editorial heading, not a promotional hero or another tappable card.
struct RadioPageHeading: View {
    let title: String
    let subtitle: String
    var eyebrow: String = "AETHER / RADIO"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle().fill(AetherInterface.accent).frame(width: 19, height: 3)
                Text(eyebrow)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(AetherInterface.secondaryText)
            }
            Text(title)
                .font(AetherInterface.displayFont)
                .foregroundStyle(AetherInterface.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AetherInterface.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}
