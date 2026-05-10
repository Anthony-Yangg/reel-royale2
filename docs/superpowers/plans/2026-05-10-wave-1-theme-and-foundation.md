# Reel Royale Wave 1 — Theme & Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay down the design system (tokens, motion, sound, haptics) and core primitive components, wrap the existing app in the new tab shell with a sticky identity header and center FAB — without breaking any existing functionality.

**Architecture:** Layered redesign. Existing MVVM (ViewModels/Repositories/Services) untouched. New `Theme/` module exposes a `ReelTheme` environment object. New `Services/SoundService.swift` + `Services/HapticsService.swift` for feedback primitives. New components live in `Views/Components/` alongside the existing ones. The existing `MainTabView` is wrapped in a new `TabBarShell` that renders the custom tab bar, center ⚓ FAB (opens existing `LogCatchView` unchanged), and an `IdentityHeader` on each primary tab.

**Tech Stack:** SwiftUI (iOS 17+), AVFoundation (sound), UIKit (`UIImpactFeedbackGenerator` for haptics), Supabase Swift SDK (unchanged).

**Testing approach:** Wave 1 deliverables are presentational primitives and design tokens. We rely on:
1. Comprehensive `#Preview` blocks for visual verification.
2. `xcodebuild` build success after every task (catches type errors).
3. Manual simulator run at end (visual confirmation).
4. Formal `XCTest` unit tests are introduced in Wave 4 when `ProgressionService` (pure logic) is built. Skipping for Wave 1 avoids forcing the engineer to wire up an Xcode test target for views that are trivially visually verifiable.

**Acceptance criteria (end of Wave 1):**
- App builds without errors (`xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build`).
- App launches and lands on existing screens (Spots default).
- New dark pirate-themed tab bar visible with center anchor FAB.
- Tapping FAB opens existing `LogCatchView` modal.
- Sticky `IdentityHeader` renders on Spots, Community, Profile, More tabs with mock identity data sourced from `AppState.currentUser`.
- All previously working flows (auth, log catch, profile, etc.) continue to work.
- Light-mode regression: app forces dark color scheme (the entire design assumes dark — light mode would look broken).

---

## File Structure

**New files** (created in tasks below):

```
ReelRoyale/Theme/
├── ReelThemeColors.swift
├── ReelThemeTypography.swift
├── ReelThemeSpacing.swift
├── ReelThemeRadius.swift
├── ReelThemeShadow.swift
├── ReelThemeMotion.swift
└── ReelTheme.swift

ReelRoyale/Services/
├── HapticsService.swift
└── SoundService.swift

ReelRoyale/Views/Components/
├── PirateButton.swift
├── GhostButton.swift
├── IconButton.swift
├── DoubloonChip.swift
├── TierEmblem.swift
├── ShipAvatar.swift
└── IdentityHeader.swift

ReelRoyale/Views/Shell/
├── TabBarShell.swift
└── CenterFAB.swift
```

**Modified files:**
- `ReelRoyale/ReelRoyaleApp.swift` — inject theme env, update appearance config
- `ReelRoyale/Utilities/AppState.swift` — add `.home` case to `AppTab`, expose `SoundService` + `HapticsService`
- `ReelRoyale/Views/MainTabView.swift` — wrap in `TabBarShell` + render `IdentityHeader`
- `ReelRoyale/Views/Components/CrownBadge.swift` — refactor to use theme (keep behavior)
- `ReelRoyale/Views/Components/LoadingView.swift` — refactor to use theme + add pirate `ShipWheelSpinner` style
- `ReelRoyale/Models/User.swift` — add `tier`, `crownsHeld`, `doubloons`, `seasonRank` cached display fields (defaults only; persistence comes in later waves)

---

## Conventions used throughout this plan

- **Theme access in views:** `@Environment(\.reelTheme) private var theme` then read `theme.colors.brand.brassGold` etc.
- **No hardcoded hex colors** outside the theme files.
- **Previews:** every component file MUST have a `#Preview` that demonstrates all variants on a `theme.colors.bg.canvas` background.
- **Build command:** `xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20` after each task. Expected: ends with `** BUILD SUCCEEDED **`.
- **Commit cadence:** commit after each task with a tight conventional message (`feat(theme): add ReelThemeColors`, etc.)
- **Worktree:** all work happens in this branch `claude/sad-bartik-49775b`.

---

## Task 1: Create `ReelThemeColors`

**Files:**
- Create: `ReelRoyale/Theme/ReelThemeColors.swift`

- [ ] **Step 1: Create the theme directory and file**

Create `ReelRoyale/Theme/ReelThemeColors.swift` with the following content:

```swift
import SwiftUI

/// Semantic color tokens for Reel Royale.
/// Never reference these as raw hex outside this file — always via `theme.colors.*`.
struct ReelThemeColors {
    let surface: Surface
    let brand: Brand
    let text: TextColors
    let state: StateColors
    let tier: TierColors

    struct Surface {
        let canvas: Color          // primary background (near-black navy)
        let elevated: Color        // cards, sheets
        let elevatedAlt: Color     // nested cards, headers
        let parchment: Color       // light/inverse surfaces — map land, onboarding
        let scrim: Color           // dim overlay behind modals
    }

    struct Brand {
        let deepSea: Color         // primary brand teal
        let tideTeal: Color        // mid teal — interactive accents
        let seafoam: Color         // bright teal — highlights / focus
        let brassGold: Color       // gold — emblems, doubloons, CTAs
        let crown: Color           // bright gold — winning / kings
        let coralRed: Color        // coral — dethrone / danger / alert
        let walnut: Color          // dark wood — frames, banners
        let parchment: Color       // aged paper accent on dark
    }

    struct TextColors {
        let primary: Color
        let secondary: Color
        let muted: Color
        let onLight: Color
        let accent: Color
    }

    struct StateColors {
        let success: Color
        let danger: Color
        let warning: Color
    }

    struct TierColors {
        let deckhand: Color
        let sailor: Color
        let firstMate: Color
        let captain: Color
        let commodore: Color
        let admiral: Color
        let pirateLord: Color
    }

    static let `default` = ReelThemeColors(
        surface: Surface(
            canvas:       Color(hex: 0x0A1822),
            elevated:     Color(hex: 0x14222F),
            elevatedAlt:  Color(hex: 0x1B2D3D),
            parchment:    Color(hex: 0xF4E8D0),
            scrim:        Color.black.opacity(0.55)
        ),
        brand: Brand(
            deepSea:    Color(hex: 0x0E2C44),
            tideTeal:   Color(hex: 0x1F6F7A),
            seafoam:    Color(hex: 0x3FB8AE),
            brassGold:  Color(hex: 0xC9A24B),
            crown:      Color(hex: 0xF2C95C),
            coralRed:   Color(hex: 0xD8553C),
            walnut:     Color(hex: 0x4A2E1D),
            parchment:  Color(hex: 0xE8D9B0)
        ),
        text: TextColors(
            primary:   Color(hex: 0xF0E6D2),
            secondary: Color(hex: 0xA99E83),
            muted:     Color(hex: 0x6E6353),
            onLight:   Color(hex: 0x1B2D3D),
            accent:    Color(hex: 0xF2C95C)
        ),
        state: StateColors(
            success: Color(hex: 0x4FC28A),
            danger:  Color(hex: 0xD8553C),
            warning: Color(hex: 0xE5A547)
        ),
        tier: TierColors(
            deckhand:   Color(hex: 0x8B7355),
            sailor:     Color(hex: 0xB0925E),
            firstMate:  Color(hex: 0xC9A24B),
            captain:    Color(hex: 0xE5C04A),
            commodore:  Color(hex: 0x6FA8E8),
            admiral:    Color(hex: 0xB47EFF),
            pirateLord: Color(hex: 0xF2C95C)
        )
    )
}

/// Convenience initializer for hex literals.
extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected: ends with `** BUILD SUCCEEDED **`.

If it fails with `error: cannot find 'Color' in scope`, the file is missing `import SwiftUI`. If it fails on `Color(hex:)`, check the extension is in the same file.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Theme/ReelThemeColors.swift
git commit -m "feat(theme): add ReelThemeColors semantic tokens"
```

