import SwiftUI

/// 2×2 grid of feature shortcuts.
struct FeatureCTAGrid: View {
    let onFishID: () -> Void
    let onMeasure: () -> Void
    let onRegulations: () -> Void
    let onLeaderboard: () -> Void

    @Environment(\.reelTheme) private var theme

    private struct CTA: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        let action: () -> Void
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Tools", subtitle: "Build your edge")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: theme.spacing.s), GridItem(.flexible(), spacing: theme.spacing.s)], spacing: theme.spacing.s) {
                ForEach(ctas) { cta in
                    tile(cta)
                }
            }
        }
    }

    private var ctas: [CTA] {
        [
            CTA(title: "Fish ID",      subtitle: "AI species",  icon: "sparkles",            tint: theme.colors.brand.seafoam,   action: onFishID),
            CTA(title: "Measure",      subtitle: "AR ruler",    icon: "ruler.fill",          tint: theme.colors.brand.tideTeal,  action: onMeasure),
            CTA(title: "Regulations",  subtitle: "Know rules",  icon: "doc.text.fill",       tint: theme.colors.brand.brassGold, action: onRegulations),
            CTA(title: "Leaderboard",  subtitle: "Global rank", icon: "trophy.fill",         tint: theme.colors.brand.crown,     action: onLeaderboard)
        ]
    }

    private func tile(_ cta: CTA) -> some View {
        Button(action: cta.action) {
            HStack(spacing: theme.spacing.s) {
                ZStack {
                    Circle()
                        .fill(cta.tint.opacity(0.22))
                        .frame(width: 40, height: 40)
                    Image(systemName: cta.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(cta.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(cta.title)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                    Text(cta.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.colors.text.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(theme.colors.text.muted)
            }
            .padding(theme.spacing.s + 2)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .fill(theme.colors.surface.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .strokeBorder(cta.tint.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
