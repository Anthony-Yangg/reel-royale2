# Reel Royale ↔ Unity Engine Integration

This document is the **one source of truth** for getting the Unity-powered
Pokémon-GO-style map running inside the Reel Royale iOS app.

Two halves:
1. The **Unity engine** in `unity-engine/` — compiles into a
   `UnityFramework.framework`.
2. The **iOS host app** in `ReelRoyale/` — embeds that framework and renders
   it via `UnityMapHostView` whenever the framework is present, falling back
   to the existing MapKit map when it isn't.

The Swift code already auto-detects the framework at runtime
(`ReelUnityIsAvailable()` in `Bridges/UnityBridge/UnityBridgeC.mm`), so once
the framework is dropped into the app bundle the map flips over automatically
on next launch. Until then, the app keeps shipping with the recolored MapKit
map.

---

## One-time setup: install Unity

Unity Editor compiles the C# source in `unity-engine/` into a native
framework binary. There's no way to skip this step — Unity's IL2CPP +
Metal/ShaderGraph toolchain must run.

1. Download **Unity Hub**: https://unity.com/download
2. In Hub → **Installs** → **Install Editor**, pick **Unity 6 LTS**
   (`6000.0.x` LTS — match the version in
   `unity-engine/ProjectSettings/ProjectVersion.txt`).
3. **During install, enable the `iOS Build Support` module.** This is the
   single most common thing people forget; without it Unity can't emit an
   Xcode project for iOS.
4. Sign in with a free **Unity Personal** license (or whatever your org
   uses). Hub will activate automatically.

Total disk usage: ~12 GB. First-time setup: ~30 min.

## Build the iOS framework

From the repo root:

```bash
./scripts/build-unity-ios.sh
```

What it does:

1. Locates Unity (checks `$UNITY_PATH`, then `~/Applications/Unity/Hub/Editor/6.x`,
   then `/Applications/Unity/Hub/Editor/6.x`).
2. Runs Unity in **batch mode** against `unity-engine/` and invokes
   `PokemonGo.Editor.iOSBuildPipeline.BuildForReelRoyale`.
3. That C# method:
   - Auto-creates a runtime scene at `Assets/Scenes/ReelRoyaleMap.unity`
     with the `EngineSceneBootstrap` + `NativeBridge` GameObjects pre-wired.
   - Auto-creates an `EngineSettings` asset at
     `Assets/Settings/ReelRoyaleEngine.asset` (pulls `MAPBOX_TOKEN` from env
     if set, else stays in simulated GPS mode).
   - Configures `PlayerSettings` for Unity-as-a-Library (IL2CPP, arm64,
     iOS 16+, location usage description).
   - Runs `BuildPipeline.BuildPlayer` with
     `BuildOptions.AcceptExternalModificationsToPlayer` — that flag tells
     Unity to emit an Xcode project where `UnityFramework.framework` is its
     own target, separate from the demo `Unity-iPhone` app target.

Output:

```
unity-build/ios/
├── Unity-iPhone.xcodeproj/           # The Xcode project Unity emits
├── UnityFramework/                   # The framework target source
├── Data/                             # Game assets, asset bundles, .data files
└── Classes/                          # Unity's bootstrapping Obj-C++
```

