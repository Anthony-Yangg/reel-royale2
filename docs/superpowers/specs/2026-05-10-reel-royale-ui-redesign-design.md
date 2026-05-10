# Reel Royale — Complete UI Redesign Design Spec

**Date:** 2026-05-10
**Status:** Approved — implementation in 6 waves
**Owner:** Raunak Gengiti

---

## 1. Vision & Goals

Reel Royale is a real-world king-of-the-hill fishing game. The redesign reframes it as a **pirate adventure game that uses fishing as its core mechanic** — not "a fishing app with social features." Inspiration: Clash Royale's hub model, Fortnite/Valorant polish, Studio Ghibli stylized water aesthetics, Pirates of the Caribbean tone.

### Goals

1. **Game-first identity.** App should feel like a premium mobile game (Fortnite, Clash Royale). Fishing is the in-world activity; the game wraps everything.
2. **Leaderboard supremacy.** Every screen drives the user toward "climb the leaderboard." Persistent rank + points header on every screen.
3. **Process clarity.** A new player should see the 4-step path to the leaderboard within 10 seconds of opening the app: **Find Spot → Catch → Identify → Submit → Rank up.**
4. **Restrained premium motion.** Animation reserved for hero moments (dethrone, tier-up, season-end). List/feed/settings stay calm.
5. **Universal usability.** Any age. Large tap targets, high contrast, voiceover-ready, no jargon.
6. **Non-fisher engagement.** Browse mode is fun *before* the user goes fishing — observing leaderboards, scouting spots, following rivals, watching dethrone ticker — creates anticipation that drives outdoor action.

### Non-goals (v1)

- Real-time multiplayer duels
- Apple Watch companion
- Music (deferred — SFX + haptics only)
- iPad-specific layout (compatible but not optimized)
- Custom map mode toggle (only the one stylized map)

---

## 2. Locked Decisions Summary

| # | Decision | Locked |
|---|----------|--------|
| Aesthetic | Modern Pirate Adventure: deep teal + dark walnut + brass gold + coral red | ✓ |
| Hub model | Hybrid Hub — sticky identity header, podium hero, process strip, map/territory cards, feature CTAs | ✓ |
| Tab structure | 4 tabs + center ⚓ FAB — Home · Map · [FAB] · Community · Profile | ✓ |
| Progression | Captain Tier + Season Rank + Crowns | ✓ |
| Map style | Real coast + animated stylized water + territory polygons + king banners | ✓ |
| Catch flow | 4-step animated: Spot → Catch → Identify → Submit + dethrone cinematic | ✓ |
| Leaderboard | Tabbed (Global / Regional / Friends) + podium hero + time filter | ✓ |
| Profile | Captain's Quarters: hero card, stat tiles, trophy case, logbook, territories | ✓ |
| Community | Tavern Hub: bounty board, dethrone ticker, feed | ✓ |
| Motion | Restrained premium — animation reserved for hero moments | ✓ |
| Sound | SFX + haptics, no looping music | ✓ |
| Onboarding | Cinematic + 3-step setup, skippable + first-bounty quest | ✓ |

---

## 3. Design System

### 3.1 Color Tokens (semantic)

```
// Surface
bg.canvas        #0A1822  primary background (near-black navy)
bg.elevated      #14222F  cards, sheets
bg.elevatedAlt   #1B2D3D  nested cards, headers
bg.parchment     #F4E8D0  inverse surfaces — map land, onboarding

// Brand
brand.deepSea    #0E2C44  deep teal — primary brand
brand.tideTeal   #1F6F7A  mid teal — interactive accents
brand.seafoam    #3FB8AE  bright teal — highlights, focused state
brand.brassGold  #C9A24B  gold — tier emblems, doubloons, CTAs
brand.crown      #F2C95C  bright gold — kings, crowns, winning
brand.coralRed   #D8553C  coral — dethrone, danger, alert
brand.walnut     #4A2E1D  dark wood — frames, banners
brand.parchment  #E8D9B0  aged paper accent on dark

// Text
text.primary     #F0E6D2  warm off-white
text.secondary   #A99E83  muted parchment
text.muted       #6E6353
text.onLight     #1B2D3D  text on parchment
text.accent      #F2C95C  gold-tinted

// State
state.success    #4FC28A
state.danger     #D8553C
state.warning    #E5A547

// Tier emblem
tier.deckhand    #8B7355
tier.sailor      #B0925E
tier.firstMate   #C9A24B
tier.captain     #E5C04A
tier.commodore   #6FA8E8
tier.admiral     #B47EFF
tier.pirateLord  #F2C95C  (glow)
```

