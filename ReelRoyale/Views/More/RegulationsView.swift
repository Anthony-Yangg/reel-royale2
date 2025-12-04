import SwiftUI

struct RegulationsView: View {
    let spotId: String?
    @State private var regulations: RegulationInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRegion = "General"
    
    private let regions = ["General", "California", "Florida", "Texas", "New York", "Washington"]
    
    var body: some View {
        ScrollView {
            if isLoading {
                LoadingView(message: "Loading regulations...")
                    .frame(height: 300)
            } else if let regulations = regulations {
                regulationsContent(regulations)
            } else {
                defaultRegulationsView
            }
        }
        .navigationTitle("Regulations")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadRegulations()
        }
    }
    
    @ViewBuilder
    private func regulationsContent(_ regulations: RegulationInfo) -> some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.oceanBlue)
                
                Text(regulations.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(regulations.regionName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !regulations.isInSeason {
                    Label("Currently Out of Season", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.coral)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            // License info
            if regulations.licenseRequired {
                licenseSection(regulations)
            }
            
            // Season info
            if regulations.seasonStart != nil || regulations.seasonEnd != nil {
                seasonSection(regulations)
            }
            
            // Size limits
            if let sizeLimits = regulations.sizeLimits, !sizeLimits.isEmpty {
                limitsSection(title: "Size Limits", limits: sizeLimits.map { $0.displayText })
            }
            
            // Bag limits
            if let bagLimits = regulations.bagLimits, !bagLimits.isEmpty {
                limitsSection(title: "Daily Bag Limits", limits: bagLimits.map { $0.displayText })
            }
            
            // Special rules
            if let rules = regulations.specialRules, !rules.isEmpty {
                specialRulesSection(rules)
            }
            
            // General content
            contentSection(regulations.content)
            
            // Source link
            if let sourceURL = regulations.sourceURL, let url = URL(string: sourceURL) {
                Link(destination: url) {
                    HStack {
                        Text("View Official Regulations")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.oceanBlue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.oceanBlue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            // Last updated
            Text("Last updated: \(regulations.lastUpdated.formattedDate)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            
            Spacer(minLength: 32)
        }
    }
    
    @ViewBuilder
    private func licenseSection(_ regulations: RegulationInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("License Required")
                    .font(.headline)
                Spacer()
            }
            
            if let licenseInfo = regulations.licenseInfo {
                Text(licenseInfo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func seasonSection(_ regulations: RegulationInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.orange)
                Text("Season")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                if let start = regulations.seasonStart {
                    VStack(alignment: .leading) {
                        Text("Opens")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(start.formattedDate)
                            .font(.subheadline)
                    }
                }
                
                Spacer()
                
                if let end = regulations.seasonEnd {
                    VStack(alignment: .trailing) {
                        Text("Closes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(end.formattedDate)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func limitsSection(title: String, limits: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(.oceanBlue)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(limits, id: \.self) { limit in
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.secondary)
                        Text(limit)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func specialRulesSection(_ rules: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.coral)
                Text("Special Rules")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rules, id: \.self) { rule in
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.coral)
                        Text(rule)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color.coral.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func contentSection(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General Information")
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var defaultRegulationsView: some View {
        VStack(spacing: 24) {
            // Region picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Region")
                    .font(.headline)
                
                Picker("Region", selection: $selectedRegion) {
                    ForEach(regions, id: \.self) { region in
                        Text(region).tag(region)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Disclaimer
            VStack(spacing: 16) {
                Image(systemName: "info.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.oceanBlue)
                
                Text("Important Notice")
                    .font(.headline)
                
                Text("Fishing regulations vary by location and change frequently. Always check with your local fish and wildlife agency for the most current regulations before fishing.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.oceanBlue.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal)
            
            // Default rules
            VStack(alignment: .leading, spacing: 16) {
                Text("General Guidelines")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    guidelineRow(text: "A valid fishing license is typically required for all anglers")
                    guidelineRow(text: "Respect catch and size limits for each species")
                    guidelineRow(text: "Practice catch and release when appropriate")
                    guidelineRow(text: "Report any illegal fishing activity")
                    guidelineRow(text: "Follow all posted rules at fishing locations")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer(minLength: 32)
        }
        .padding(.top)
    }
    
    private func guidelineRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private func loadRegulations() async {
        guard let spotId = spotId else { return }
        
        isLoading = true
        do {
            regulations = try await AppState.shared.regulationsService.getRegulations(for: spotId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        RegulationsView(spotId: nil)
    }
}

