# Reel Royale Wave 2 — Home Hub

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution.

**Goal:** Build the Home tab as the new default landing surface. Hub composition per spec §5.2: sticky identity (Wave 1 ✓) → leaderboard podium hero → today's bounty → catch-path strip → map preview → your crowns → dethrone ticker → feature CTAs.

**Architecture:** New `Views/Home/` directory holds the section-per-file structure. New `Models/` types for `Bounty`, `DethroneEvent`, `LeaderboardEntry`. New services for `BountyService`, `DethroneEventService`, `LeaderboardService` — each ships with a mock implementation returning realistic seed data so the screen feels alive immediately. Real Supabase wiring lives behind the protocol and can ship later without touching views.

**Mock-first rationale:** The acceptance criteria of "Home loads in <1s on warm cache, podium animates, all CTAs go to correct destinations" requires data. Building protocol + mock now means Wave 5/6 can swap in real Supabase reads behind the same interface with no view changes.

**Acceptance:**
- App launches and lands on Home tab by default.
- Podium renders top-3 (mock) with bobbing ship avatars.
- Today's Bounty card shows time-remaining countdown.
- Catch Path strip shows 4 stages with current step highlighted.
- Map preview shows nearest spot card.
- "Your Crowns" section shows held spots (mock = empty state if user has none).
- Dethrone ticker auto-scrolls with mock events.
- Feature CTA grid links to existing destinations (FishID, Measure, Regulations, Leaderboard).
- All taps fire haptics, navigation works.
- Build succeeds, no regression in other tabs.

---

## File Map

**New files:**
```
ReelRoyale/Models/
├── Bounty.swift
├── DethroneEvent.swift
└── LeaderboardEntry.swift

ReelRoyale/Services/
├── BountyService.swift           (protocol + MockBountyService)
├── DethroneEventService.swift    (protocol + MockDethroneEventService)
└── LeaderboardService.swift      (protocol + MockLeaderboardService)

ReelRoyale/ViewModels/
└── HomeViewModel.swift

ReelRoyale/Views/Home/
├── HomeView.swift
├── PodiumHeroSection.swift
├── TodaysBountySection.swift
├── CatchPathStrip.swift
├── MapPreviewCard.swift
├── YourCrownsSection.swift
├── DethroneTickerSection.swift
└── FeatureCTAGrid.swift

ReelRoyale/Views/Components/
├── BountyCard.swift
├── PodiumCard.swift
├── SectionHeader.swift
└── DethroneTickerItem.swift
```

**Modified:**
- `ReelRoyale/Utilities/AppState.swift` — register new services, change default `selectedTab` to `.home`.
- `ReelRoyale/Views/MainTabView.swift` — render `HomeView` for `.home` tab.

---

## Task 1: Models — Bounty, DethroneEvent, LeaderboardEntry

Create three model files. All `Identifiable, Codable, Hashable`. Bounty has type/criteria/reward/time-window. DethroneEvent records who took whose spot when. LeaderboardEntry is a denormalized read model (avatar, name, tier, points, crowns, rank).

## Task 2: Services with mocks

Each service is `protocol + MockImpl`. Mocks return seed data immediately. Real Supabase impl is deferred.

## Task 3: Wire services into AppState + change default tab

`AppState.configure()` instantiates the mock services. `selectedTab = .home`.

## Task 4: SectionHeader, PodiumCard, BountyCard, DethroneTickerItem components

Shared primitives consumed by Home sections.

## Task 5: PodiumHeroSection

Animated top-3 podium. Idle bob, gold/silver/bronze plinths. Tap → leaderboard.

## Task 6: TodaysBountySection

BountyCard + countdown timer. Tap → details (Wave 6 — for now → leaderboard).

## Task 7: CatchPathStrip

Horizontal 4-tile strip: Find Spot → Catch → Identify → Submit. Tap step → opens relevant flow. Current step highlighted.

## Task 8: MapPreviewCard

Mini map card showing nearest spot. Tap → switches to Map tab.

## Task 9: YourCrownsSection

Horizontal scroll of held-crown spots. Empty state CTA: "Claim your first crown."

## Task 10: DethroneTickerSection

Auto-scrolling marquee of recent dethrones. Mock data flows through. Tap item → catch detail.

## Task 11: FeatureCTAGrid

2×2 tile grid: Fish ID, Measure, Regulations, Leaderboard.

## Task 12: HomeView + HomeViewModel + integration

`HomeView` composes all sections in scroll, with sticky `IdentityHeader` at top. `HomeViewModel` fetches data on appear. `MainTabView` wires `HomeView` to `.home`.

## Task 13: Build + smoke verification

`xcodebuild` + simulator launch. Take screenshots. Verify acceptance criteria.

---

Tasks consolidated for execution efficiency. Code per task lives inline in the implementation messages — no upfront placeholder restatement.
