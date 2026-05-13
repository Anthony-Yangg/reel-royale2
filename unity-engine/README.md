# PoGo Engine — Pokémon-GO-style Geospatial Game Engine for Unity 6

Production-grade real-world map engine that streams Mapbox / OpenStreetMap
vector-tile data, builds stylized procedural geometry on the fly, and renders
it with a custom Pokémon-GO-style URP shader suite. Designed to live inside
a larger title (e.g. **Reel Royale**, see the iOS project at the repo root)
or to run standalone on iOS and Android.

## Visual Target

- pastel stylized terrain (custom shader)
- low-poly extruded buildings with procedural window grids that glow at night
- animated stylized water with caustics, foam edges and shoreline shimmer
- emissive roads (sodium-glow at night, vertex-color tint by class)
- soft world curvature in the vertex stage of every material
- dynamic time-of-day atmosphere via global shader params
- soft fog, sky-gradient dome, sun disk, star field

## Tech Stack

- **Unity 6 LTS (6000.0+)** with the **Universal Render Pipeline (URP)**
- **C# 9** + **Burst Compiler 1.8** + **Unity Jobs**
- **Mapbox Vector Tiles (MVT)** decoded with a custom Protocol Buffers reader
- **OpenStreetMap** layer taxonomy (roads, buildings, water, parks, landuse)
- **Web Mercator (EPSG:3857)** projection
- **S2 Geometry** cell indexing for spatial buckets
- **Addressables**, **Input System (Touch + Mouse)**, **AR Foundation 6**

## Folder Structure

```
unity-engine/
├── Packages/manifest.json              # Pinned package dependencies
├── ProjectSettings/                    # Editor metadata
└── Assets/
    ├── Scripts/
    │   ├── Core/           # ServiceLocator, EngineRuntime, Bootstrap, EventBus, Settings
    │   ├── GIS/            # GeoCoordinate, WebMercator, TileId, S2CellId, CoordinateService
    │   ├── VectorTiles/    # MVT protobuf decoder, command stream, types
    │   ├── Streaming/      # Tile downloader, hybrid cache, chunk manager, streamer
    │   ├── Terrain/        # Procedural mesh generators + ear-clipping triangulator
    │   ├── Rendering/      # Material library, mesh pool, LOD, frustum culler
    │   ├── Stylization/    # Atmosphere/time-of-day service
    │   ├── Camera/         # MapCameraService (PoGo-style orbit cam) + touch input
    │   ├── GPS/            # Device GPS + simulated GPS + Kalman smoothing
    │   ├── Jobs/           # Burst-compiled bulk transforms
    │   ├── Utilities/      # UnityMainThread dispatcher
    │   ├── Debug/          # IMGUI HUD + chunk bounds gizmo
    │   └── Editor/         # Tile visualizer + Coordinate inspector windows
    ├── Shaders/            # PoGoCommon.hlsl + Terrain/Water/Road/Building/Sky shaders
    ├── Materials/          # (Optional, runtime-synthesised if missing)
    ├── Prefabs/
    ├── Addressables/
    ├── Resources/
    ├── Scenes/
    └── Settings/           # URP renderer asset
```

## Architecture Overview

The engine is a **layered, service-oriented chunk-streaming engine** on top
of URP. Three coordinate domains and four streaming layers:

### Coordinate domains
1. **GPS** (WGS84 lat/lng) — input from device GPS or simulator
2. **Web Mercator** (EPSG:3857, meters) — tile addressing & projection
3. **Unity World** (planar meters) — game space, recentered with a floating origin

The `CoordinateService` is the only authority for coordinate conversion and
floating-origin shifts. When the camera anchor drifts more than
`floatingOriginThresholdMeters` (4 km default) from `(0,0,0)`, the world
recenters and every chunk root translates to keep float precision intact.

### Streaming layers (radial concentric LODs)
- **L0 (active)**: full mesh, full shaders, dynamic objects
- **L1 (visible)**: full mesh, atlased textures
- **L2 (silhouette)**: simplified mesh, no buildings
- **L3 (impostor)**: culled

### Pipeline flow per tile
```
TileId → MapboxClient(HTTP) → MVT bytes → ProtobufReader →
VectorTile → LayerFilter → FeatureGeometry → CoordTransform →
TerrainBuilder → MeshData → Mesh + Material → Chunk GameObject
```