### 3.2 Typography

SF Pro Rounded for display/titles (warmer, game-feel). SF Pro for body (legibility). SF Mono for stats.

| Style | Font | Size / Line | Weight | Usage |
|-------|------|------|------|-------|
| Display | SF Pro Rounded | 56/64 | Black | Podium numbers, hero stats |
| Title 1 | SF Pro Rounded | 34/40 | Bold | Page titles |
| Title 2 | SF Pro Rounded | 22/28 | Bold | Section titles |
| Headline | SF Pro | 17/22 | Semibold | Card titles |
| Body | SF Pro | 17/22 | Regular | Body copy |
| Subhead | SF Pro | 15/20 | Medium | Secondary info |
| Caption | SF Pro | 13/18 | Medium | Meta, labels |
| Mono | SF Mono | 15/20 | Medium | Numbers in stats rows |

### 3.3 Spacing & Radius

- Spacing scale (4pt grid): 4, 8, 12, 16, 20, 24, 32, 40, 56, 80
- Radius scale: 6 (chip), 12 (button/small card), 18 (card), 24 (hero card), 32 (modal)

### 3.4 Elevation

Two-layer + optional inset:
- Layer 1 — inner highlight 1pt top, 6% white ("lit from above")
- Layer 2 — drop shadow 0/4/16, 30% black
- Hero cards add brass-gold inset border at 12% opacity

### 3.5 Motion tokens

| Token | Duration | Curve | Usage |
|-------|----------|-------|-------|
| motion.fast | 180ms | easeOut | Taps, micro-feedback |
| motion.standard | 320ms | spring(0.7, 18) | Transitions, sheets |
| motion.hero | 600ms | spring(0.6, 14) | Page transitions, podium reveals |
| motion.cinematic | 1200ms+ | keyframes | Dethrone, tier-up, season-end |
| motion.ambient | 4–8s | loop | Water shader, idle ship bob |

Pair haptics:
- Tap: `.soft`
- Confirm: `.medium`
- Dethrone / tier-up: `.heavy` + `.success` notification
- Error: `.error` notification

### 3.6 Theme implementation

`ReelTheme` SwiftUI `EnvironmentObject` exposes all tokens. Every component reads from environment — no hardcoded hex outside theme file. Enables future theme variants (daylight, premium cosmetics) without touching components.

```swift
// Sketch
struct ReelTheme {
    let colors: Colors
    let typography: Typography
    let spacing: Spacing
    let radius: Radius
    let motion: Motion
}

extension EnvironmentValues {
    var reelTheme: ReelTheme { ... }
}
```

---

## 4. Component Library (Wave 1 primitives)

Every reusable building block lives here. Components are dumb (no business logic), themed, accessible.

