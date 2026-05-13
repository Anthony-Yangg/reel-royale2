using UnityEngine;

namespace PokemonGo.Core
{
    /// <summary>
    /// Single immutable bag of tunables for the engine. Stored as a
    /// <see cref="ScriptableObject"/> so designers can author it without code
    /// and so values can be swapped per platform (mobile vs editor).
    ///
    /// Naming convention: every value here describes a *target* the engine
    /// honours best-effort. Engine code reads from
    /// <see cref="EngineRuntime.Settings"/>, never from singletons under a
    /// different name.
    /// </summary>
    [CreateAssetMenu(fileName = "EngineSettings",
        menuName = "PokemonGo/Engine Settings", order = 0)]
    public sealed class EngineSettings : ScriptableObject
    {
        [Header("World")]
        [Tooltip("Map tile zoom level used for visible chunks. 16-17 mimics " +
            "Pokémon GO's effective ground tile density.")]
        [Range(10, 18)] public int baseZoom = 16;

        [Tooltip("Number of tile rings loaded around the camera anchor. " +
            "Total tiles ≈ (2r+1)^2.")]
        [Range(0, 6)] public int loadRadiusTiles = 3;

        [Tooltip("Extra rings kept resident for fast pan-back.")]
        [Range(0, 4)] public int retainRadiusTiles = 1;

        [Tooltip("Distance from camera anchor at which world recenters to " +
            "Vector3.zero to keep float precision near origin.")]
        public float floatingOriginThresholdMeters = 4000f;

        [Header("Networking")]
        [Tooltip("Mapbox vector tile URL template. Use {z}/{x}/{y} placeholders.")]
        public string vectorTileUrlTemplate =
            "https://api.mapbox.com/v4/mapbox.mapbox-streets-v8/{z}/{x}/{y}.mvt?access_token={token}";

        [Tooltip("Token replacement injected into the URL template. Set " +
            "via runtime config in production; do not commit live tokens.")]
        public string mapboxAccessToken = "";

        [Tooltip("Max concurrent HTTP tile downloads. Mobile radios degrade " +
            "above ~6 simultaneous connections.")]
        [Range(1, 16)] public int maxConcurrentDownloads = 4;

        [Tooltip("On-disk tile cache size in MB. LRU eviction.")]
        public int diskCacheBudgetMB = 256;

        [Tooltip("In-memory tile cache size in MB. LRU eviction.")]
        public int memoryCacheBudgetMB = 64;

        [Header("Atmosphere")]
        [Tooltip("Global time-of-day 0…1 passed to shaders (0 ≈ midnight). " +
            "Daylight map reads best around ~0.42-0.56.")]
        [Range(0f, 1f)] public float atmosphereTimeOfDay01 = 0.48f;

        [Header("Rendering")]
        public bool enableSrpBatcher = true;
        public bool enableGpuInstancing = true;

        [Tooltip("Building extrusion meters per OSM 'levels' value when " +
            "height data is missing.")]
        public float metersPerBuildingLevel = 3.2f;

        [Tooltip("Distance at which buildings collapse to a flat footprint.")]
        public float buildingFullDetailDistance = 200f;

        [Tooltip("Hard cull distance for chunks.")]
        public float maxRenderDistance = 1200f;

        [Header("Camera")]
        public float defaultCameraTiltDegrees = 60f;
        public float defaultCameraDistance = 110f;
        public float minCameraDistance = 35f;
        public float maxCameraDistance = 220f;
        public float cameraInertiaSeconds = 0.18f;

        [Header("GPS")]
        public bool useSimulatedGPS = true;
        public double simulatedLatitude = 37.81f;   // SF Embarcadero
        public double simulatedLongitude = -122.41f;
        public float simulatedWalkSpeedMps = 1.4f;
        public float gpsSmoothingSeconds = 0.6f;
        public float gpsRejectAccuracyThresholdMeters = 80f;

        [Header("Performance")]
        [Range(30, 120)] public int targetFrameRate = 60;
        [Tooltip("Max milliseconds of per-frame budget given to mesh " +
            "generation and tile decoding on the main thread.")]
        [Range(1f, 8f)] public float mainThreadGenBudgetMs = 3.5f;

        [Header("Debug")]
        public bool verboseLogging = false;
        public bool drawChunkBounds = false;
        public bool drawTileGrid = false;
    }
}
