import SwiftUI

/// Section header used across Home, Profile, Community, etc.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailingActionTitle: String? = nil
    var trailingAction: (() -> Void)? = nil

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.title2)
                    .foregroundStyle(theme.colors.text.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.text.secondary)
                }
            }
            Spacer()
            if let actionTitle = trailingActionTitle, let action = trailingAction {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundStyle(theme.colors.text.primary)
                }
            }
        }
    }
}