| Component | Purpose |
|-----------|---------|
| `PirateButton` | Primary action button — brass-gold gradient w/ wood-textured border, ripple on press, haptic |
| `GhostButton` | Secondary outlined variant |
| `IconButton` | Round icon-only (camera, share, etc.) |
| `CaptainCard` | User identity card (avatar, name, tier, season rank, crowns, XP bar) — small + hero size |
| `ShipAvatar` | Avatar in ship-frame medallion. Variants: small, medium, large, hero. Tier-colored frame ring. |
| `TierEmblem` | Standalone tier badge (Deckhand → Pirate Lord). Renders chevrons + name. Animated tier-up keyframe. |
| `CrownBadge` (v2) | Existing component, restyled. Shows crowns held; pulses gold when count increases. |
| `DoubloonChip` | Inline coin + number for points (used in header + everywhere points are shown) |
| `StatTile` | Numeric + label tile (used in Profile stats row) |
| `BannerStrip` | Pirate flag banner used over spots/territories (king name + tier) |
| `PodiumCard` | Top-3 podium card; gold/silver/bronze plinths with ship avatars on top |
| `LeaderboardRow` | Single rank row (rank, avatar, name, tier, points, delta vs you) |
| `BountyCard` | Time-limited event card (icon, title, time remaining, reward, CTA) |
| `DethroneTickerItem` | Marquee item ("⚡ X dethroned Y at Z") |
| `MapPin` | Treasure-chest spot pin variants: vacant, claimed-by-you, claimed-by-other |
| `MapBanner` | Flag-emblem banner planted at claimed spots showing king's tier color |
| `TerritoryOverlay` | Colored polygon overlay on map for owned territories |
| `WaveLayer` | Animated water shader layer (Metal-backed or `TimelineView` + SwiftUI shaders on iOS 17+) |
| `ParchmentBackground` | Aged-paper texture container (for onboarding, regulations, modals) |
| `SectionHeader` | Bold gold-rule section header used across screens |
| `EmptyState` | Themed empty state (replaces sad iOS defaults) — pirate mascot + headline + CTA |
| `ErrorState` | Themed error (replaces "Something went wrong" — pirate-themed copy + Retry button) |
| `LoadingView` (v2) | Themed loading — ship-wheel spinner or treasure-chest animation |
| `StepperRail` | Progress rail for catch flow (cannonball moves along route) |
| `IdentityHeader` | The sticky top header — avatar + name + tier + crowns + season rank + doubloons |
| `TabBarShell` | 4-tab + center FAB shell with custom selection animation |
| `CenterFAB` | The ⚓ floating action button — anchored, animated, opens catch flow |

---

## 5. Screen Designs

### 5.1 Identity Header (every screen)

Sticky pinned at top across all primary tabs. ~64pt tall on standard scroll, compresses to ~44pt on scroll.

```
┌──────────────────────────────────────────────────────────────┐
│ 🟡   CaptainBlackbeard       ⚔️ Captain II     👑 7    🪙 12,450 │
│ (avatar)  Season Rank #234              (tap → leaderboard) │
└──────────────────────────────────────────────────────────────┘
```

- Avatar: tap → opens own Profile.
- Tier emblem: tap → opens tier-progress modal.
- Crowns count: tap → opens "Your Crowns" list.
- Doubloons: tap → coin history.
- Whole header background: subtle wave-shader at 8% opacity.

### 5.2 Home Hub

Order top → bottom:

1. **Identity Header** (sticky)
2. **Podium Hero** — top 3 players on gold/silver/bronze plinths, ship-frame avatars, animated idle bob. Below the podium, "Your Rank" card slotted in showing your rank #, points diff to next position, "Tap to see full leaderboard →".
3. **Today's Bounty** — single featured event card (BountyCard). Time-limited goal (e.g., "Biggest Bass — ends in 9h — reward 500🪙 + Glory bonus"). CTA "Accept Bounty."
4. **Catch Path Strip** — horizontal 4-step strip showing Find Spot → Catch → Identify → Submit. Each step a tappable tile; current incomplete step highlighted. Acts as both pedagogy and shortcut.
5. **Map Preview** — small map card. Shows nearest spot + your nearest territory. CTA "Open Map."
6. **Your Crowns** — horizontal scroll of spots you currently rule (or "Claim your first crown" if none). Each chip: spot name + thumbnail + size of your winning catch + "Defend" CTA if under threat.
7. **Recent Dethrone Ticker** — horizontal auto-scroll bar showing recent global dethrones. Each item: "⚡ X dethroned Y at Z, 2m ago" — tap → opens that catch.
8. **Feature CTAs** — 2x2 tile grid: Fish ID, Measure, Regulations, Achievements.
9. **First Bounty quest** (only for first 24h) — sticky banner above tab bar: "Cast Your First Claim — earn 100🪙."

### 5.3 Map (Pirate Map)

Real Apple Maps as base. Land tinted parchment-cream. Water rendered with painterly stylized wave shader (animated, looping, ambient motion only — not gaudy).

