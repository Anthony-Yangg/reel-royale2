import SwiftUI

struct MoreView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            // Tools section
            Section {
                NavigationLink(value: NavigationDestination.fishID) {
                    MoreRowView(
                        icon: "sparkles",
                        iconColor: .purple,
                        title: "Fish ID",
                        subtitle: "Identify species using AI"
                    )
                }
                
                NavigationLink(value: NavigationDestination.measureFish) {
                    MoreRowView(
                        icon: "ruler",
                        iconColor: .seafoam,
                        title: "Measure Fish",
                        subtitle: "Use AR to measure catch length"
                    )
                }
            } header: {
                Text("Tools")
            }
            
            // Information section
            Section {
                NavigationLink(value: NavigationDestination.regulations(spotId: nil)) {
                    MoreRowView(
                        icon: "doc.text.fill",
                        iconColor: .oceanBlue,
                        title: "Regulations",
                        subtitle: "Fishing rules and limits"
                    )
                }
                
                NavigationLink(value: NavigationDestination.leaderboard) {
                    MoreRowView(
                        icon: "trophy.fill",
                        iconColor: .crown,
                        title: "Leaderboard",
                        subtitle: "Global rankings"
                    )
                }
            } header: {
                Text("Information")
            }
            
            // Settings section
            Section {
                NavigationLink(value: NavigationDestination.settings) {
                    MoreRowView(
                        icon: "gearshape.fill",
                        iconColor: .gray,
                        title: "Settings",
                        subtitle: "App preferences"
                    )
                }
                
                Button {
                    // Open help/support
                } label: {
                    MoreRowView(
                        icon: "questionmark.circle.fill",
                        iconColor: .blue,
                        title: "Help & Support",
                        subtitle: "FAQs and contact"
                    )
                }
                
                Button {
                    // Share app
                    shareApp()
                } label: {
                    MoreRowView(
                        icon: "square.and.arrow.up.fill",
                        iconColor: .green,
                        title: "Share App",
                        subtitle: "Invite friends to fish"
                    )
                }
            } header: {
                Text("Settings")
            }
            
            // About section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://reelroyale.com/privacy")!) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://reelroyale.com/terms")!) {
                    HStack {
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("About")
            }
            
            // App info footer
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "fish.fill")
                        .font(.largeTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.seafoam, .coral],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Reel Royale")
                        .font(.headline)
                    
                    Text("King of the Hill Fishing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func shareApp() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        let shareText = "Check out Reel Royale - the king of the hill fishing app! 🎣👑"
        let shareURL = URL(string: "https://reelroyale.com")!
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText, shareURL],
            applicationActivities: nil
        )
        
        rootVC.present(activityVC, animated: true)
    }
}

struct MoreRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        MoreView()
            .environmentObject(AppState.shared)
    }
}

