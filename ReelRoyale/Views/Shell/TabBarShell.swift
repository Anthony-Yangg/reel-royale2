import SwiftUI

/// Custom tab bar with center FAB. Wraps the existing primary tab content.
/// Wave 1 renders Map / Community / [FAB] / Profile / More.
/// (Home tab is declared in AppTab but rendered only starting Wave 2.)
struct TabBarShell<Content: View>: View {
    @ViewBuilder var content: (AppTab) -> Content
    let onFABTap: () -> Void

    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            // Active tab content
            content(appState.selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.colors.surface.canvas.ignoresSafeArea())

            // Tab bar overlay
            tabBar
        }
    }

    private var tabBar: some View {
        ZStack(alignment: .top) {
            // Bar background
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.colors.surface.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(theme.colors.brand.brassGold.opacity(0.25), lineWidth: 1)
                )
                .reelShadow(theme.shadow.heroCard)
                .frame(height: 68)
                .padding(.horizontal, theme.spacing.s)

            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.spots)
                Spacer(minLength: 64)  // reserved space for FAB
                tabButton(.community)
                tabButton(.profile)
            }
            .frame(height: 68)
            .padding(.horizontal, theme.spacing.lg)

            // Center FAB anchored above bar center
            CenterFAB(action: onFABTap)
                .offset(y: -22)
        }
        .frame(height: 92, alignment: .top)
        .padding(.bottom, 14)   // lift higher above home indicator
        .ignoresSafeArea(.keyboard)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = appState.selectedTab == tab
        return Button {
            appState.haptics?.tap()
            appState.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: isSelected ? .heavy : .regular))
                    .foregroundStyle(isSelected ? theme.colors.brand.crown : theme.colors.text.secondary)
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? theme.colors.brand.crown : theme.colors.text.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