Overlays:
- **Spot pins** — treasure-chest icon. Variants: vacant (closed chest), claimed-by-you (open chest with crown), claimed-by-other (open chest with rival's tier-color glow).
- **King banners** — floating flag above claimed spots showing king's avatar + tier color. Tap → spot detail.
- **Territory polygons** — semi-transparent colored regions (tier-color of ruler). Subtle gold outline.
- **Your position** — animated ship icon (replaces default blue dot).

Map UI:
- Search bar (parchment style)
- Segmented: Map / List
- Filters: Type, Distance, Claimed status, Vacant only
- "Recenter on me" anchor-icon button
- Long-press empty water → "Claim new spot here" (creates new spot)

### 5.4 Catch Flow (FAB → 4 steps)

Full-screen modal flow. Custom transition: water-wipe between steps (300ms). Cannonball-on-rope progress rail at top.

**Step 1 — Spot**
- Map showing nearby spots + your location
- List of suggested spots (sorted by distance + your past catches there)
- "Claim a new spot at my location" CTA
- Selected spot shows preview card with current king + record catch
- Next button: "I'm Here ⚓" (golden)

**Step 2 — Catch (Photo)**
- Camera-first view with capture button at bottom
- Library + AR Measure options at sides
- After capture: photo preview + "Measure with AR" button
- AR measurement returns length value; manual override allowed
- Next button: "Looks Good →"

**Step 3 — Identify**
- Auto-run Fish ID on photo. Show predicted species with confidence + alternative top-3.
- User confirms or picks from list (uses existing CommonFishSpecies enum, expanded).
- Length already known from step 2.
- Optional notes field (collapsed by default).
- Next button: "Continue →"

**Step 4 — Submit**
- Full preview card: photo, species, length, spot, weather conditions (auto-pulled), date.
- "Points to earn" preview (calculated: base + size bonus + rare-species bonus + dethrone-jackpot if applicable).
- Privacy toggle: Public / Friends / Private.
- Current king of spot shown with their catch size. If user's catch > king's → "🏴‍☠️ DETHRONE IMMINENT" banner glows red.
- Big button: "Cast Your Claim ⚓" (full-width, brass-gold, haptic-heavy on tap).

**On submit:**
- If no dethrone: short success animation (coin shower 600ms + sound) → returns to Home with points-earned toast.
- If dethrone: **dethrone cinematic** triggers (see §5.5).

### 5.5 Dethrone Cinematic

Triggered when user's catch claims a spot from another king. ~3s sequence. Cannot be skipped (it's the reward).

Sequence:
1. (0.0s) Screen fades to black with crashing wave audio sweep
2. (0.3s) Previous king's crown enters from above, settles on a pedestal
3. (0.8s) Camera shake + cannon-boom audio + heavy haptic. Crown shatters into gold particles.
4. (1.2s) Gold particles converge into NEW crown that flies onto user's avatar (rendered large center-screen).
5. (1.8s) Banner unfurls below: "You are now King of [Spot Name]"
6. (2.5s) Stats overlay: "+500🪙 · +120 Glory · Crown #8"
7. (3.0s) Transition to map showing the spot with user's new banner planted (banner-wave animation).

Implementation: SwiftUI keyframe animations + sprite particles + AVAudioPlayer SFX.

Visibility: opponent gets a push notification "⚡ CaptainBlackbeard dethroned you at Pier 39 — retaliate!" → tap → opens map at that spot.

### 5.6 Leaderboard

Top: Segmented "Global / Regional / Friends." Below: time filter dropdown "All-Time / Season / Week."

Hero: Top-3 podium (PodiumCard). Below podium: ranked list.

Each row (LeaderboardRow): rank, ship-frame avatar, name, tier emblem, crowns count, points, delta indicator (▲ up N this week, ▼ down N).

Pinned bottom: your card with rank and "Tap to see neighbors" expanding the list around your position.

Row tap → opens that player's read-only Captain Profile card modal (their tier, crowns, biggest catch, follow button).

### 5.7 Profile (Captain's Quarters — own profile)