To also produce a compiled `UnityFramework.framework` binary alongside the
project (useful when you don't want to open Xcode):

```bash
./scripts/build-unity-ios.sh --xcode
# → Frameworks/UnityFramework.framework
```

## Wire the framework into ReelRoyale.xcodeproj

Two paths — pick one.

### Path A: Workspace (recommended)

This keeps the Unity project compiling alongside the host app, so any
re-export to `unity-build/ios/` is picked up next build with no copying.

1. In Xcode, open **`ReelRoyale.xcodeproj`**.
2. **File → New → Workspace…** → save as `ReelRoyale.xcworkspace` at the
   repo root.
3. Drag `ReelRoyale.xcodeproj` into the workspace.
4. Drag `unity-build/ios/Unity-iPhone.xcodeproj` into the workspace.
5. Select the `ReelRoyale` target → **General** tab → under **Frameworks,
   Libraries, and Embedded Content**, press **+** and add
   `UnityFramework.framework` (from the `Unity-iPhone` sub-project).
   Set **Embed** to **Embed & Sign**.
6. In the same target, **Build Phases → Dependencies** → add
   `UnityFramework` as a target dependency so xcodebuild builds Unity first.
7. Always launch the app from `ReelRoyale.xcworkspace`, never the bare
   `.xcodeproj`, from now on.

### Path B: Pre-built framework

If you don't want a workspace and just want a single binary to embed:

1. Run `./scripts/build-unity-ios.sh --xcode` (produces
   `Frameworks/UnityFramework.framework`).
2. In Xcode, select the `ReelRoyale` target → **General** →
   **Frameworks, Libraries, and Embedded Content** → drag
   `Frameworks/UnityFramework.framework` in. Embed & Sign.
3. Add `$(PROJECT_DIR)/Frameworks` to **Build Settings → Framework
   Search Paths**.

Path B is simpler but means every Unity code change requires rerunning the
script before the host app sees it.

## Verify

```bash
./scripts/build-unity-ios.sh           # build Unity framework
xcodebuild -workspace ReelRoyale.xcworkspace -scheme ReelRoyale \
  -destination 'generic/platform=iOS Simulator' build
```

Launch the app, open the Map tab, check the Xcode console:
- ✅ `[ReelUnity] UnityFramework runEmbedded launched.` — Unity is rendering.
- ❌ `[ReelUnity] UnityFramework.framework not present — falling back to native map.`
  — embed/sign was missed; recheck steps 5–6 above.

## Day-to-day workflow

| When you change… | What you need to run |
| --- | --- |
| Swift / SwiftUI code | normal Xcode build |
| Anything in `unity-engine/Assets/Scripts/` | `./scripts/build-unity-ios.sh` |
| Shaders in `unity-engine/Assets/Shaders/` | `./scripts/build-unity-ios.sh` |
| `EngineSettings` values | edit asset in Unity Editor, save, rebuild |

## Bridge protocol

Swift → Unity (via `UnityRuntime.shared`):

| Method | Triggers in Unity (`ReelRoyale.NativeBridge`) |
| --- | --- |
| `send(player:)` | `SetPlayerPosition` → `IGpsService` + `IMapCameraService` |
| `send(spots:)` | `SetSpots` → fires `NativeBridge.SpotsChanged` |
| `send(regions:)` | `SetRegions` → fires `NativeBridge.RegionsChanged` |
| `send(user:)` | `SetUser` → stores `CurrentUserId` |
| `recenter()` | `RecenterToPlayer` → camera service `SetTarget` |

Unity → Swift (via `NSNotification` named `ReelRoyaleUnityBridgeMessage`,
observed by `UnityRuntime` and surfaced as `UnityInbound` events on the
`messages` publisher):

| Topic | Swift event |
| --- | --- |
| `engine.ready` | `.engineReady` |
| `spot.tapped` | `.spotTapped(id:)` |
| `region.tapped` | `.regionTapped(id:)` |
| `nativebridge.pong` | `.pong(nonce:)` |

JSON payload shapes are pinned in two places that **must stay in sync**:
- C#: `unity-engine/Assets/Scripts/NativeBridge/NativeBridgePayloads.cs`
- Swift: `ReelRoyale/Bridges/UnityBridge/UnityMessages.swift`

Field names are matched by `JsonUtility` (Unity) — rename in both files or
neither.

## Troubleshooting

- **"Could not find Unity 6 Editor"** — install Unity Hub + an Editor with iOS
  Build Support, or `export UNITY_PATH=…` to a specific install.
- **Linker complains about UnityFramework symbols on host build** — Embed
  step (Path A step 5 / Path B step 2) was missed.
- **Map screen is black on launch** — check that `UnityFramework.framework`
  is actually inside `ReelRoyale.app/Frameworks/` post-build (`ls` the app
  bundle in `~/Library/Developer/CoreSimulator/...`). If it isn't, the embed
  phase isn't running.
- **Unity logs `MissingComponent: NativeBridge`** — the build pipeline didn't
  rebuild the scene. Delete `Assets/Scenes/ReelRoyaleMap.unity` and re-run.
