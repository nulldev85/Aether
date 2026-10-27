import SwiftUI

struct RadioPageHeading: View {
    let title: String
    let subtitle: String
    var eyebrow = "AETHER / PERSONAL RADIO"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Rectangle().fill(AetherTheme.accent).frame(width: 16, height: 3)
                Text(eyebrow).font(.radio(10, .heavy)).tracking(1.8)
                    .foregroundStyle(AetherTheme.accent)
            }
            Text(title).font(AetherTheme.displayFont)
                .foregroundStyle(AetherTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.radio(.subheadline))
                .foregroundStyle(AetherTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            AetherTuningRule().padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18).padding(.bottom, 20)
    }
}

/// A static tuning scale, not a fake signal meter or an audio visualizer.
struct AetherTuningRule: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<45, id: \.self) { tick in
                    Rectangle().fill(AetherTheme.divider)
                        .frame(width: 1, height: tick.isMultiple(of: 5) ? 15 : 6)
                        .frame(maxWidth: .infinity)
                }
            }
            Rectangle().fill(AetherTheme.accent).frame(width: 3, height: 22)
                .position(x: geometry.size.width * 0.36, y: 11)
        }
        .frame(height: 22)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct AetherSectionLabel: View {
    let title: String
    var detail = ""

    var body: some View {
        HStack {
            Text(title.uppercased()).font(.radio(10, .heavy)).tracking(1.4)
            Spacer(minLength: 8)
            Text(detail).font(.radio(11, .medium))
        }
        .foregroundStyle(AetherTheme.mutedIcon)
        .padding(.vertical, 12)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A monochrome etched symbol, never a colored app-icon tile.
struct AetherIconTile: View {
    let symbol: String
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.radio(size * 0.5, .semibold))
            .foregroundStyle(AetherTheme.accent)
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(AetherTheme.divider, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

struct AetherPanelHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            AetherIconTile(symbol: symbol, size: 24)
            Text(title.uppercased()).font(.radio(12, .heavy)).tracking(1.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
        }
        .foregroundStyle(AetherTheme.accent)
        .padding(.top, 18).padding(.bottom, 16)
    }
}

struct AetherButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.radio(17, .semibold))
            .foregroundStyle(configuration.role == .destructive ? AetherTheme.destructive : (prominent ? AetherTheme.onAccent : AetherTheme.primaryText))
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(prominent ? AetherTheme.accent : AetherTheme.surface, in: RoundedRectangle(cornerRadius: AetherTheme.compactRadius))
            .overlay(RoundedRectangle(cornerRadius: AetherTheme.compactRadius).strokeBorder(prominent ? .clear : AetherTheme.divider, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct AetherBarButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.radio(15, .semibold))
            .foregroundStyle(prominent ? AetherTheme.onAccent : AetherTheme.primaryText)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(prominent ? AetherTheme.accent : AetherTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AetherTheme.border, lineWidth: 1))
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
        .listRowBackground(AetherTheme.surface)
    }
}

extension View {
    func radioField() -> some View {
        textFieldStyle(.plain).font(.radio(.body))
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(AetherTheme.surface, in: RoundedRectangle(cornerRadius: AetherTheme.compactRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AetherTheme.compactRadius).strokeBorder(AetherTheme.divider, lineWidth: 1))
    }

    func radioSettingsList() -> some View {
        listStyle(.plain)
            .font(.radio(.body))
            .fontDesign(.rounded)
            .environment(\.defaultMinListRowHeight, 58)
            .listSectionSpacing(24)
            .listRowSpacing(2)
            .scrollContentBackground(.hidden)
            .background(AetherTheme.background)
    }
}
