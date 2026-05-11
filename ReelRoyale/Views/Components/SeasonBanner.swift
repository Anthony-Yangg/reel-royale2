import SwiftUI

/// Compact banner shown at the top of the Spots tab. Surfaces current season
/// + a CTA so players always know how much time is left to climb.
struct SeasonBanner: View {
    let season: Season
    let userScore: Int
    let userRank: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.crown.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "flag.checkered")
                        .foregroundColor(.crown)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Season \(season.seasonNumber)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("\(season.daysRemaining) days remaining")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let rank = userRank {
                        Text("#\(rank)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    Text("\(userScore) pts")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(LinearGradient(colors: [.deepOcean, .oceanBlue], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}