---

## Task 2: Create `ReelThemeTypography`

**Files:**
- Create: `ReelRoyale/Theme/ReelThemeTypography.swift`

- [ ] **Step 1: Write the typography token file**

Create `ReelRoyale/Theme/ReelThemeTypography.swift`:

```swift
import SwiftUI

/// Typography tokens. Display/Title use SF Pro Rounded (warmer, game-feel).
/// Body uses standard SF Pro (legibility). Mono for stats.
struct ReelThemeTypography {
    let display: Font     // hero numbers, podium positions
    let title1: Font      // page titles
    let title2: Font      // section titles
    let headline: Font    // card titles
    let body: Font
    let subhead: Font
    let caption: Font
    let mono: Font        // numbers / stats

    static let `default` = ReelThemeTypography(
        display:  .system(size: 56, weight: .black,    design: .rounded),
        title1:   .system(size: 34, weight: .bold,     design: .rounded),
        title2:   .system(size: 22, weight: .bold,     design: .rounded),
        headline: .system(size: 17, weight: .semibold, design: .default),
        body:     .system(size: 17, weight: .regular,  design: .default),
        subhead:  .system(size: 15, weight: .medium,   design: .default),
        caption:  .system(size: 13, weight: .medium,   design: .default),
        mono:     .system(size: 15, weight: .medium,   design: .monospaced)
    )
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Theme/ReelThemeTypography.swift
git commit -m "feat(theme): add ReelThemeTypography tokens"
```

---

## Task 3: Create `ReelThemeSpacing` and `ReelThemeRadius`

**Files:**
- Create: `ReelRoyale/Theme/ReelThemeSpacing.swift`
- Create: `ReelRoyale/Theme/ReelThemeRadius.swift`

- [ ] **Step 1: Write spacing tokens**

Create `ReelRoyale/Theme/ReelThemeSpacing.swift`:

```swift
import Foundation

/// 4pt spacing grid.
struct ReelThemeSpacing {
    let xxs: CGFloat   // 4
    let xs: CGFloat    // 8
    let s: CGFloat     // 12
    let m: CGFloat     // 16
    let lg: CGFloat    // 20
    let xl: CGFloat    // 24
    let xxl: CGFloat   // 32
    let xxxl: CGFloat  // 40
    let huge: CGFloat  // 56
    let massive: CGFloat // 80

    static let `default` = ReelThemeSpacing(
        xxs: 4, xs: 8, s: 12, m: 16, lg: 20,
        xl: 24, xxl: 32, xxxl: 40, huge: 56, massive: 80
    )
}
```

- [ ] **Step 2: Write radius tokens**

Create `ReelRoyale/Theme/ReelThemeRadius.swift`:

```swift
import Foundation

/// Corner radius scale.
struct ReelThemeRadius {
    let chip: CGFloat      // 6
    let button: CGFloat    // 12
    let card: CGFloat      // 18
    let heroCard: CGFloat  // 24
    let modal: CGFloat     // 32

    static let `default` = ReelThemeRadius(
        chip: 6, button: 12, card: 18, heroCard: 24, modal: 32
    )
}
```

- [ ] **Step 3: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ReelRoyale/Theme/ReelThemeSpacing.swift ReelRoyale/Theme/ReelThemeRadius.swift
git commit -m "feat(theme): add spacing + radius tokens"
```

---

## Task 4: Create `ReelThemeShadow` and `ReelThemeMotion`

**Files:**
- Create: `ReelRoyale/Theme/ReelThemeShadow.swift`
- Create: `ReelRoyale/Theme/ReelThemeMotion.swift`

- [ ] **Step 1: Write shadow tokens**

Create `ReelRoyale/Theme/ReelThemeShadow.swift`:

```swift
import SwiftUI

/// Shadow tokens for elevation.
struct ReelThemeShadow {
    let card: Shadow
    let heroCard: Shadow
    let modal: Shadow

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static let `default` = ReelThemeShadow(
        card:     Shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 4),
        heroCard: Shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 8),
        modal:    Shadow(color: Color.black.opacity(0.60), radius: 32, x: 0, y: 12)
    )
}

extension View {
    /// Apply a `ReelThemeShadow.Shadow`.
    func reelShadow(_ shadow: ReelThemeShadow.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
```

- [ ] **Step 2: Write motion tokens**

Create `ReelRoyale/Theme/ReelThemeMotion.swift`:

```swift
import SwiftUI

/// Motion tokens. Honor `reduceMotion` env at call sites.
struct ReelThemeMotion {
    let fast: Animation       // 180ms easeOut — taps
    let standard: Animation   // 320ms spring — transitions
    let hero: Animation       // 600ms spring — page transitions, podium
    let cinematic: Animation  // 1200ms — dethrone, tier-up
    let ambientDuration: Double  // base loop duration for ambient anims (seconds)

    static let `default` = ReelThemeMotion(
        fast:      .easeOut(duration: 0.18),
        standard:  .spring(response: 0.32, dampingFraction: 0.78),
        hero:      .spring(response: 0.60, dampingFraction: 0.72),
        cinematic: .easeInOut(duration: 1.20),
        ambientDuration: 6.0
    )
}
```

- [ ] **Step 3: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ReelRoyale/Theme/ReelThemeShadow.swift ReelRoyale/Theme/ReelThemeMotion.swift
git commit -m "feat(theme): add shadow + motion tokens"
```

---

## Task 5: Create `ReelTheme` composite + EnvironmentKey

**Files:**
- Create: `ReelRoyale/Theme/ReelTheme.swift`

- [ ] **Step 1: Write the composite + env key**

Create `ReelRoyale/Theme/ReelTheme.swift`:

```swift
import SwiftUI

/// Top-level theme bundle. Inject into the environment at app root.
struct ReelTheme {
    let colors: ReelThemeColors
    let typography: ReelThemeTypography
    let spacing: ReelThemeSpacing
    let radius: ReelThemeRadius
    let shadow: ReelThemeShadow
    let motion: ReelThemeMotion

    static let `default` = ReelTheme(
        colors:     .default,
        typography: .default,
        spacing:    .default,
        radius:     .default,
        shadow:     .default,
        motion:     .default
    )
}

private struct ReelThemeKey: EnvironmentKey {
    static let defaultValue: ReelTheme = .default
}

extension EnvironmentValues {
    var reelTheme: ReelTheme {
        get { self[ReelThemeKey.self] }
        set { self[ReelThemeKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Theme/ReelTheme.swift
git commit -m "feat(theme): add ReelTheme composite + environment key"
```

---

## Task 6: Inject theme + force dark scheme at app root

**Files:**
- Modify: `ReelRoyale/ReelRoyaleApp.swift`

- [ ] **Step 1: Replace the app root**

Replace the contents of `ReelRoyale/ReelRoyaleApp.swift` with:

```swift
import SwiftUI

@main
struct ReelRoyaleApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        AppState.shared.configure()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.reelTheme, .default)
                .preferredColorScheme(.dark)
        }
    }

    private func configureAppearance() {
        let theme = ReelTheme.default

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(theme.colors.surface.canvas)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(theme.colors.text.primary)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(theme.colors.text.primary)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(theme.colors.brand.seafoam)

        // Tab bar — Wave 1 keeps system tab bar for fallback; Wave 1 shell hides it where applied
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(theme.colors.surface.canvas)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(theme.colors.brand.seafoam)
        UITabBar.appearance().unselectedItemTintColor = UIColor(theme.colors.text.secondary)
    }
}
```

- [ ] **Step 2: Verify the app launches with theme**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

Manual: run on simulator, confirm app launches without crash. Background should already feel darker / navy.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/ReelRoyaleApp.swift
git commit -m "feat(theme): inject ReelTheme at app root and force dark scheme"
```

---

## Task 7: Add `HapticsService`

**Files:**
- Create: `ReelRoyale/Services/HapticsService.swift`

- [ ] **Step 1: Define the protocol + implementation**

Create `ReelRoyale/Services/HapticsService.swift`:

```swift
import UIKit

/// Single source of haptic feedback. Honors a user-toggleable mute state.
protocol HapticsServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }

