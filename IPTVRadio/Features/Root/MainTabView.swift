import SwiftUI

/// One persistent workspace. Navigation is at the top; playback has its own
/// full-width bottom shelf. Tab identity never owns the audio session.
struct MainTabView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackEngine
    @State private var showNowPlaying = false
    @State private var selectedTab: AetherTab = .radio
    @State private var lastStationTab: AetherTab = .radio

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            TabView(selection: $selectedTab) {
                ManualRadioView().tabItem { Text("Radio") }.tag(AetherTab.radio).toolbar(.hidden, for: .tabBar)
                RadioHomeView().tabItem { Text("SXM") }.tag(AetherTab.sxm).toolbar(.hidden, for: .tabBar)
                FavoritesTabView().tabItem { Text("Favorites") }.tag(AetherTab.favorites).toolbar(.hidden, for: .tabBar)
                SearchView().tabItem { Text("Search") }.tag(AetherTab.search).toolbar(.hidden, for: .tabBar)
                SettingsView().tabItem { Text("Settings") }.tag(AetherTab.settings).toolbar(.hidden, for: .tabBar)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if playback.state.station != nil {
                    MiniPlayerView(onOpen: { showNowPlaying = true })
                }
            }
        }
        .background(AetherTheme.canvas.ignoresSafeArea())
        .tint(AetherTheme.accent)
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView().presentationBackground(AetherTheme.canvas)
        }
    }

    private var workspaceHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Aether").font(.radio(21, .heavy))
                    .foregroundStyle(AetherTheme.primaryText)
                Spacer(minLength: 12)
                utility(.search, symbol: "magnifyingglass")
                utility(.settings, symbol: "slider.horizontal.3")
            }
            .padding(.horizontal, AetherNavigationLayout.sideMargin).padding(.top, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach([AetherTab.radio, .sxm, .favorites]) { tab in
                        Button { select(tab) } label: {
                            Text(tab.title).font(.radio(.subheadline, selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? AetherTheme.primaryText : AetherTheme.mutedIcon)
                                .frame(minWidth: AetherNavigationLayout.minimumTarget, minHeight: AetherNavigationLayout.utilityTarget)
                                .overlay(alignment: .bottom) {
                                    if selectedTab == tab { AetherTheme.primaryText.frame(height: 1) }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
                        .accessibilityIdentifier("tab.\(tab.title.lowercased())")
                    }
                }
                .padding(.horizontal, AetherNavigationLayout.sideMargin)
            }
            AetherTheme.divider.frame(height: 0.5)
        }
        .background {
            if settings.liquidGlassEnabled {
                Rectangle().fill(.ultraThinMaterial).overlay(AetherTheme.canvas.opacity(0.65))
            } else { AetherTheme.canvas }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aether.navigation.header")
    }

    private func utility(_ tab: AetherTab, symbol: String) -> some View {
        Button { select(tab) } label: {
            Image(systemName: symbol).font(.radio(19, .medium))
                .foregroundStyle(selectedTab == tab ? AetherTheme.primaryText : AetherTheme.mutedIcon)
                .frame(width: AetherNavigationLayout.utilityTarget, height: AetherNavigationLayout.utilityTarget).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityHint(selectedTab == tab ? "Returns to \(lastStationTab.title)" : "Opens \(tab.title)")
        .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
        .accessibilityIdentifier("tab.\(tab.title.lowercased())")
    }

    private func select(_ tab: AetherTab) {
        UISelectionFeedbackGenerator().selectionChanged()
        if tab == .settings || tab == .search {
            selectedTab = selectedTab == tab ? lastStationTab : tab
        } else {
            lastStationTab = tab
            selectedTab = tab
        }
    }
}

private enum AetherTab: Int, Identifiable {
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
}
