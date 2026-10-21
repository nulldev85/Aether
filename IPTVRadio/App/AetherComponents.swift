import SwiftUI

struct RadioPageHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(AetherTheme.displayFont)
                .foregroundStyle(AetherTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.radio(.subheadline))
                .foregroundStyle(AetherTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
}

/// LineupIconTile's native Settings colors, symbol treatment and proportions.
struct AetherIconTile: View {
    let symbol: String
    var size: CGFloat = 30

    private var tint: Color {
        switch symbol {
        case "heart", "heart.fill", "paintbrush.pointed": Color(uiColor: AetherTheme.rgb(0xFF375F))
        case "star", "star.fill": Color(uiColor: AetherTheme.rgb(0xFFCC00))
        case "person.crop.circle", "antenna.radiowaves.left.and.right", "timer", "moon.zzz": Color(uiColor: AetherTheme.rgb(0x0A84FF))
        case "externaldrive", "lock.shield": Color(uiColor: AetherTheme.rgb(0x5E5CE6))
        case "music.note": Color(uiColor: AetherTheme.rgb(0xFF375F))
        case "hifispeaker", "safari", "line.3.horizontal.decrease": Color(uiColor: AetherTheme.rgb(0x30B0C7))
        default: Color(uiColor: AetherTheme.rgb(0x8E8E93))
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.radio(size * 0.5, .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct AetherPanelHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            AetherIconTile(symbol: symbol, size: 24)
            Text(title.uppercased()).font(.radio(15, .heavy)).tracking(0.4)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
        }
        .foregroundStyle(AetherTheme.caption)
        .padding(.top, 15).padding(.bottom, 11)
    }
}

struct AetherButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.radio(17, .semibold))
            .foregroundStyle(configuration.role == .destructive ? AetherTheme.destructive : .white)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(minHeight: 46)
            .background(prominent ? AetherTheme.accent : AetherTheme.selected, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct AetherBarButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.radio(15, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(prominent ? AetherTheme.accent : AetherTheme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(AetherTheme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct AetherNavigationButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Explicit label fonts avoid the title-only control initializers choosing
/// their own standard text style inside Forms and native toggle styles.
struct AetherSettingToggle: View {
    let title: String
    @Binding var isOn: Bool
    var textStyle: Font.TextStyle = .body

    init(_ title: String, isOn: Binding<Bool>, textStyle: Font.TextStyle = .body) {
        self.title = title
        _isOn = isOn
        self.textStyle = textStyle
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title).font(.radio(textStyle, .medium))
        }
        .tint(AetherTheme.accent)
    }
}

struct AetherLabeledValue: View {
    let title: String
    let value: String
    var textStyle: Font.TextStyle = .body

    init(_ title: String, value: String, textStyle: Font.TextStyle = .body) {
        self.title = title
        self.value = value
        self.textStyle = textStyle
    }

    var body: some View {
        LabeledContent {
            Text(value).font(.radio(textStyle))
                .foregroundStyle(AetherTheme.mutedIcon)
        } label: {
            Text(title).font(.radio(textStyle, .medium))
                .foregroundStyle(AetherTheme.primaryText)
        }
    }
}

struct AetherFormSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Section { content } header: {
            Text(title).font(.radio(.footnote, .semibold))
        }
    }
}

extension View {
    func radioField() -> some View {
        textFieldStyle(.plain).font(.radio(.body))
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(AetherTheme.surface, in: RoundedRectangle(cornerRadius: AetherTheme.compactRadius, style: .continuous))
    }

    func radioSettingsList() -> some View {
        listStyle(.insetGrouped)
            .font(.radio(.body))
            .fontDesign(.rounded)
            .environment(\.defaultMinListRowHeight, 58)
            .listSectionSpacing(24)
            .scrollContentBackground(.hidden)
            .background(AetherTheme.background)
    }
}