    func tap()        // .soft  — generic tap
    func confirm()    // .medium — confirmed action
    func heavy()      // .heavy  — big moment (dethrone, tier-up)
    func success()    // notification.success
    func warning()    // notification.warning
    func error()      // notification.error
}

final class HapticsService: HapticsServiceProtocol {
    var isEnabled: Bool = true

    private let softGenerator   = UIImpactFeedbackGenerator(style: .soft)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator  = UIImpactFeedbackGenerator(style: .heavy)
    private let notification    = UINotificationFeedbackGenerator()

    init() {
        // Prime generators for low-latency first hit
        softGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notification.prepare()
    }

    func tap() {
        guard isEnabled else { return }
        softGenerator.impactOccurred()
        softGenerator.prepare()
    }

    func confirm() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    func heavy() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        heavyGenerator.prepare()
    }

    func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
        notification.prepare()
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Services/HapticsService.swift
git commit -m "feat(services): add HapticsService"
```

---

## Task 8: Add `SoundService` (stub for Wave 1, real assets land in Wave 4)

**Files:**
- Create: `ReelRoyale/Services/SoundService.swift`

- [ ] **Step 1: Define the protocol + stub implementation**

Create `ReelRoyale/Services/SoundService.swift`:

```swift
import AVFoundation

/// SFX library. Wave 1 ships the API; real audio assets are wired in Wave 4/6.
enum SoundEffect: String, CaseIterable {
    case tap             = "tap"
    case confirm         = "confirm"
    case coinShower      = "coin_shower"
    case cannonBoom      = "cannon_boom"
    case crownShatter    = "crown_shatter"
    case seaShantyHorn   = "sea_shanty_horn"
    case brassChime      = "brass_chime"
    case bellRing        = "bell_ring"
    case lowThud         = "low_thud"
    case ropeCreak       = "rope_creak"
}

protocol SoundServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }
    func play(_ effect: SoundEffect)
    func stopAll()
}

