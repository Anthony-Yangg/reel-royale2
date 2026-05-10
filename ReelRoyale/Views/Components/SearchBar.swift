import SwiftUI

/// Themed search bar.
struct PirateSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    @Environment(\.reelTheme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.colors.text.muted)
                .font(.system(size: 14, weight: .semibold))
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .foregroundStyle(theme.colors.text.primary)
                .font(theme.typography.body)
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.colors.text.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                .fill(theme.colors.surface.elevatedAlt)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                .strokeBorder(isFocused ? theme.colors.brand.brassGold.opacity(0.7) : theme.colors.brand.brassGold.opacity(0.18), lineWidth: 1)
        )
    }
}

/// Themed filter chip used in segmented filter rows.
struct FilterChip: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(isSelected ? theme.colors.text.onLight : theme.colors.text.primary)
            .padding(.horizontal, theme.spacing.s)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? theme.colors.brand.brassGold : theme.colors.surface.elevatedAlt)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(theme.colors.brand.brassGold.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
