import SwiftUI

@main
struct ReelRoyaleApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        AppState.shared.configure()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.reelTheme, .default)
                .preferredColorScheme(.dark)
        }
    }

    private func configureAppearance() {
        let theme = ReelTheme.default

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(theme.colors.surface.canvas)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(theme.colors.text.primary)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(theme.colors.text.primary)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(theme.colors.brand.seafoam)

        // Tab bar — system tab bar retained for fallback; the custom shell hides it where applied
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(theme.colors.surface.canvas)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(theme.colors.brand.seafoam)
        UITabBar.appearance().unselectedItemTintColor = UIColor(theme.colors.text.secondary)
    }
}
