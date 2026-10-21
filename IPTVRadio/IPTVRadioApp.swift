import SwiftUI

@main
struct IPTVRadioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var environment: AppEnvironment

    init() {
        let env = AppEnvironmentFactory.makeEnvironment(processArguments: ProcessInfo.processInfo.arguments)
        _environment = StateObject(wrappedValue: env)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.backgroundColor = AetherTheme.uiNavigationSurface
        let inactive = UIColor(AetherTheme.caption)
        let active = UIColor.white
        for itemAppearance in [
            tabAppearance.stackedLayoutAppearance,
            tabAppearance.inlineLayoutAppearance,
            tabAppearance.compactInlineLayoutAppearance
        ] {
            itemAppearance.normal.iconColor = inactive
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: inactive]
            itemAppearance.selected.iconColor = active
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: active]
        }
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        // Match Lineup's neutral selected icons in both navigation styles.
        UITabBar.appearance().tintColor = active
        UITabBar.appearance().unselectedItemTintColor = inactive

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = AetherTheme.uiCanvas
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.white, .font: AetherTheme.roundedUIFont(17, .heavy)]
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white, .font: AetherTheme.roundedUIFont(34, .heavy)]
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().tintColor = .white
        UITabBarItem.appearance().setTitleTextAttributes([.font: AetherTheme.roundedUIFont(10, .semibold)], for: .normal)
        UISearchTextField.appearance().font = AetherTheme.roundedUIFont(17, .regular)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: AetherTheme.roundedUIFont(13, .semibold)], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: AetherTheme.roundedUIFont(17, .semibold)], for: .normal)
        AppLogger.app.info("App started")
    }

    var body: some Scene {
        WindowGroup {
            ThemedRootView()
                .foregroundStyle(AetherTheme.primaryText)
                .environment(\.font, .radio(.body))
                .fontDesign(.rounded)
                .environmentObject(environment)
                .environmentObject(environment.playback)
                .environmentObject(environment.library)
                .environmentObject(environment.auth)
                .environmentObject(environment.settings)
                .environmentObject(environment.favorites)
                .environmentObject(environment.history)
                .environmentObject(environment.manualStations)
                .environmentObject(environment.connectivity)
                .tint(AetherTheme.accent)
        }
    }
}

private struct ThemedRootView: View {
    var body: some View {
        RootView()
            .preferredColorScheme(.dark)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Audio session configuration happens in PlaybackEngine when playback starts.
        return true
    }
}
