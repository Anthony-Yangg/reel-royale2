import SwiftUI

struct MoreView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            theme.colors.surface.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    title
                    toolsSection
                    informationSection
                    settingsSection
                    aboutSection
                    appFooter
                }
                .padding(.horizontal, theme.spacing.m)
                .padding(.top, theme.spacing.s)
                .padding(.bottom, 140)
            }
        }
    }

    private var title: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("More")
                    .font(theme.typography.title1)
                    .foregroundStyle(theme.colors.text.primary)
                Text("Tools · Information · Settings")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.text.secondary)
            }
            Spacer()
            Image(systemName: "compass.drawing")
                .font(.system(size: 26))
                .foregroundStyle(theme.colors.brand.brassGold)
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Tools")
            VStack(spacing: theme.spacing.xs) {
                row(icon: "sparkles",   tint: Color(hex: 0xB47EFF), title: "Fish ID",      subtitle: "Identify species using AI", destination: .fishID)
                row(icon: "ruler.fill", tint: theme.colors.brand.seafoam, title: "Measure Fish", subtitle: "Use AR to measure catch length", destination: .measureFish)
            }
        }
    }

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Information")
            VStack(spacing: theme.spacing.xs) {
                row(icon: "doc.text.fill", tint: theme.colors.brand.tideTeal, title: "Regulations", subtitle: "Fishing rules and limits",  destination: .regulations(spotId: nil))
                row(icon: "trophy.fill",   tint: theme.colors.brand.crown,    title: "Leaderboard", subtitle: "Global rankings",            destination: .leaderboard)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Settings")
            VStack(spacing: theme.spacing.xs) {
                row(icon: "gearshape.fill", tint: theme.colors.text.secondary, title: "Settings",      subtitle: "App preferences",        destination: .settings)
                actionRow(icon: "questionmark.circle.fill", tint: theme.colors.brand.tideTeal, title: "Help & Support", subtitle: "FAQs and contact") {}
                actionRow(icon: "square.and.arrow.up.fill", tint: theme.colors.state.success, title: "Share App", subtitle: "Invite friends to fish") {
                    shareApp()
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "About")
            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.text.primary)
                    Spacer()
                    Text("1.0.0")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.text.secondary)
                }
                .padding(theme.spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                        .fill(theme.colors.surface.elevated)
                )
                .padding(.bottom, theme.spacing.xs)

                linkRow(title: "Privacy Policy", url: "https://reelroyale.com/privacy")
                linkRow(title: "Terms of Service", url: "https://reelroyale.com/terms")
            }
        }
    }

    private var appFooter: some View {
        VStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(
                    LinearGradient(colors: [theme.colors.brand.crown, theme.colors.brand.brassGold], startPoint: .top, endPoint: .bottom)
                )
            Text("Reel Royale")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.primary)
            Text("King of the Seven Seas")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.text.secondary)
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.lg)
    }

    @ViewBuilder
    private func row(icon: String, tint: Color, title: String, subtitle: String, destination: NavigationDestination) -> some View {
        NavigationLink(value: destination) {
            rowContent(icon: icon, tint: tint, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    private func actionRow(icon: String, tint: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowContent(icon: icon, tint: tint, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    private func rowContent(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: theme.spacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.text.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(theme.colors.text.muted)
        }
        .padding(theme.spacing.s + 2)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.15), lineWidth: 1)
        )
    }

    private func linkRow(title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.text.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(theme.colors.text.muted)
            }
            .padding(theme.spacing.m)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .fill(theme.colors.surface.elevated)
            )
        }
        .padding(.bottom, theme.spacing.xs)
    }

    private func shareApp() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        let shareText = "Check out Reel Royale — claim your throne on the seas! 🎣👑"
        let shareURL = URL(string: "https://reelroyale.com")!
        let activityVC = UIActivityViewController(activityItems: [shareText, shareURL], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }
}

#Preview {
    NavigationStack {
        MoreView()
            .environmentObject(AppState.shared)
            .environment(\.reelTheme, .default)
            .preferredColorScheme(.dark)
    }
}