Top → bottom:

1. **Identity Header** (sticky, your own)
2. **Captain Card Hero** — large, parallax sea backdrop. Big ship-frame avatar, name, tier emblem, "Season Rank #234" badge, "Crowns: 7" badge. XP bar to next tier with current/needed.
3. **Stat Tile Row** — horizontally scrollable: Crowns Held / Biggest Catch / Spots Ruled / Win Rate / Total Catches / Species Caught.
4. **Trophy Case** — earned Achievements grid. Locked ones show silhouette. Tap → detail modal with how to earn + progress.
5. **Logbook** — catch history. Grid + list toggle. Tap → catch detail.
6. **Territories** — visual list of regions you rule with map preview chips. Each chip: territory name + spot count + map snapshot.
7. **Edit Profile** button bottom (avatar, bio, privacy defaults).

### 5.8 Profile (other player — read-only)

Same layout minus edit. Adds: Follow / Unfollow button, "Catches near me" if any overlap with your territories.

### 5.9 Community (Tavern Hub)

Top → bottom:

1. **Identity Header**
2. **Bounty Board** — horizontal scroll of active limited-time events. Each = BountyCard. Includes: daily challenges, weekly tournaments, regional battles.
3. **Dethrone Ticker** — horizontal auto-scroll of recent global dethrones. Hot dethrones (high-tier players) glow.
4. **Feed Filter** — segmented: Following / Region / Global / Hot.
5. **Feed** — vertical scroll of catch posts. Each post: photo, captain card mini-header, species, size, spot, comment + like counts, "View" CTA. King catches (currently held crown) show gold border + crown icon.

### 5.10 Onboarding (first launch, skippable)

1. **Cinematic intro** — 5s animated treasure map zoom-in, ship sail-by, logo reveal with sea-shanty horn. Skip button top-right.
2. **Create Captain** — choose name, pick avatar (selection of pirate avatars, can upload later). Tier starts at Deckhand. (Existing auth flow integrated.)
3. **Grant location** — explain why (find nearby spots, claim territories), then trigger permission.
4. **How to Play** — 3 swipeable cards:
   - Card 1: "Catch fish" (illustration: ship + fishing rod)
   - Card 2: "Claim spots — biggest fish wins the crown" (illustration: crown on map)
   - Card 3: "Climb the leaderboard — become Pirate Lord" (illustration: tier ladder)
5. **Land on Home** with First Bounty quest active: "Cast your first claim. Reward: 100🪙."

Skip on any step → goes straight to Home but First Bounty quest still active.

### 5.11 Browse Mode (Non-fisher engagement)

For users not yet ready to go outside, app must be engaging.

- Leaderboard is always browsable — read others' Captain profiles.
- Map is browsable — view spots, kings, territories anywhere in world. Toggle "World Mode" to free-pan globally.
- Bounty Board updates daily — gives reasons to check in.
- Dethrone Ticker = social drama.
- Achievements visible with locked silhouettes — collection-driver.
- **Scout List**: user can save spots as "scouts" (planned destinations). Builds anticipation. Saved scouts appear on Home as a small section.
- **Follow** top captains — see their catches in feed even if you haven't caught anything yet.

---

## 6. Data Model Extensions

Existing models stay. New additions:

### User (extended)
```swift
struct User {
    // existing fields...
    var captainName: String         // public-facing pirate name
    var avatarFrameId: String       // selected ship frame
    var doubloons: Int              // currency earned
    var seasonGlory: Int            // rank-determining season score
    var lifetimeGlory: Int          // career score
    var currentTier: CaptainTier    // enum
    var tierDivision: Int           // 1–3 within tier
    var crownsHeld: Int             // cached count (denormalized)
    var seasonRank: Int?            // cached rank (refreshed periodically)
    var globalRank: Int?            // cached rank
    var followingIds: [UUID]        // captains you follow
    var followerIds: [UUID]
}

enum CaptainTier: Int, Codable {
    case deckhand = 0
    case sailor = 1
    case firstMate = 2
    case captain = 3
    case commodore = 4
    case admiral = 5
    case pirateLord = 6
}
```

