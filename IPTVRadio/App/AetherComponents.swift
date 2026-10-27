import SwiftUI

struct RadioPageHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.radio(.title, .heavy))
                .foregroundStyle(AetherTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("page.title.\(title)")
            if !subtitle.isEmpty {
                Text(subtitle).font(.radio(.subheadline))
                    .foregroundStyle(AetherTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24).padding(.bottom, 24)
    }
}

struct AetherSectionLabel: View {
    let title: String
    var detail = ""

    var body: some View {
        HStack {
            Text(title).font(.radio(.footnote, .semibold))
            Spacer(minLength: 8)
            Text(detail).font(.radio(11, .medium))
        }
        .foregroundStyle(AetherTheme.mutedIcon)
        .padding(.vertical, 12)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Quiet symbols without decorative boxes or background tiles.
struct AetherIconTile: View {
    let symbol: String
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.radio(size * 0.5, .semibold))
            .foregroundStyle(AetherTheme.mutedIcon)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct AetherPanelHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            AetherIconTile(symbol: symbol, size: 24)
            Text(title).font(.radio(.footnote, .semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
        }
        .foregroundStyle(AetherTheme.secondaryText)
        .padding(.top, 10).padding(.bottom, 10)
    }
}

struct AetherButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.radio(17, .semibold))
            .foregroundStyle(configuration.role == .destructive ? AetherTheme.destructive : (prominent ? AetherTheme.onAccent : AetherTheme.primaryText))
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(prominent ? AetherTheme.selected : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            .overlay(alignment: .bottom) { if !prominent { AetherTheme.divider.frame(height: 0.5) } }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct AetherBarButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.radio(15, .semibold))
            .foregroundStyle(prominent ? AetherTheme.onAccent : AetherTheme.primaryText)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .contentShape(Rectangle())
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
        .listRowBackground(Color.clear)
    }
}

extension View {
    func radioField() -> some View {
        textFieldStyle(.plain).font(.radio(.body))
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) { AetherTheme.divider.frame(height: 0.5) }
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
