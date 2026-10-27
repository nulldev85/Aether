import SwiftUI

/// One persistent TabView for Aether's studio dock and optional native bar.
/// The audio session, selected station and vinyl do not depend on tab changes.
struct MainTabView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackEngine
    @State private var showNowPlaying = false
    @State private var selectedTab: AetherTab = .radio
    @ScaledMetric(relativeTo: .body) private var playerHeight: CGFloat = 68

    private var nativeNavigation: Bool {
        if #available(iOS 26.0, *) { return settings.liquidGlassEnabled }
        return false
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $selectedTab) {
                tabContent(safeAreaBottom: proxy.safeAreaInsets.bottom) { ManualRadioView() }
                    .tabItem { Label("Radio", systemImage: "waveform") }.tag(AetherTab.radio)
                tabContent(safeAreaBottom: proxy.safeAreaInsets.bottom) { RadioHomeView() }
                    .tabItem { Label("SXM", systemImage: "antenna.radiowaves.left.and.right") }.tag(AetherTab.sxm)
                tabContent(safeAreaBottom: proxy.safeAreaInsets.bottom) { FavoritesTabView() }
                    .tabItem { Label("Favorites", systemImage: "heart") }.tag(AetherTab.favorites)
                tabContent(safeAreaBottom: proxy.safeAreaInsets.bottom) { SearchView() }
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(AetherTab.search)
                tabContent(safeAreaBottom: proxy.safeAreaInsets.bottom) { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gearshape") }.tag(AetherTab.settings)
            }
            .tint(AetherTheme.accent)
            .overlay(alignment: .bottom) {
                if !nativeNavigation {
                    VStack(spacing: AetherNavigationLayout.playerGap) {
                        if playback.state.station != nil {
                            MiniPlayerView(onOpen: { showNowPlaying = true })
                                .frame(height: playerHeight)
                        }
                        AetherStudioTabBar(selection: $selectedTab)
                    }
                    .padding(.bottom, AetherNavigationLayout.bottomGap(safeAreaBottom: proxy.safeAreaInsets.bottom))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.container, edges: .bottom)
                }
            }
        }
        .background(AetherTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView().tint(AetherTheme.accent)
                .presentationBackground(AetherTheme.background)
        }
    }

    @ViewBuilder
    private func tabContent<Content: View>(safeAreaBottom: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(AetherTheme.primaryText)
            .tint(AetherTheme.accent)
            .toolbar(nativeNavigation ? .visible : .hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if nativeNavigation {
                    if playback.state.station != nil {
                        MiniPlayerView(onOpen: { showNowPlaying = true })
                            .frame(height: playerHeight).padding(.vertical, 8)
                    }
                } else {
                    // One reservation per tab. Individual lists/settings do
                    // not also add padding for the same floating controls.
                    Color.clear.frame(height: AetherNavigationLayout.reservedHeight(
                        hasPlayer: playback.state.station != nil,
                        playerHeight: playerHeight, safeAreaBottom: safeAreaBottom))
                        .accessibilityHidden(true)
                }
            }
    }
}

private enum AetherTab: Int, CaseIterable, Identifiable {
    case radio, sxm, favorites, search, settings
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .radio: "Radio"
        case .sxm: "SXM"
        case .favorites: "Favorites"
        case .search: "Search"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .radio: "waveform"
        case .sxm: "antenna.radiowaves.left.and.right"
        case .favorites: "heart"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

/// A low studio rail with an active copper marker, not floating pill buttons.
private struct AetherStudioTabBar: View {
    @Binding var selection: AetherTab
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AetherTab.allCases) { tab in
                let selected = selection == tab
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selected && tab == .favorites ? "heart.fill" : tab.symbol)
                            .font(.radio(19, .semibold)).frame(width: 25, height: 23)
                        Text(tab.title).font(.radio(labelSize, .semibold))
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(selected ? AetherTheme.accent : AetherTheme.mutedIcon)
                    .frame(maxWidth: .infinity, minHeight: AetherNavigationLayout.itemHeight)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 1).fill(selected ? AetherTheme.accent : .clear)
                            .frame(width: 20, height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(AetherNavigationButtonStyle())
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityValue(selected ? "Selected" : "")
                .accessibilityIdentifier("tab.\(tab.title.lowercased())")
            }
        }
        .padding(AetherNavigationLayout.padding)
        .background(AetherTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AetherTheme.divider, lineWidth: 1).allowsHitTesting(false))
        .padding(.horizontal, AetherNavigationLayout.sideMargin)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
        .accessibilityIdentifier("aether.navigation.custom")
    }
}