### Achievement
```swift
struct Achievement: Identifiable, Codable {
    let id: UUID
    let key: String           // e.g., "first_catch", "crown_thief"
    let title: String
    let description: String
    let iconName: String
    let tier: AchievementTier // bronze, silver, gold, legendary
    let rewardDoubloons: Int
    let rewardGlory: Int
}

struct UserAchievement: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let achievementKey: String
    let earnedAt: Date
    let progress: Int?         // for trackable achievements
    let target: Int?
}
```

### Bounty / Event
```swift
struct Bounty: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let bountyType: BountyType  // dailyChallenge, weeklyTournament, regionalBattle
    let startsAt: Date
    let endsAt: Date
    let criteria: BountyCriteria // e.g., "biggest bass", "most catches"
    let rewardDoubloons: Int
    let rewardGlory: Int
    let regionId: UUID?         // nil = global
}
```

### Dethrone Event (denormalized for ticker performance)
```swift
struct DethroneEvent: Identifiable, Codable {
    let id: UUID
    let occurredAt: Date
    let spotId: UUID
    let spotName: String
    let previousKingId: UUID
    let previousKingName: String
    let newKingId: UUID
    let newKingName: String
    let newCatchSize: Double
}
```

### Season
```swift
struct Season: Identifiable, Codable {
    let id: UUID
    let number: Int            // S1, S2, ...
    let startsAt: Date
    let endsAt: Date
    let theme: String?         // optional season theme name
}
```

### Catch (extended)
Add: `doubloonsEarned: Int`, `gloryEarned: Int`, `triggeredDethrone: Bool`, `predictedSpeciesConfidence: Float?`.

### Scout (new)
```swift
struct Scout: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let spotId: UUID
    let savedAt: Date
    let note: String?
}
```

### Supabase migration

Additive only. New tables: `achievements`, `user_achievements`, `bounties`, `dethrone_events`, `seasons`, `scouts`. New columns on `profiles` and `catches`. RLS policies extend existing patterns.

---

## 7. Services & Architecture

### New services

| Service | Responsibility |
|---------|----------------|
| `ThemeService` | Holds current ReelTheme; future skins |
| `SoundService` | SFX playback (AVAudioPlayer pool); mute toggle |
| `HapticsService` | Wraps `UIImpactFeedbackGenerator` / notification generator |
| `ProgressionService` | Computes points + glory per catch; tier-up logic |
| `AchievementService` | Tracks progress, awards on event |
| `BountyService` | Fetches active bounties, computes progress |
| `SeasonService` | Tracks current season, reset on rollover |
| `DethroneEventService` | Records dethrone events; streams ticker |
| `ScoutService` | Save/load planned spots |

All conform to protocols (existing pattern). Injected via `AppState`. Mock implementations for tests.

### Architecture diagram (high-level)

```
View (SwiftUI)
   ↓ binds
ViewModel (Observable)
   ↓ calls
Service / Repository protocols
   ↓ implemented by
SupabaseService + local cache
```

No change to MVVM pattern. New components live in `Views/Components/`. New screens in `Views/<Tab>/`.

### File structure additions

```
ReelRoyale/
├── Theme/                         (new)
│   ├── ReelTheme.swift
│   ├── Colors.swift
│   ├── Typography.swift
│   ├── Spacing.swift
│   ├── Motion.swift
│   └── EnvironmentKey.swift
├── Services/
│   ├── SoundService.swift         (new)
│   ├── HapticsService.swift       (new)
│   ├── ProgressionService.swift   (new)
│   ├── AchievementService.swift   (new)
│   ├── BountyService.swift        (new)
│   ├── SeasonService.swift        (new)
│   └── DethroneEventService.swift (new)
├── Resources/
│   ├── Sounds/                    (new — SFX assets)
│   └── Avatars/                   (new — pirate avatar set)
├── Views/
│   ├── Components/                (expanded with new primitives)
│   ├── Home/                      (new tab)
│   │   ├── HomeView.swift
│   │   ├── PodiumHeroView.swift
│   │   ├── CatchPathStripView.swift
│   │   └── ...
│   ├── Catch/                     (replace existing flow)
│   │   ├── CatchFlowCoordinator.swift
│   │   ├── Step1SpotView.swift
│   │   ├── Step2CatchView.swift
│   │   ├── Step3IdentifyView.swift
│   │   ├── Step4SubmitView.swift
│   │   └── DethroneCinematicView.swift
│   ├── Onboarding/                (new)
│   │   ├── IntroCinematicView.swift
│   │   └── CreateCaptainView.swift
│   └── ...
```