final class SoundService: SoundServiceProtocol {
    var isEnabled: Bool = true

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        configureSession()
    }

    private func configureSession() {
        // Ambient = mixes with other audio (user might be on a fishing podcast)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        if let player = players[effect] {
            player.currentTime = 0
            player.play()
            return
        }
        guard let url = bundle.url(forResource: effect.rawValue, withExtension: "m4a") ?? bundle.url(forResource: effect.rawValue, withExtension: "wav") else {
            // Asset not bundled yet (Wave 1 stub). Silently no-op.
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[effect] = player
            player.play()
        } catch {
            // No assets yet; ignore.
        }
    }

    func stopAll() {
        players.values.forEach { $0.stop() }
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Services/SoundService.swift
git commit -m "feat(services): add SoundService stub (no assets yet)"
```

---

## Task 9: Wire `HapticsService` + `SoundService` into `AppState`

**Files:**
- Modify: `ReelRoyale/Utilities/AppState.swift`

- [ ] **Step 1: Add service properties + init**

Open `ReelRoyale/Utilities/AppState.swift`. In the `AppState` class, find the existing block of service declarations (around line 41-54). Add two new lines below the existing `imageUploadService` line:

Replace this block:
```swift
    private(set) var supabaseService: SupabaseService!
    private(set) var authService: AuthServiceProtocol!
    private(set) var userRepository: UserRepositoryProtocol!
    private(set) var spotRepository: SpotRepositoryProtocol!
    private(set) var catchRepository: CatchRepositoryProtocol!
    private(set) var territoryRepository: TerritoryRepositoryProtocol!
    private(set) var likeRepository: LikeRepositoryProtocol!
    private(set) var weatherService: WeatherServiceProtocol!
    private(set) var regulationsService: RegulationsServiceProtocol!
    private(set) var fishIDService: FishIDServiceProtocol!
    private(set) var measurementService: MeasurementServiceProtocol!
    private(set) var gameService: GameServiceProtocol!
    private(set) var imageUploadService: ImageUploadServiceProtocol!
```

with:

```swift
    private(set) var supabaseService: SupabaseService!
    private(set) var authService: AuthServiceProtocol!
    private(set) var userRepository: UserRepositoryProtocol!
    private(set) var spotRepository: SpotRepositoryProtocol!
    private(set) var catchRepository: CatchRepositoryProtocol!
    private(set) var territoryRepository: TerritoryRepositoryProtocol!
    private(set) var likeRepository: LikeRepositoryProtocol!
    private(set) var weatherService: WeatherServiceProtocol!
    private(set) var regulationsService: RegulationsServiceProtocol!
    private(set) var fishIDService: FishIDServiceProtocol!
    private(set) var measurementService: MeasurementServiceProtocol!
    private(set) var gameService: GameServiceProtocol!
    private(set) var imageUploadService: ImageUploadServiceProtocol!
    private(set) var haptics: HapticsServiceProtocol!
    private(set) var sounds: SoundServiceProtocol!
```

Then in the `configure()` method, find the line `// Initialize services`. Replace the block from `// Initialize services` down through `gameService = GameService(...)` line with:

```swift
        // Initialize services
        authService = SupabaseAuthService(supabase: supabaseService, userRepository: userRepository)
        weatherService = OpenWeatherService()
        regulationsService = SupabaseRegulationsService(supabase: supabaseService)
        fishIDService = CoreMLFishIDService()
        measurementService = ARMeasurementService()
        imageUploadService = SupabaseImageUploadService(supabase: supabaseService)
        gameService = GameService(
            spotRepository: spotRepository,
            catchRepository: catchRepository,
            territoryRepository: territoryRepository
        )
        haptics = HapticsService()
        sounds = SoundService()
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Utilities/AppState.swift
git commit -m "feat(state): wire HapticsService + SoundService into AppState"
```

---

## Task 10: Add `PirateButton` (primary action button)

**Files:**
- Create: `ReelRoyale/Views/Components/PirateButton.swift`

- [ ] **Step 1: Create the component**

Create `ReelRoyale/Views/Components/PirateButton.swift`:

```swift
import SwiftUI

/// Primary CTA button — brass-gold gradient, walnut border, press animation, haptic on tap.
struct PirateButton: View {
    let title: String
    var icon: String? = nil          // SF Symbol name
    var fullWidth: Bool = false
    var isLoading: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false

    var body: some View {
        Button {
            appState.haptics?.confirm()
            action()
        } label: {
            HStack(spacing: theme.spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(theme.colors.text.onLight)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(title)
                        .font(theme.typography.headline)
                }
            }
            .foregroundStyle(theme.colors.text.onLight)
            .padding(.horizontal, theme.spacing.xl)
            .padding(.vertical, theme.spacing.s + 2)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isDestructive
                                ? [theme.colors.brand.coralRed, theme.colors.brand.coralRed.opacity(0.85)]
                                : [theme.colors.brand.crown, theme.colors.brand.brassGold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .strokeBorder(theme.colors.brand.walnut, lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .reelShadow(theme.shadow.card)
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
        .disabled(isLoading)
    }
}

/// Tracks press state for any button.
struct PressFeedbackStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, new in
                isPressed = new
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        PirateButton(title: "Cast Your Claim", icon: "anchor") {}
        PirateButton(title: "Full Width", fullWidth: true) {}
        PirateButton(title: "Loading", isLoading: true) {}
        PirateButton(title: "Dethrone", icon: "crown.fill", isDestructive: true) {}
        PirateButton(title: "Disabled") {}.disabled(true)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Components/PirateButton.swift
git commit -m "feat(components): add PirateButton"
```

---

## Task 11: Add `GhostButton` (secondary outlined variant)

**Files:**
- Create: `ReelRoyale/Views/Components/GhostButton.swift`

- [ ] **Step 1: Create the component**

Create `ReelRoyale/Views/Components/GhostButton.swift`:

```swift
import SwiftUI

/// Secondary outlined button. Brass-gold border on transparent background.
struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = false
    let action: () -> Void

    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false

    var body: some View {
        Button {
            appState.haptics?.tap()
            action()
        } label: {
            HStack(spacing: theme.spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(theme.typography.headline)
            }
            .foregroundStyle(theme.colors.brand.brassGold)
            .padding(.horizontal, theme.spacing.xl)
            .padding(.vertical, theme.spacing.s + 2)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .fill(theme.colors.surface.elevated.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .strokeBorder(theme.colors.brand.brassGold.opacity(0.7), lineWidth: 1.25)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        GhostButton(title: "Open Map", icon: "map") {}
        GhostButton(title: "Full Width", fullWidth: true) {}
        GhostButton(title: "Disabled") {}.disabled(true)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Components/GhostButton.swift
git commit -m "feat(components): add GhostButton"
```

---

## Task 12: Add `IconButton` (round icon-only button)

**Files:**
- Create: `ReelRoyale/Views/Components/IconButton.swift`

- [ ] **Step 1: Create the component**

Create `ReelRoyale/Views/Components/IconButton.swift`:

```swift
import SwiftUI

/// Round icon-only button. Used in nav bars, cards, etc.
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 44
    var fillStyle: FillStyle = .elevated
    let action: () -> Void

    enum FillStyle {
        case elevated   // dark filled circle
        case ghost      // outlined transparent
        case brass      // gold filled
    }

    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState
    @State private var isPressed = false

    var body: some View {
        Button {
            appState.haptics?.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(backgroundFill)
                )
                .overlay(
                    Circle().strokeBorder(borderColor, lineWidth: fillStyle == .ghost ? 1.25 : 0)
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
    }

    private var foregroundColor: Color {
        switch fillStyle {
        case .elevated: return theme.colors.text.primary
        case .ghost:    return theme.colors.brand.brassGold
        case .brass:    return theme.colors.text.onLight
        }
    }

    private var backgroundFill: AnyShapeStyle {
        switch fillStyle {
        case .elevated:
            return AnyShapeStyle(theme.colors.surface.elevatedAlt)
        case .ghost:
            return AnyShapeStyle(Color.clear)
        case .brass:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    private var borderColor: Color {
        switch fillStyle {
        case .ghost: return theme.colors.brand.brassGold.opacity(0.6)
        default: return .clear
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        IconButton(systemName: "plus", fillStyle: .elevated) {}
        IconButton(systemName: "camera.fill", fillStyle: .ghost) {}
        IconButton(systemName: "anchor", fillStyle: .brass) {}
        IconButton(systemName: "magnifyingglass", size: 36, fillStyle: .elevated) {}
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Components/IconButton.swift
git commit -m "feat(components): add IconButton"
```

---

## Task 13: Add `CaptainTier` enum + `TierEmblem`

**Files:**
- Create: `ReelRoyale/Views/Components/TierEmblem.swift`
- (CaptainTier enum lives in this file for Wave 1; can move to `Models/` in Wave 5 when persistence lands.)

- [ ] **Step 1: Create the file**

Create `ReelRoyale/Views/Components/TierEmblem.swift`:

```swift
import SwiftUI

/// Captain progression tier (Deckhand → Pirate Lord).
enum CaptainTier: Int, Codable, CaseIterable, Identifiable {
    case deckhand   = 0
    case sailor     = 1
    case firstMate  = 2
    case captain    = 3
    case commodore  = 4
    case admiral    = 5
    case pirateLord = 6

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .deckhand:   return "Deckhand"
        case .sailor:     return "Sailor"
        case .firstMate:  return "First Mate"
        case .captain:    return "Captain"
        case .commodore:  return "Commodore"
        case .admiral:    return "Admiral"
        case .pirateLord: return "Pirate Lord"
        }
    }

    /// SF Symbol used for the emblem chevron count visual.
    var chevronCount: Int { rawValue + 1 } // Deckhand 1 ... Pirate Lord 7
}

extension ReelThemeColors.TierColors {
    func color(for tier: CaptainTier) -> Color {
        switch tier {
        case .deckhand:   return deckhand
        case .sailor:     return sailor
        case .firstMate:  return firstMate
        case .captain:    return captain
        case .commodore:  return commodore
        case .admiral:    return admiral
        case .pirateLord: return pirateLord
        }
    }
}

/// Tier emblem badge: chevrons + name, tinted by tier color.
struct TierEmblem: View {
    let tier: CaptainTier
    var division: Int = 1   // 1, 2, or 3 within tier (display only in Wave 1)
    var size: Size = .medium

    enum Size {
        case small, medium, large
        var fontSize: CGFloat {
            switch self { case .small: 11; case .medium: 13; case .large: 17 }
        }
        var chevronSize: CGFloat {
            switch self { case .small: 8; case .medium: 10; case .large: 14 }
        }
        var hPad: CGFloat {
            switch self { case .small: 6; case .medium: 10; case .large: 14 }
        }
        var vPad: CGFloat {
            switch self { case .small: 3; case .medium: 4; case .large: 6 }
        }
    }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 1) {
                ForEach(0..<min(tier.chevronCount, 5), id: \.self) { _ in
                    Image(systemName: "chevron.up")
                        .font(.system(size: size.chevronSize, weight: .black))
                }
            }
            Text("\(tier.displayName)\(division > 1 ? " \(romanNumeral(division))" : "")")
                .font(.system(size: size.fontSize, weight: .heavy, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(theme.colors.tier.color(for: tier))
        .padding(.horizontal, size.hPad)
        .padding(.vertical, size.vPad)
        .background(
            Capsule(style: .continuous)
                .fill(theme.colors.surface.elevatedAlt)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(theme.colors.tier.color(for: tier).opacity(0.5), lineWidth: 1)
        )
    }

    private func romanNumeral(_ n: Int) -> String {
        switch n { case 1: "I"; case 2: "II"; case 3: "III"; default: "" }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(CaptainTier.allCases) { tier in
            TierEmblem(tier: tier, division: 1, size: .medium)
        }
        TierEmblem(tier: .captain, division: 2, size: .small)
        TierEmblem(tier: .admiral, division: 3, size: .large)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Components/TierEmblem.swift
git commit -m "feat(components): add CaptainTier enum + TierEmblem"
```

---

## Task 14: Add `DoubloonChip` (points display chip)

**Files:**
- Create: `ReelRoyale/Views/Components/DoubloonChip.swift`

- [ ] **Step 1: Create the component**

Create `ReelRoyale/Views/Components/DoubloonChip.swift`:

```swift
import SwiftUI

/// Inline coin + amount chip used in headers and stats.
struct DoubloonChip: View {
    let amount: Int
    var size: Size = .medium
    var compact: Bool = false  // omit background pill if true

    enum Size {
        case small, medium, large
        var fontSize: CGFloat { switch self { case .small: 12; case .medium: 15; case .large: 22 } }
        var coinSize: CGFloat { switch self { case .small: 12; case .medium: 16; case .large: 24 } }
        var hPad: CGFloat { switch self { case .small: 6; case .medium: 10; case .large: 14 } }
        var vPad: CGFloat { switch self { case .small: 3; case .medium: 5; case .large: 8 } }
    }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            CoinIcon(size: size.coinSize)
            Text(amount.formatted(.number.notation(.compactName)))
                .font(.system(size: size.fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.brand.crown)
                .monospacedDigit()
        }
        .padding(.horizontal, compact ? 0 : size.hPad)
        .padding(.vertical, compact ? 0 : size.vPad)
        .background(
            Group {
                if !compact {
                    Capsule(style: .continuous)
                        .fill(theme.colors.surface.elevatedAlt)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(theme.colors.brand.brassGold.opacity(0.35), lineWidth: 1)
                        )
                }
            }
        )
    }
}

/// The little doubloon coin glyph used inside DoubloonChip.
struct CoinIcon: View {
    let size: CGFloat
    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(theme.colors.brand.walnut.opacity(0.8), lineWidth: max(1, size * 0.06))
            Image(systemName: "dollarsign")
                .font(.system(size: size * 0.55, weight: .black))
                .foregroundStyle(theme.colors.brand.walnut)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 12) {
        DoubloonChip(amount: 234)
        DoubloonChip(amount: 12_450, size: .large)
        DoubloonChip(amount: 1_250_000, size: .small)
        DoubloonChip(amount: 5_678, compact: true)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Components/DoubloonChip.swift
git commit -m "feat(components): add DoubloonChip + CoinIcon"
```

---

## Task 15: Add `ShipAvatar` (avatar in tier-colored ship frame)

**Files:**
- Create: `ReelRoyale/Views/Components/ShipAvatar.swift`

- [ ] **Step 1: Create the component**

Create `ReelRoyale/Views/Components/ShipAvatar.swift`:

```swift
import SwiftUI

/// Avatar in a ship-frame medallion. Frame ring is tinted by tier color.
struct ShipAvatar: View {
    let imageURL: URL?
    let initial: String          // fallback shown when no image
    var tier: CaptainTier = .deckhand
    var size: Size = .medium
    var showCrown: Bool = false  // currently a king at any spot

    enum Size {
        case small, medium, large, hero

        var diameter: CGFloat {
            switch self {
            case .small: 36
            case .medium: 48
            case .large: 72
            case .hero: 112
            }
        }
        var ringWidth: CGFloat {
            switch self {
            case .small: 2
            case .medium: 2.5
            case .large: 3.5
            case .hero: 5
            }
        }
        var initialFont: Font {
            switch self {
            case .small:  .system(size: 14, weight: .heavy, design: .rounded)
            case .medium: .system(size: 18, weight: .heavy, design: .rounded)
            case .large:  .system(size: 26, weight: .heavy, design: .rounded)
            case .hero:   .system(size: 42, weight: .heavy, design: .rounded)
            }
        }
    }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            // Tier ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            theme.colors.tier.color(for: tier),
                            theme.colors.tier.color(for: tier).opacity(0.6)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: size.ringWidth
                )
                .frame(width: size.diameter, height: size.diameter)

            // Inner dark fill
            Circle()
                .fill(theme.colors.surface.elevatedAlt)
                .frame(width: size.diameter - size.ringWidth * 2, height: size.diameter - size.ringWidth * 2)

            // Avatar content
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(theme.colors.text.secondary)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initialView
                    @unknown default:
                        initialView
                    }
                }
                .frame(width: size.diameter - size.ringWidth * 2, height: size.diameter - size.ringWidth * 2)
                .clipShape(Circle())
            } else {
                initialView
            }

            // Crown overlay
            if showCrown {
                Image(systemName: "crown.fill")
                    .font(.system(size: size.diameter * 0.28, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .offset(y: -size.diameter * 0.48)
            }
        }
        .frame(width: size.diameter, height: size.diameter + (showCrown ? size.diameter * 0.18 : 0), alignment: .bottom)
    }

    private var initialView: some View {
        Text(initial.prefix(1).uppercased())
            .font(size.initialFont)
            .foregroundStyle(theme.colors.text.primary)
    }
}

#Preview {
    HStack(spacing: 16) {
        ShipAvatar(imageURL: nil, initial: "B", tier: .deckhand, size: .small)
        ShipAvatar(imageURL: nil, initial: "K", tier: .captain, size: .medium)
        ShipAvatar(imageURL: nil, initial: "R", tier: .admiral, size: .large, showCrown: true)
        ShipAvatar(imageURL: nil, initial: "P", tier: .pirateLord, size: .hero, showCrown: true)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Components/ShipAvatar.swift
git commit -m "feat(components): add ShipAvatar"
```

---

## Task 16: Refactor `CrownBadge` to use theme

**Files:**
- Modify: `ReelRoyale/Views/Components/CrownBadge.swift`

- [ ] **Step 1: Replace the file**

Replace `ReelRoyale/Views/Components/CrownBadge.swift` with:

```swift
import SwiftUI

/// Crown badge — used wherever someone is currently a king.
struct CrownBadge: View {
    let size: Size
    var isAnimated: Bool = false
    var showGlow: Bool = false

    enum Size {
        case small, medium, large
        var iconSize: CGFloat {
            switch self { case .small: 16; case .medium: 24; case .large: 36 }
        }
    }

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if showGlow {
                Image(systemName: "crown.fill")
                    .font(.system(size: size.iconSize * 1.3))
                    .foregroundStyle(theme.colors.brand.crown.opacity(0.55))
                    .blur(radius: 10)
            }
            Image(systemName: "crown.fill")
                .font(.system(size: size.iconSize))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
        }
        .onAppear {
            guard isAnimated, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                rotation = 5
                scale = 1.08
            }
        }
    }
}

/// "New King!" celebration badge.
struct NewKingBadge: View {
    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            CrownBadge(size: .medium, isAnimated: true, showGlow: true)
            Text("NEW KING!")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.onLight)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.coralRed],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
        )
        .scaleEffect(pulse ? 1.04 : 1.0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// Territory ruler badge.
struct TerritoryRulerBadge: View {
    let spotCount: Int
    let totalSpots: Int

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.fill")
                .font(.caption)
                .foregroundStyle(theme.colors.brand.seafoam)
            Text("\(spotCount)/\(totalSpots)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.text.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(theme.colors.brand.tideTeal.opacity(0.35))
        )
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            CrownBadge(size: .small)
            CrownBadge(size: .medium)
            CrownBadge(size: .large)
        }
        CrownBadge(size: .large, isAnimated: true, showGlow: true)
        NewKingBadge()
        TerritoryRulerBadge(spotCount: 3, totalSpots: 5)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

If the build fails with errors referencing `Color.crown`, `Color.coral`, or `Color.sunset` in OTHER files (places that previously imported the old `Constants.swift` palette), do not change those callers here. Wave 1 keeps the legacy `Color.crown`/`Color.coral` extensions in `Constants.swift` available as fallbacks. Subsequent waves migrate callers off them.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Components/CrownBadge.swift
git commit -m "refactor(components): port CrownBadge to ReelTheme + ReduceMotion respect"
```

---

## Task 17: Refactor `LoadingView` to use theme + add `ShipWheelSpinner`

**Files:**
- Modify: `ReelRoyale/Views/Components/LoadingView.swift`

- [ ] **Step 1: Replace the file**

Replace `ReelRoyale/Views/Components/LoadingView.swift` with:

```swift
import SwiftUI

/// Pirate-themed loading indicator: a rotating ship wheel.
struct ShipWheelSpinner: View {
    var size: CGFloat = 44

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: "steeringwheel")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(theme.colors.brand.brassGold)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .accessibilityLabel("Loading")
    }
}

/// Standard inline loading view.
struct LoadingView: View {
    var message: String? = nil
    var size: Size = .medium

    enum Size {
        case small, medium, large
        var diameter: CGFloat {
            switch self { case .small: 28; case .medium: 44; case .large: 60 }
        }
    }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.m) {
            ShipWheelSpinner(size: size.diameter)
            if let message = message {
                Text(message)
                    .font(theme.typography.subhead)
                    .foregroundStyle(theme.colors.text.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Fullscreen loading overlay with dim scrim.
struct LoadingOverlay: View {
    let isLoading: Bool
    var message: String? = nil

    @Environment(\.reelTheme) private var theme

    var body: some View {
        if isLoading {
            ZStack {
                theme.colors.surface.scrim
                    .ignoresSafeArea()
                VStack(spacing: theme.spacing.m) {
                    ShipWheelSpinner(size: 56)
                    if let message = message {
                        Text(message)
                            .font(theme.typography.subhead)
                            .foregroundStyle(theme.colors.text.primary)
                    }
                }
                .padding(theme.spacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.card)
                        .fill(theme.colors.surface.elevated)
                )
                .reelShadow(theme.shadow.heroCard)
            }
            .transition(.opacity)
        }
    }
}

/// Pirate-themed empty state.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(theme.colors.brand.tideTeal.opacity(0.6))
            Text(title)
                .font(theme.typography.title2)
                .foregroundStyle(theme.colors.text.primary)
                .multilineTextAlignment(.center)
            if let message = message {
                Text(message)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacing.xxl)
            }
            if let actionTitle = actionTitle, let action = action {
                PirateButton(title: actionTitle, action: action)
                    .padding(.top, theme.spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacing.m)
    }
}

/// Pirate-themed error state.
struct ErrorStateView: View {
    let message: String
    var retryAction: (() -> Void)? = nil

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.colors.brand.coralRed)
            Text("The Tides Are Rough")
                .font(theme.typography.title2)
                .foregroundStyle(theme.colors.text.primary)
            Text(message)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xxl)
            if let retryAction = retryAction {
                PirateButton(title: "Try Again", icon: "arrow.clockwise", action: retryAction)
                    .padding(.top, theme.spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacing.m)
    }
}

#Preview {
    VStack {
        LoadingView(message: "Charting nearby waters...")
        Divider().background(ReelTheme.default.colors.text.muted)
        EmptyStateView(
            icon: "fish",
            title: "No Catches Yet",
            message: "Cast your line and claim your first spot.",
            actionTitle: "Log a Catch"
        ) {}
    }
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

If any caller of `EmptyStateView` or `ErrorStateView` breaks (the signature is unchanged so this should not happen), do NOT modify the caller — instead check whether `theme.spacing.s` or other tokens are mistyped above. The public surface (`init` parameters) of `LoadingView`, `LoadingOverlay`, `EmptyStateView`, `ErrorStateView` is identical to the previous version.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Components/LoadingView.swift
git commit -m "refactor(components): port LoadingView family to ReelTheme + ShipWheelSpinner"
```

---

## Task 18: Add `IdentityHeader` composite

**Files:**
- Create: `ReelRoyale/Views/Components/IdentityHeader.swift`

- [ ] **Step 1: Create the component**

Create `ReelRoyale/Views/Components/IdentityHeader.swift`:

```swift
import SwiftUI

/// Sticky top header shown on every primary tab.
/// Wave 1: data sourced from `AppState.currentUser` with safe fallbacks (tier/crowns/doubloons/seasonRank not yet persisted).
struct IdentityHeader: View {
    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            ShipAvatar(
                imageURL: avatarURL,
                initial: initial,
                tier: tier,
                size: .medium,
                showCrown: crownsHeld > 0
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(captainName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    TierEmblem(tier: tier, division: 1, size: .small)
                    Text("S1 #\(seasonRankString)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.text.secondary)
                }
            }

            Spacer(minLength: theme.spacing.xs)

            HStack(spacing: theme.spacing.s) {
                if crownsHeld > 0 {
                    HStack(spacing: 3) {
                        CrownBadge(size: .small)
                        Text("\(crownsHeld)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.colors.brand.crown)
                            .monospacedDigit()
                    }
                }
                DoubloonChip(amount: doubloons, size: .small)
            }
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            theme.colors.surface.elevated
                .overlay(
                    LinearGradient(
                        colors: [
                            theme.colors.brand.deepSea.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.brand.brassGold.opacity(0.35))
                .frame(height: 0.75)
        }
    }

    // MARK: Mock values backed by current user (Wave 1)
    private var captainName: String {
        if let u = appState.currentUser {
            return u.displayName.isEmpty ? u.username : u.displayName
        }
        return "Captain"
    }
    private var initial: String { String(captainName.first ?? "C") }
    private var avatarURL: URL? {
        guard let s = appState.currentUser?.avatarUrl, !s.isEmpty else { return nil }
        return URL(string: s)
    }
    // These fields don't exist on User yet (added in Wave 5). Wave 1 returns defaults.
    private var tier: CaptainTier { .deckhand }
    private var doubloons: Int { 0 }
    private var crownsHeld: Int { 0 }
    private var seasonRankString: String { "—" }
}

#Preview {
    VStack(spacing: 0) {
        IdentityHeader()
        Spacer()
    }
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Confirm `User` model has the fields we read**

Read `ReelRoyale/Models/User.swift`. Confirm it has `username`, `displayName`, `avatarUrl` (or equivalent). If the actual field names differ (e.g., `avatarURL`), edit the four marked accessor methods above to match. **Do not change the `User` model itself in this task.**

- [ ] **Step 3: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

If you see `value of type 'User' has no member 'displayName'` or similar, that means the User model uses different property names. Look at `User.swift`, find the correct names, and update the accessors in `IdentityHeader.swift` accordingly. Do NOT change `User.swift`.

- [ ] **Step 4: Commit**

```bash
git add ReelRoyale/Views/Components/IdentityHeader.swift
git commit -m "feat(components): add IdentityHeader composite"
```

---

## Task 19: Update `AppTab` enum (add `.home`, update icons)

**Files:**
- Modify: `ReelRoyale/Utilities/AppState.swift`

- [ ] **Step 1: Update the enum**

In `ReelRoyale/Utilities/AppState.swift`, find the `AppTab` enum at the bottom of the file. Replace the entire enum definition with:

```swift
/// App tabs (4 primary + center FAB action).
/// Wave 1 keeps existing screens — `.home` is declared but not yet selected by default.
/// Wave 2 will set `.home` as the default selected tab when HomeView ships.
enum AppTab: String, CaseIterable, Identifiable {
    case home      = "Home"
    case spots     = "Map"        // renamed display label; Wave 1 still uses SpotsView
    case community = "Community"
    case profile   = "Profile"
    case more      = "More"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:      return "house.fill"
        case .spots:     return "map.fill"
        case .community: return "person.3.fill"
        case .profile:   return "person.crop.circle.fill"
        case .more:      return "ellipsis.circle.fill"
        }
    }

    /// Tabs that appear in the visible custom tab bar in Wave 1
    /// (Home is declared but not rendered yet — comes in Wave 2.)
    static var visibleInWave1: [AppTab] {
        [.spots, .community, .profile, .more]
    }
}
```

Note: the raw value for `.spots` stays the *enum case name* but the display label becomes "Map" via the rawValue string. If anywhere in the code reads `AppTab.spots.rawValue` expecting "Spots", we need to be careful. Search the codebase before continuing:

- [ ] **Step 2: Search for callers of `AppTab.spots.rawValue` and similar**

Run:
```bash
grep -rn "AppTab.spots.rawValue\|AppTab.community.rawValue\|AppTab.profile.rawValue\|AppTab.more.rawValue\|\.rawValue" ReelRoyale/ --include='*.swift'
```

Look at every result. If any code uses `.rawValue` to display a tab label (e.g., `Label(AppTab.spots.rawValue, ...)`) those will now show "Map" which is the desired Wave 1 behavior. If any code uses `.rawValue` to compare against the string "Spots", that's a bug. Fix any such bug by comparing against the enum case directly: `tab == .spots`.

For Wave 1 expected hits: `MainTabView.swift` uses `Label(AppTab.spots.rawValue, systemImage: AppTab.spots.icon)` — that's fine; it now reads "Map".

- [ ] **Step 3: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ReelRoyale/Utilities/AppState.swift
git commit -m "feat(state): add .home tab case, rename Spots label to Map"
```

