import SwiftUI

struct TodaysBountySection: View {
    let bounty: Bounty?
    let onTap: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Today's Bounty", subtitle: "Limited-time goal")
            if let bounty = bounty {
                BountyCard(bounty: bounty, compact: false, onTap: onTap)
            } else {
                LoadingView().frame(height: 120)
            }
        }
    }
}