---

## 8. Accessibility & Universal Usability

- **Minimum tap target:** 44×44pt.
- **VoiceOver** labels on every interactive element. Custom rotor for leaderboard rows.
- **Dynamic Type** supported up to XXL on body/caption styles; titles cap at +2 sizes to preserve hierarchy.
- **Color-contrast** AA on all text against backgrounds (verified per token pair).
- **Reduced Motion** honored: ambient water animation freezes, transitions become crossfades, dethrone cinematic becomes static reveal with banner unfurl only.
- **High Contrast** mode: strengthens gold accents and increases card border opacity.
- **Haptics off** toggle in settings (legal requirement for some users).
- **Localization-ready** strings via `Localizable.strings`, even if v1 ships English-only.
- **No jargon barrier:** every gamified term has a glossary entry accessible from Help. ("Dethrone = take over a spot by catching a bigger fish there.")

---

## 9. Sound Design

Asset list (royalty-free / produced):

| Event | Sound | Haptic |
|-------|-------|--------|
| Tap (any button) | soft wood-click | .soft |
| Successful submit | coin-shower | .medium |
| Dethrone trigger | cannon-boom + crown-shatter | .heavy + .success |
| Tier-up | sea-shanty horn rise | .heavy + .success |
| Achievement unlock | brass chime | .success |
| Bounty acceptance | bell ring | .medium |
| Error | low thud | .error |
| Refresh / pull | rope creak | .light |

Stored in `Resources/Sounds/`. Loaded eagerly at app start (small files). SoundService caches AVAudioPlayer instances.

Mute toggle in Settings + system-level mute respected.

---

## 10. Progression Economy

### Doubloons (currency)
Earned for every action that progresses competitive ranking. Spent on cosmetic upgrades (avatar frames, ship designs) — future feature; in v1 they're a flex stat shown in header.

- Per catch base: 50
- Size bonus: +1 per cm
- Rare species: +100
- Dethroning a king: +500
- First catch at a new spot: +25
- Daily login: +25

### Glory (rank score)
Drives Season Rank position. Only goes up within a season. Resets per season.

- Catch glory = doubloons × 0.2
- Dethrone bonus: +120 glory
- Bounty completion: variable (per bounty)

### Captain Tier (long-term identity)
Tiers gated by **lifetime glory** (never resets):

| Tier | Lifetime Glory |
|------|----------------|
| Deckhand | 0 |
| Sailor | 500 |
| First Mate | 2,000 |
| Captain | 6,000 |
| Commodore | 15,000 |
| Admiral | 40,000 |
| Pirate Lord | 100,000 |

Each tier has divisions III → II → I. Division-up animation. Tier-up cinematic (similar in spirit to dethrone — see §5.5).

### Seasons
8-week seasons. End-of-season ceremony: top-100 globally + top-10 regional get exclusive cosmetic + badge on profile. Season reset = fresh leaderboard, motivates re-engagement.

---

## 11. Wave Rollout Plan

Each wave is a separate implementation plan + PR. App must remain functional after every wave (feature-flag gates as needed).

### Wave 1 — Theme & Foundation
Goal: design system + primitives in place. No new screens yet.

Scope:
- `ReelTheme` env object + tokens
- Typography, spacing, radius, motion modules
- All Wave 1 primitive components (see §4)
- `SoundService`, `HapticsService` stubs
- IdentityHeader rendered on existing tabs (replacing nothing yet, behind feature flag if needed)
- TabBarShell + CenterFAB rendered around existing screens (visual only; FAB opens existing LogCatchView)

Acceptance: every existing screen still works, app theme is dark + pirate-styled, no functional regression.

