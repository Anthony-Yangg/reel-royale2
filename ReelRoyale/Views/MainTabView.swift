import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogCatch = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content based on selected tab
            Group {
                switch appState.selectedTab {
                case .spots:
                    NavigationStack(path: $appState.spotsNavigationPath) {
                        SpotsView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                case .community:
                    NavigationStack(path: $appState.communityNavigationPath) {
                        CommunityView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                case .profile:
                    NavigationStack(path: $appState.profileNavigationPath) {
                        ProfileView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                case .more:
                    NavigationStack {
                        MoreView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                }
            }
            // No bottom padding - map goes to edge
            
            // Floating Tab Bar
            FloatingTabBar(
                selectedTab: $appState.selectedTab,
                onCenterTap: {
                    showLogCatch = true
                }
            )
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showLogCatch) {
            NavigationStack {
                LogCatchView(preselectedSpotId: nil)
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .spotDetail(let spotId):
            SpotDetailView(spotId: spotId)
            
        case .catchDetail(let catchId):
            CatchDetailView(catchId: catchId)
            
        case .logCatch(let spotId):
            LogCatchView(preselectedSpotId: spotId)
            
        case .userProfile(let userId):
            ProfileView(userId: userId)
            
        case .territory(let territoryId):
            TerritoryView(territoryId: territoryId)
            
        case .regulations(let spotId):
            RegulationsView(spotId: spotId)
            
        case .fishID:
            FishIDView()
            
        case .measureFish:
            MeasurementView(onCapture: { _ in })
            
        case .leaderboard:
            LeaderboardView()
            
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Floating Tab Bar Component
struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab
    var onCenterTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Left tabs
            TabBarButton(
                icon: "map.fill",
                label: "Spots",
                isSelected: selectedTab == .spots
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .spots
                }
            }
            
            TabBarButton(
                icon: "person.3.fill",
                label: "Feed",
                isSelected: selectedTab == .community
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .community
                }
            }
            
            // Center Action Button
            CenterActionButton(action: onCenterTap)
                .offset(y: -12)
            
            TabBarButton(
                icon: "person.crop.circle.fill",
                label: "Profile",
                isSelected: selectedTab == .profile
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .profile
                }
            }
            
            TabBarButton(
                icon: "ellipsis.circle.fill",
                label: "More",
                isSelected: selectedTab == .more
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .more
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.cardWhite)
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, -20)
        .ignoresSafeArea(edges: .bottom)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height < -30 {
                        onCenterTap()
                    }
                }
        )
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(isSelected ? .navyPrimary : .gray.opacity(0.5))
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Center Action Button (Log Catch)
struct CenterActionButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            ZStack {
                // Main button - solid aqua/mint green with black outline
                Circle()
                    .fill(Color.aquaHighlight)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2.5)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                
                // Fish icon - appropriate for log catch
                Image(systemName: "fish.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// Settings placeholder
struct SettingsView: View {
    var body: some View {
        List {
            Section("Account") {
                NavigationLink("Edit Profile") {
                    Text("Edit Profile")
                }
                NavigationLink("Privacy Settings") {
                    Text("Privacy Settings")
                }
            }
            
            Section("App") {
                NavigationLink("Notifications") {
                    Text("Notifications")
                }
                NavigationLink("Units & Measurements") {
                    Text("Units & Measurements")
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.shared)
}

