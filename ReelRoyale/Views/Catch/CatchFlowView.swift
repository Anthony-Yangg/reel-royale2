import SwiftUI
import PhotosUI

/// Full-screen 4-step catch flow. Wraps LogCatchViewModel.
struct CatchFlowView: View {
    let preselectedSpotId: String?
    @StateObject private var viewModel: LogCatchViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.reelTheme) private var theme
    @EnvironmentObject var appState: AppState

    @State private var currentStep: Int = 1
    @State private var showCinematic = false
    @State private var lastReward: ProgressionReward?
    @State private var pickerSelection: PhotosPickerItem?

    private let progression = ProgressionService()
    private let totalSteps = 4
    private let stepLabels = ["Spot", "Catch", "Identify", "Submit"]

    init(preselectedSpotId: String? = nil) {
        self.preselectedSpotId = preselectedSpotId
        _viewModel = StateObject(wrappedValue: LogCatchViewModel(preselectedSpotId: preselectedSpotId))
    }

    var body: some View {
        ZStack {
            theme.colors.surface.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                StepperRail(totalSteps: totalSteps, currentStep: currentStep, labels: stepLabels)
                    .padding(.horizontal, theme.spacing.m)
                    .padding(.vertical, theme.spacing.m)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.colors.surface.canvas)
                    .id(currentStep)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                bottomBar
            }

            if viewModel.isSubmitting {
                LoadingOverlay(isLoading: true, message: "Casting your claim...")
            }
        }
        .fullScreenCover(isPresented: $showCinematic) {
            if let r = lastReward {
                DethroneCinematicView(
                    spotName: viewModel.selectedSpot?.name ?? "Unknown Waters",
                    captainName: appState.currentUser?.username ?? "Captain",
                    avatarURL: appState.currentUser?.avatarURL.flatMap(URL.init),
                    initial: String(appState.currentUser?.username.first ?? "C"),
                    tier: .deckhand,
                    reward: r,
                    onComplete: {
                        showCinematic = false
                        dismiss()
                    }
                )
            }
        }
        .task { await viewModel.loadInitialData() }
        .sheet(isPresented: $viewModel.showSpotPicker) {
            SpotPickerView(spots: viewModel.spots) { spot in
                viewModel.selectSpot(spot)
            }
        }
        .sheet(isPresented: $viewModel.showMeasurement) {
            NavigationStack {
                MeasurementView { length in viewModel.applyMeasurement(length) }
            }
        }
        .sheet(isPresented: $viewModel.showFishID) {
            NavigationStack {
                FishIDView(initialImage: viewModel.catchPhoto) { species in
                    viewModel.species = species
                    viewModel.showFishID = false
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.showSuccess) { _, success in
            guard success else { return }
            let reward = progression.computeReward(
                sizeCm: viewModel.sizeValueDouble,
                isDethrone: viewModel.catchResult?.isNewKing ?? false,
                isRareSpecies: false,
                isFirstAtSpot: viewModel.catchResult?.previousKingId == nil
            )
            lastReward = reward
            if viewModel.catchResult?.isNewKing == true {
                showCinematic = true
            } else {
                appState.haptics?.success()
                appState.sounds?.play(.coinShower)
                dismiss()
            }
        }
        .onChange(of: pickerSelection) { _, item in
            guard let item = item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    viewModel.setPhoto(img)
                }
                pickerSelection = nil
            }
        }
    }

    // MARK: - Top + Bottom Bars

    private var topBar: some View {
        ModernPageHeader(
            title: "Log a Catch",
            leadingIcon: "xmark",
            trailingIcon: nil,
            showsIndicator: true,
            onLeadingTap: { dismiss() },
            onTrailingTap: nil
        )
    }

    private var bottomBar: some View {
        VStack(spacing: theme.spacing.xs) {
            Divider().background(theme.colors.brand.brassGold.opacity(0.2))
            HStack(spacing: theme.spacing.s) {
                if currentStep > 1 {
                    GhostButton(title: "Back", icon: "chevron.left") {
                        withAnimation(theme.motion.standard) { currentStep -= 1 }
                    }
                }
                Spacer()
                if currentStep < totalSteps {
                    PirateButton(title: nextLabel, icon: nextIcon, fullWidth: false) {
                        guard canAdvance else {
                            viewModel.showError = true
                            viewModel.errorMessage = advanceBlocker
                            return
                        }
                        withAnimation(theme.motion.standard) { currentStep += 1 }
                    }
                } else {
                    PirateButton(title: "Cast Your Claim", icon: "anchor", fullWidth: true) {
                        Task { await viewModel.submitCatch() }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.top, theme.spacing.s)
            .padding(.bottom, theme.spacing.m)
        }
        .background(theme.colors.surface.elevated)
    }

    private var nextLabel: String {
        switch currentStep {
        case 1: "I'm Here"
        case 2: "Looks Good"
        case 3: "Continue"
        default: "Next"
        }
    }

    private var nextIcon: String {
        switch currentStep {
        case 1: "mappin.circle.fill"
        case 2: "camera.fill"
        case 3: "sparkles"
        default: "chevron.right"
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 1: return !viewModel.selectedSpotId.isEmpty
        case 2: return viewModel.catchPhoto != nil
        case 3: return !viewModel.species.isEmpty && viewModel.sizeValueDouble > 0
        default: return true
        }
    }

    private var advanceBlocker: String {
        switch currentStep {
        case 1: return "Pick a spot to fish at."
        case 2: return "Snap or pick a photo of your catch."
        case 3: return "Add the species and size."
        default: return ""
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                switch currentStep {
                case 1: spotStep
                case 2: catchStep
                case 3: identifyStep
                case 4: submitStep
                default: EmptyView()
                }
            }
            .padding(theme.spacing.m)
            .padding(.bottom, theme.spacing.lg)
        }
    }

    // STEP 1 — SPOT
    private var spotStep: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            stepHeader(
                title: "Where are you fishing?",
                subtitle: "Pick a known spot or claim a new one."
            )
            if let spot = viewModel.selectedSpot {
                spotCard(spot: spot)
            } else {
                EmptyStateView(
                    icon: "mappin.and.ellipse",
                    title: "No spot selected",
                    message: "Tap below to choose a fishing spot."
                )
                .frame(height: 220)
            }
            PirateButton(title: "Pick a Spot", icon: "list.bullet.below.rectangle", fullWidth: true) {
                viewModel.showSpotPicker = true
            }
        }
    }

    private func spotCard(spot: Spot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: theme.spacing.s) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [theme.colors.brand.tideTeal, theme.colors.brand.deepSea], startPoint: .top, endPoint: .bottom))
                        .frame(width: 48, height: 48)
                    Image(systemName: spot.waterType?.icon ?? "drop.fill")
                        .foregroundStyle(theme.colors.brand.parchment)
                        .font(.system(size: 20, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.name)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                    if let region = spot.regionName {
                        Text(region)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.text.secondary)
                    }
                }
                Spacer()
                if spot.hasKing { CrownBadge(size: .medium) }
            }
            if let bestDisplay = spot.bestCatchDisplay {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(theme.colors.brand.crown)
                        .font(.system(size: 12, weight: .black))
                    Text("Current record: \(bestDisplay)")
                        .font(theme.typography.subhead)
                        .foregroundStyle(theme.colors.text.secondary)
                }
            }
        }
        .padding(theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.35), lineWidth: 1)
        )
    }

    // STEP 2 — CATCH (photo)
    private var catchStep: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            stepHeader(title: "Show your catch", subtitle: "A clear side photo helps identification.")
            ZStack {
                RoundedRectangle(cornerRadius: theme.radius.card)
                    .fill(theme.colors.surface.elevated)
                    .frame(height: 260)
                if let img = viewModel.catchPhoto {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "fish")
                            .font(.system(size: 56))
                            .foregroundStyle(theme.colors.brand.tideTeal.opacity(0.7))
                        Text("Tap below to snap or pick a photo")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.text.secondary)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card)
                    .strokeBorder(theme.colors.brand.brassGold.opacity(0.25), lineWidth: 1)
            )

            HStack(spacing: theme.spacing.s) {
                PhotosPicker(selection: $pickerSelection, matching: .images) {
                    HStack(spacing: theme.spacing.xs) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Library")
                            .font(theme.typography.headline)
                    }
                    .foregroundStyle(theme.colors.brand.brassGold)
                    .padding(.horizontal, theme.spacing.m)
                    .padding(.vertical, theme.spacing.s + 2)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                            .fill(theme.colors.surface.elevated.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                            .strokeBorder(theme.colors.brand.brassGold.opacity(0.7), lineWidth: 1.25)
                    )
                }
                GhostButton(title: "AR Measure", icon: "ruler.fill") {
                    viewModel.showMeasurement = true
                }
            }

            if viewModel.measuredWithAR, !viewModel.sizeValue.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(theme.colors.state.success)
                    Text("AR measured: \(viewModel.sizeValue) cm")
                        .font(theme.typography.subhead)
                        .foregroundStyle(theme.colors.text.secondary)
                }
            }
        }
    }

    // STEP 3 — IDENTIFY
    private var identifyStep: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            stepHeader(title: "What did you catch?", subtitle: "Use AI ID or pick from the list.")

            GhostButton(title: "Auto-Identify with AI ✨", icon: "sparkles", fullWidth: true) {
                viewModel.showFishID = true
            }

            Text("Species")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.secondary)

            Menu {
                ForEach(CommonFishSpecies.allCases, id: \.self) { species in
                    Button(species.rawValue) { viewModel.species = species.rawValue }
                }
            } label: {
                HStack {
                    Text(viewModel.species.isEmpty ? "Tap to pick" : viewModel.species)
                        .foregroundStyle(viewModel.species.isEmpty ? theme.colors.text.muted : theme.colors.text.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(theme.colors.text.secondary)
                }
                .font(theme.typography.body)
                .padding(theme.spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.button)
                        .fill(theme.colors.surface.elevatedAlt)
                )
            }

            Text("Length")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.secondary)

            HStack(spacing: theme.spacing.s) {
                TextField("0.0", text: $viewModel.sizeValue)
                    .keyboardType(.decimalPad)
                    .padding(theme.spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius.button)
                            .fill(theme.colors.surface.elevatedAlt)
                    )
                    .foregroundStyle(theme.colors.text.primary)
                    .font(theme.typography.body)
                Picker("Unit", selection: $viewModel.sizeUnit) {
                    ForEach(SizeUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }

    // STEP 4 — SUBMIT
    private var submitStep: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            stepHeader(title: "Cast your claim", subtitle: "Final check, then send it.")

            // Summary card
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                if let img = viewModel.catchPhoto {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card))
                }
                summaryRow(label: "Spot", value: viewModel.selectedSpot?.name ?? "—")
                summaryRow(label: "Species", value: viewModel.species.isEmpty ? "—" : viewModel.species)
                summaryRow(label: "Length", value: viewModel.sizeValue.isEmpty ? "—" : "\(viewModel.sizeValue) \(viewModel.sizeUnit.rawValue)")
                let r = progression.computeReward(
                    sizeCm: viewModel.sizeValueDouble,
                    isDethrone: dethronePreview,
                    isRareSpecies: false,
                    isFirstAtSpot: false
                )
                Divider().background(theme.colors.brand.brassGold.opacity(0.18))
                HStack {
                    Text("Reward preview")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.text.secondary)
                    Spacer()
                    DoubloonChip(amount: r.doubloons, size: .medium)
                }
                if dethronePreview {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.colors.brand.coralRed)
                        Text("DETHRONE IMMINENT — bigger than the current king!")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.colors.brand.coralRed)
                    }
                }
            }
            .padding(theme.spacing.m)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.card)
                    .fill(theme.colors.surface.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card)
                    .strokeBorder(dethronePreview ? theme.colors.brand.coralRed : theme.colors.brand.brassGold.opacity(0.35), lineWidth: dethronePreview ? 2 : 1)
            )

            // Privacy
            HStack {
                Text("Visibility")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.secondary)
                Spacer()
                Picker("", selection: $viewModel.visibility) {
                    ForEach(CatchVisibility.allCases, id: \.self) { v in
                        Text(v.rawValue.capitalized).tag(v)
                    }
                }
                .pickerStyle(.menu)
                .tint(theme.colors.brand.brassGold)
            }
            .padding(theme.spacing.s)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.button)
                    .fill(theme.colors.surface.elevated)
            )
        }
    }

    private var dethronePreview: Bool {
        guard let bestSize = viewModel.selectedSpot?.currentBestSize else { return false }
        return viewModel.sizeValueDouble > bestSize
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(theme.typography.title1)
                .foregroundStyle(theme.colors.text.primary)
            Text(subtitle)
                .font(theme.typography.subhead)
                .foregroundStyle(theme.colors.text.secondary)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.secondary)
            Spacer()
            Text(value)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.text.primary)
                .lineLimit(1)
        }
    }
}