### Wave 2 — Home Hub
Goal: Home tab as default landing.

Scope:
- New `HomeView` with all sections
- `BountyService` + `DethroneEventService` stubs returning mocked data initially, then wired to real Supabase tables
- Podium hero rendering top-3 from real leaderboard
- First Bounty quest logic
- Catch Path Strip wired to existing screens
- Make Home the default tab on app launch

Acceptance: Home loads in <1s on warm cache, podium animates, all CTAs go to correct destinations.

### Wave 3 — Pirate Map
Goal: map looks like the design.

Scope:
- Custom tile overlay (parchment land tint)
- Animated water shader layer (`WaveLayer`)
- New `MapPin` treasure-chest variants
- King banner overlays
- Territory polygons
- Animated ship avatar for user position
- Long-press → claim new spot
- Map/List segmented view styled

Acceptance: map performs at 60fps on iPhone 12+ with all overlays, animation honors Reduced Motion.

### Wave 4 — Catch Flow + Dethrone Cinematic
Goal: replace existing log-catch with the 4-step flow.

Scope:
- `CatchFlowCoordinator` + 4 step views
- `StepperRail` (cannonball progress)
- Dethrone detection in submit step
- `DethroneCinematicView` with keyframe animation + particles + SFX
- `ProgressionService` for points calculation
- Push notification on dethrone (opponent gets alert)

Acceptance: full flow under 60s for typical user, dethrone cinematic plays correctly on first dethrone with proper haptics + sound, opponent receives notification.

### Wave 5 — Leaderboard + Profile
Goal: motivating destinations done.

Scope:
- Tabbed Leaderboard (Global / Regional / Friends) + time filter
- LeaderboardRow, PodiumCard polished
- Other-player profile modal
- Captain's Quarters profile redesign (hero card, stat tiles, trophy case, logbook, territories)
- `AchievementService` + initial achievement set (first_catch, crown_thief, cartographer, apex_predator, species_hunter)
- Achievement unlock toast + cinematic

Acceptance: leaderboard scrolls smoothly with 200+ players cached, achievements unlock correctly on triggering events.

### Wave 6 — Community + Onboarding + Polish
Goal: ship-ready.

Scope:
- Tavern Hub (Community) — bounty board, dethrone ticker, feed redesign
- Onboarding cinematic + create-captain + how-to-play cards
- Sound assets finalized
- Accessibility audit pass (VoiceOver, Dynamic Type, Reduced Motion verified)
- Empty / error / loading state pass (replace all defaults)
- Settings redesign
- Localization scaffolding

Acceptance: new-user flow from first launch to first catch fully smooth, VoiceOver navigates every primary surface, no default iOS empty/error states remain.

---

## 12. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| SwiftUI shader performance on older devices | Profile on iPhone 12 minimum; fallback to static texture if FPS drops |
| Sound files inflate bundle size | Cap at <2MB total SFX; encode AAC; lazy-load non-critical |
| Animation budget overruns | Per-wave perf budget enforced (90fps target on supported devices) |
| Supabase schema migrations breaking existing data | All migrations additive; rolling deploy with backwards-compatible reads |
| Onboarding friction for non-fishers | Browse mode active before first catch; First Bounty doesn't expire |
| Reduced Motion users lose game feel | Each animated moment has equivalent static reveal |
| Accessibility regressions | Per-wave a11y check before merge |

---

## 13. Out of Scope (Future Waves)

- Cosmetic doubloon shop (avatar frames, ship designs)
- Real-time duel mode
- Friend chat / DMs
- Tournaments with bracket play
- Apple Watch app
- iPad-optimized layout
- Music tracks
- AR catch overlays (display fish in AR after catching)
- Public spot moderation tools
- Localization beyond English

These are deferred until v1 ships and we observe usage.

---

## 14. Success Criteria (Post-launch)

- D1 retention up vs baseline
- 60%+ of new users complete First Bounty within 7 days
- Avg session length up
- Map screen used in 50%+ of sessions
- Leaderboard viewed in 70%+ of sessions
- App Store rating ≥ 4.6
- No crash regressions vs current build
