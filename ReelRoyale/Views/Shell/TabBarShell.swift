import SwiftUI

/// Custom tab bar with center FAB. Wraps the existing primary tab content.
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
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var tabBar: some View {
        ZStack(alignment: .bottom) {
            // Bar background
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.colors.surface.elevated)
                .reelShadow(theme.shadow.heroCard)
                .frame(height: 76)

            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.spots)
                Spacer(minLength: 72)  // reserved space for FAB
                tabButton(.community)
                tabButton(.profile)
            }
            .frame(height: 68)
            .padding(.horizontal, theme.spacing.lg)

            // Center FAB anchored above bar center
            CenterFAB(action: onFABTap)
                .offset(y: -24)
        }
        // The dock spans edge-to-edge so it visually catches the phone corners, while the
        // controls stay inset enough to remain comfortable touch targets.
        .frame(height: 96, alignment: .bottom)
        .ignoresSafeArea(.keyboard)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = appState.selectedTab == tab
        return Button {
            guard appState.selectedTab != tab else { return }
            AppFeedback.tap.play(appState: appState)
            withAnimation(theme.motion.fast) {
                appState.selectedTab = tab
            }
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