---

## Task 20: Add `CenterFAB` (anchor floating action button)

**Files:**
- Create: `ReelRoyale/Views/Shell/CenterFAB.swift`

- [ ] **Step 1: Create the directory and file**

Create `ReelRoyale/Views/Shell/CenterFAB.swift`:

```swift
import SwiftUI

/// The center ⚓ anchor button that hovers above the tab bar.
/// Tapping opens the Log Catch flow (Wave 1 = existing `LogCatchView`, Wave 4 = new 4-step flow).
struct CenterFAB: View {
    let action: () -> Void

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState
    @State private var idleScale: CGFloat = 1.0
    @State private var isPressed = false

    var body: some View {
        Button {
            appState.haptics?.heavy()
            action()
        } label: {
            ZStack {
                // Outer halo (subtle gold glow)
                Circle()
                    .fill(theme.colors.brand.crown.opacity(0.3))
                    .frame(width: 86, height: 86)
                    .blur(radius: 14)

                // Brass gradient body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle().strokeBorder(theme.colors.brand.walnut, lineWidth: 2)
                    )
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                            .blendMode(.overlay)
                    )

                // Anchor icon
                Image(systemName: "anchor")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(theme.colors.brand.walnut)
            }
            .scaleEffect(isPressed ? 0.92 : idleScale)
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: theme.motion.ambientDuration).repeatForever(autoreverses: true)) {
                idleScale = 1.04
            }
        }
        .accessibilityLabel("Log a catch")
    }
}

#Preview {
    CenterFAB(action: {})
        .padding()
        .background(ReelTheme.default.colors.surface.canvas)
        .environment(\.reelTheme, .default)
        .environmentObject(AppState.shared)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Shell/CenterFAB.swift
git commit -m "feat(shell): add CenterFAB anchor button"
```