## Core Subsystems

| Service                  | Responsibility                                                 |
| ------------------------ | -------------------------------------------------------------- |
| `EventBus`               | Allocation-free strongly-typed event channels                  |
| `CoordinateService`      | GPS ↔ Web Mercator ↔ Unity coords + floating origin             |
| `HttpTileDownloader`     | Concurrency-limited UnityWebRequest tile fetcher               |
| `HybridTileCache`        | Two-level LRU (RAM + persistent disk) with byte budgets        |
| `MapboxVectorTileDecoder`| Hand-rolled MVT 2.1 decoder + gzip support                     |
| `TerrainBuilder`         | Per-chunk mesh dispatcher with main-thread time budget         |
| `ChunkManager`           | Active chunk lifecycle + GameObject pool                       |
| `TileStreamer`           | Radial visible-set diff & load/unload orchestrator             |
| `MapCameraService`       | Tilt + yaw + dolly orbit camera, pinch zoom, inertia, follow   |
| `IGpsService`            | `SimulatedGpsService` (editor) or `DeviceGpsService` (mobile)  |
| `MaterialLibrary`        | Single shared materials per layer kind (SRP batcher friendly)  |
| `MeshPool`               | Mesh + MeshData object pool                                    |
| `AtmosphereService`      | Time-of-day, sun, fog, sky gradient global shader uniforms     |

## Getting Started

### Standalone (Editor playmode)

1. Open `unity-engine/` as a Unity 6.0+ project.
2. Editor will auto-resolve packages from `Packages/manifest.json`.
3. In `Edit ▸ Project Settings ▸ Graphics`, assign the URP asset at
   `Assets/Settings/PokemonGoURP.asset`.
4. `Assets ▸ Create ▸ PokemonGo ▸ Engine Settings` to produce an
   `EngineSettings` asset, and fill in your Mapbox token (or stay in
   simulated mode).
5. Create an empty GameObject in a new scene and add the
   `EngineSceneBootstrap` component. Drag your settings asset in. Press play.
6. Open `Window ▸ PokemonGo ▸ Tile Visualizer` to see active chunks live.

### Embedded inside the Reel Royale iOS app

The engine is wired to ship as a `UnityFramework.framework` inside the
Reel Royale SwiftUI app. See [`/INTEGRATION.md`](../INTEGRATION.md) at the
repo root for the full pipeline. Short version:

```bash
./scripts/build-unity-ios.sh
# Then in Xcode, embed unity-build/ios/Unity-iPhone.xcodeproj into a
# ReelRoyale.xcworkspace and add UnityFramework as an Embed & Sign dep.
```

The iOS host calls into the engine through the
`PokemonGo.NativeBridge.NativeBridge` MonoBehaviour, which the build
pipeline auto-instantiates in `Assets/Scenes/ReelRoyaleMap.unity`.

## Performance Notes

- **Target**: 60 FPS sustained on iPhone 13 / Pixel 6 with `loadRadiusTiles = 3`.
- **Memory**: ~120 MB resident under default LRU budgets.
- **Network**: tiles are gzip-compressed MVT, typical ~20-80 kB per tile.
- **Draw calls**: ≤ 30 per frame with SRP batcher + GPU instancing on materials.
- **Main-thread budget**: `EngineSettings.mainThreadGenBudgetMs` (default 3.5ms)
  caps per-frame mesh-generation cost. Decoding is run on worker threads via
  `Task.Run`. Mesh assignment is post-marshalled to the main thread via
  `UnityMainThread.Post`.

## Mobile Considerations

- iOS: location permissions string in `Player Settings ▸ iOS ▸ Other Settings`.
- Android: `ACCESS_FINE_LOCATION` permission, prompted at runtime by
  `LocationService.Start`.
- AR Foundation 6 is preinstalled; add an `ARSession`/`ARSessionOrigin` to
  the scene to enable AR mode.
- The custom shaders compile down to <1 KB GLSL each on mobile after
  shader-variant stripping — no megabyte URP fallback shaders.

## Extending

Drop a new service in `EngineBootstrap.RegisterServices` and you're live.
Implement `IService` (+ optionally `ITickable`, `IFixedTickable`,
`ILateTickable`). Resolve dependencies in `OnAllServicesReady`. The locator
is the only DI surface you need.

## License

MIT, see repo root.
