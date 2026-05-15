import SwiftUI

/// Custom tab bar with center FAB. Wraps the existing primary tab content.
struct TabBarShell<Content: View>: View {
    @ViewBuilder var content: (AppTab) -> Content
    let onFABTap: () -> Void

    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // Active tab content
                content(appState.selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.colors.surface.canvas.ignoresSafeArea())

                // Tab bar overlay
                tabBar(bottomInset: proxy.safeAreaInsets.bottom)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private func tabBar(bottomInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x191919), Color(hex: 0x030303)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 1)
                        .padding(.horizontal, 26)
                        .padding(.top, 8)
                }
                .shadow(color: Color.black.opacity(0.24), radius: 26, x: 0, y: 14)
                .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
                .frame(height: 74)

            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.spots)
                Spacer(minLength: 76)
                tabButton(.fishLog)
                tabButton(.profile)
            }
            .frame(height: 64)
            .padding(.horizontal, 13)
            .padding(.bottom, 5)

            CenterFAB(action: onFABTap)
                .offset(y: -28)
        }
        .frame(height: 104, alignment: .bottom)
        .padding(.horizontal, 18)
        .padding(.bottom, max(12, bottomInset * 0.42))
        .ignoresSafeArea(.keyboard)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = appState.selectedTab == tab
        return Button {
            guard appState.selectedTab != tab else { return }
            AppFeedback.tap.play(appState: appState)
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                appState.selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .heavy : .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.66))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.001))
                    .shadow(color: isSelected ? Color.white.opacity(0.18) : Color.clear, radius: 14, x: 0, y: 0)
            )
            .scaleEffect(isSelected ? 1.0 : 0.96)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