---

## Task 21: Add `TabBarShell` (custom tab bar + FAB + content slot)

**Files:**
- Create: `ReelRoyale/Views/Shell/TabBarShell.swift`

- [ ] **Step 1: Create the shell**

Create `ReelRoyale/Views/Shell/TabBarShell.swift`:

```swift
import SwiftUI

/// Custom tab bar with center FAB. Wraps the existing primary tab content.
/// Wave 1 renders Map / Community / [FAB] / Profile / More.
/// (Home tab is declared in AppTab but rendered only starting Wave 2.)
struct TabBarShell<Content: View>: View {
    @ViewBuilder var content: (AppTab) -> Content
    let onFABTap: () -> Void

    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState

    private let tabs: [AppTab] = [.spots, .community, .profile, .more]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Active tab content
            content(appState.selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.colors.surface.canvas.ignoresSafeArea())

            // Tab bar overlay
            tabBar
        }
    }

    private var tabBar: some View {
        ZStack(alignment: .top) {
            // Bar background
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.colors.surface.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(theme.colors.brand.brassGold.opacity(0.25), lineWidth: 1)
                )
                .reelShadow(theme.shadow.heroCard)
                .frame(height: 68)
                .padding(.horizontal, theme.spacing.s)

            HStack(spacing: 0) {
                tabButton(.spots)
                tabButton(.community)
                Spacer(minLength: 64)  // reserved space for FAB
                tabButton(.profile)
                tabButton(.more)
            }
            .frame(height: 68)
            .padding(.horizontal, theme.spacing.lg)

            // Center FAB anchored above bar center
            CenterFAB(action: onFABTap)
                .offset(y: -22)
        }
        .frame(height: 92, alignment: .top)
        .padding(.bottom, 0)
        .ignoresSafeArea(.keyboard)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = appState.selectedTab == tab
        return Button {
            appState.haptics?.tap()
            appState.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: isSelected ? .heavy : .regular))
                    .foregroundStyle(isSelected ? theme.colors.brand.crown : theme.colors.text.secondary)
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? theme.colors.brand.crown : theme.colors.text.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ReelRoyale/Views/Shell/TabBarShell.swift
git commit -m "feat(shell): add TabBarShell with custom tab bar + FAB"
```

---

## Task 22: Rewrite `MainTabView` to use `TabBarShell` + `IdentityHeader`

**Files:**
- Modify: `ReelRoyale/Views/MainTabView.swift`

- [ ] **Step 1: Read existing file**

Confirm you've read `ReelRoyale/Views/MainTabView.swift`. We are replacing the system TabView with our custom shell while keeping all navigation paths and destinations identical.

- [ ] **Step 2: Replace the file**

Replace `ReelRoyale/Views/MainTabView.swift` with:

```swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme
    @State private var showLogCatch = false

    var body: some View {
        TabBarShell(
            content: { tab in
                tabContent(for: tab)
            },
            onFABTap: { showLogCatch = true }
        )
        .sheet(isPresented: $showLogCatch) {
            NavigationStack {
                LogCatchView(preselectedSpotId: nil)
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            // Wave 2 implements HomeView. Wave 1 fallback: show Spots.
            spotsTab
        case .spots:
            spotsTab
        case .community:
            communityTab
        case .profile:
            profileTab
        case .more:
            moreTab
        }
    }

    private var spotsTab: some View {
        NavigationStack(path: $appState.spotsNavigationPath) {
            VStack(spacing: 0) {
                IdentityHeader()
                SpotsView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    private var communityTab: some View {
        NavigationStack(path: $appState.communityNavigationPath) {
            VStack(spacing: 0) {
                IdentityHeader()
                CommunityView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    private var profileTab: some View {
        NavigationStack(path: $appState.profileNavigationPath) {
            VStack(spacing: 0) {
                IdentityHeader()
                ProfileView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    private var moreTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                IdentityHeader()
                MoreView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .spotDetail(let spotId):    SpotDetailView(spotId: spotId)
        case .catchDetail(let catchId):  CatchDetailView(catchId: catchId)
        case .logCatch(let spotId):      LogCatchView(preselectedSpotId: spotId)
        case .userProfile(let userId):   ProfileView(userId: userId)
        case .territory(let tId):        TerritoryView(territoryId: tId)
        case .regulations(let sId):      RegulationsView(spotId: sId)
        case .fishID:                    FishIDView()
        case .measureFish:               MeasurementView(onCapture: { _ in })
        case .leaderboard:               LeaderboardView()
        case .settings:                  SettingsView()
        }
    }
}

// Settings placeholder retained from previous version.
struct SettingsView: View {
    var body: some View {
        List {
            Section("Account") {
                NavigationLink("Edit Profile") { Text("Edit Profile") }
                NavigationLink("Privacy Settings") { Text("Privacy Settings") }
            }
            Section("App") {
                NavigationLink("Notifications") { Text("Notifications") }
                NavigationLink("Units & Measurements") { Text("Units & Measurements") }
            }
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.shared)
        .environment(\.reelTheme, .default)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 3: Verify build**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

If a build error references `LogCatchView` not having a `preselectedSpotId:` init, look at the existing `LogCatchView.swift` for the correct init signature and adjust the call. The original `MainTabView` previously called `LogCatchView(preselectedSpotId: spotId)`, so this should compile unchanged.

- [ ] **Step 4: Commit**

```bash
git add ReelRoyale/Views/MainTabView.swift
git commit -m "feat(shell): wrap MainTabView in TabBarShell + IdentityHeader"
```

---

## Task 23: Manual smoke test in simulator

**Files:** (none modified)

- [ ] **Step 1: Boot the simulator and run**

```bash
xcodebuild -project ReelRoyale.xcodeproj -scheme ReelRoyale -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build 2>&1 | tail -5
```

Then run the built app. If you have access to `xcrun simctl` open the iOS Simulator manually via Xcode if needed.

- [ ] **Step 2: Verify the following checklist by visual inspection**

Walk through this list. Each item passes or fails — record results.

- [ ] App launches without crash.
- [ ] After auth (or if already authed) the user lands on the Map (formerly Spots) tab.
- [ ] Bottom tab bar shows: Map · Community · [⚓ FAB] · Profile · More.
- [ ] Tab bar background is dark navy with a faint brass-gold border.
- [ ] FAB is a brass-gold round button with an anchor icon, hovers above the bar center.
- [ ] FAB has a subtle idle scale animation (very subtle).
- [ ] Tapping FAB opens the existing Log Catch sheet.
- [ ] Tapping each tab switches content correctly.
- [ ] Each tab shows a sticky identity header at top with avatar circle, name, tier emblem (Deckhand), season placeholder, and a doubloon chip (0).
- [ ] Identity header background is slightly elevated, with a thin gold separator below.
- [ ] No regression in: auth flow, log catch submission, spot detail navigation.
- [ ] Reduced Motion (Settings → Accessibility → Motion → Reduce Motion) freezes the FAB idle animation and the crown badge animation.

- [ ] **Step 3: Capture screenshots**

Take screenshots of each tab and save to a temp location. If anything looks off (overlapping, cut-off content, missing element), capture and note it for fix-up in a follow-up task.

- [ ] **Step 4: If any visual issue found, create a fix-up commit**

Common likely issues + fixes:
- **Content hidden behind tab bar:** add `.padding(.bottom, 90)` to scrollable content roots if needed. Resolve per-screen as found.
- **Identity header overlapping nav title:** existing screens already use NavigationStack with their own headers — confirm there's no double-title. If there is, hide the navigation title via `.navigationBarHidden(true)` on the affected screen (Wave 1 only; Wave 2+ replaces these screens entirely).

If a fix is needed, make it minimal and commit:
```bash
git add <path>
git commit -m "fix(shell): <one-line description>"
```

- [ ] **Step 5: Final Wave 1 commit (no-op if no fixes needed)**

If no fixes were required, skip. Otherwise the previous step already committed them.

---

## Self-Review

- [ ] **Step 1: Re-check the spec sections against the plan**

Open `docs/superpowers/specs/2026-05-10-reel-royale-ui-redesign-design.md` and verify:
- §3 Design System → Tasks 1–6 ✓
- §9 Sound Design (Wave 1 service stub) → Task 8 ✓
- Wave 1 component list (§4) — IdentityHeader, PirateButton, GhostButton, IconButton, ShipAvatar, TierEmblem, CrownBadge v2, DoubloonChip, LoadingView v2, EmptyState v2, ErrorState v2, CenterFAB, TabBarShell — all covered ✓
- §11 Wave 1 acceptance criteria → Task 23 smoke test verifies them ✓
- "Make Home the default tab on app launch" — that's Wave 2 scope, intentionally not in Wave 1 ✓

- [ ] **Step 2: Confirm no placeholders remain**

Scan the plan for: `TODO`, `TBD`, `implement later`, `fill in details`, `add appropriate error handling`. None should exist.

- [ ] **Step 3: Type-consistency check**

- `ReelTheme.default` referenced in all previews — defined in Task 5 ✓
- `theme.colors.*`, `theme.spacing.*`, `theme.radius.*`, `theme.motion.*`, `theme.typography.*`, `theme.shadow.*` — all match the struct field names ✓
- `appState.haptics`, `appState.sounds` — added in Task 9 before being used in Tasks 10–12, 20, 21 ✓
- `CaptainTier` defined in Task 13 before used in Task 15 (`ShipAvatar`) and Task 18 (`IdentityHeader`) ✓
- `PressFeedbackStyle` defined in Task 10 before used in Task 11, 12, 20 ✓
- `reelShadow` extension defined in Task 4 before used in Task 17, 21 ✓

---

## Execution handoff

This plan is complete and saved to `docs/superpowers/plans/2026-05-10-wave-1-theme-and-foundation.md`. Two execution options:

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task with two-stage review between tasks. Best for long plans where context discipline matters.

**2. Inline Execution** — execute tasks sequentially in this session via `superpowers:executing-plans` with batched checkpoints.

Which approach?
