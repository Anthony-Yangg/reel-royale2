using System;
using PokemonGo.Camera;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.GPS;
using UnityEngine;

namespace PokemonGo.NativeBridge
{
    /// <summary>
    /// MonoBehaviour that lives on a single, well-known GameObject (named
    /// <see cref="GameObjectName"/>) so the iOS host can target it with
    /// <c>UnityFramework.sendMessageToGO()</c>.
    ///
    /// Every public method here represents an inbound RPC from Swift. Method
    /// signatures are constrained by Unity's messaging system to
    /// <c>void Method(string)</c>; we marshal richer types through JSON.
    ///
    /// Outbound messages back to Swift use <see cref="NativeNotify"/>.
    /// </summary>
    [DefaultExecutionOrder(-9000)]
    [DisallowMultipleComponent]
    public sealed class NativeBridge : MonoBehaviour
    {
        /// <summary>The exact GameObject name Swift will message.</summary>
        public const string GameObjectName = "ReelRoyale.NativeBridge";

        public static NativeBridge Instance { get; private set; }

        /// <summary>Latest player position pushed from iOS, or <c>null</c>.</summary>
        public GeoCoordinate? PlayerCoordinate { get; private set; }

        /// <summary>Latest user id pushed from iOS.</summary>
        public string CurrentUserId { get; private set; } = string.Empty;

        public event Action<SpotPayload[]> SpotsChanged;
        public event Action<RegionPayload[]> RegionsChanged;
        public event Action<GeoCoordinate> PlayerMoved;

        private bool _engineReady;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(this);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        private void Start()
        {
            // The engine boots asynchronously. We listen for completion so we
            // can flush any deferred "ready" notification up to the host.
            if (EngineRuntime.Active != null)
            {
                if (EngineRuntime.Active.IsBooted)
                {
                    OnEngineReady();
                }
                else
                {
                    EngineRuntime.Active.BootCompleted += OnEngineReady;
                }
            }
        }

        private void OnEngineReady()
        {
            _engineReady = true;
            NativeNotify.PostString("engine.ready", "{}");
        }

        // -------------------------------------------------------------------
        // Inbound RPCs from iOS Swift. Each method is invoked by
        // UnityFramework.sendMessageToGO("ReelRoyale.NativeBridge", "Method", json).
        // -------------------------------------------------------------------

        public void SetUser(string json)
        {
            try
            {
                var u = JsonUtility.FromJson<UserPayload>(json);
                CurrentUserId = u.userId ?? string.Empty;
            }
            catch (Exception e) { EngineLog.Error($"NativeBridge.SetUser: {e}"); }
        }

        public void SetPlayerPosition(string json)
        {
            try
            {
                var p = JsonUtility.FromJson<PlayerPositionPayload>(json);
                var coord = new GeoCoordinate(p.lat, p.lng);
                PlayerCoordinate = coord;
                PlayerMoved?.Invoke(coord);

                // The simulated GPS service treats SetSimulatedTarget as a
                // teleport on first call and a target for interpolation on
                // subsequent calls — perfect for forwarding real CL updates.
                if (_engineReady &&
                    EngineRuntime.Locator.TryResolve<IGpsService>(out var gps))
                {
                    gps.SetSimulatedTarget(coord);
                }

                if (_engineReady &&
                    EngineRuntime.Locator.TryResolve<IMapCameraService>(out var cam))
                {
                    cam.SetTarget(coord, snap: false);
                }
            }
            catch (Exception e) { EngineLog.Error($"NativeBridge.SetPlayerPosition: {e}"); }
        }

        public void SetSpots(string json)
        {
            try
            {
                var batch = JsonUtility.FromJson<SpotsPayload>(json);
                if (batch.spots == null) return;
                SpotsChanged?.Invoke(batch.spots);
            }
            catch (Exception e) { EngineLog.Error($"NativeBridge.SetSpots: {e}"); }
        }

        public void SetRegions(string json)
        {
            try
            {
                var batch = JsonUtility.FromJson<RegionsPayload>(json);
                if (batch.regions == null) return;
                RegionsChanged?.Invoke(batch.regions);
            }
            catch (Exception e) { EngineLog.Error($"NativeBridge.SetRegions: {e}"); }
        }

        public void RecenterToPlayer(string json)
        {
            try
            {
                if (!PlayerCoordinate.HasValue) return;
                if (!EngineRuntime.Locator.TryResolve<IMapCameraService>(out var cam)) return;
                var payload = string.IsNullOrEmpty(json)
                    ? new RecenterPayload { animate = true }
                    : JsonUtility.FromJson<RecenterPayload>(json);
                cam.SetTarget(PlayerCoordinate.Value, snap: !payload.animate);
            }
            catch (Exception e) { EngineLog.Error($"NativeBridge.RecenterToPlayer: {e}"); }
        }

        public void Ping(string nonce)
        {
            // iOS uses this to verify the runtime is alive after launch.
            NativeNotify.PostString("nativebridge.pong", nonce ?? string.Empty);
        }

        // -------------------------------------------------------------------
        // Outbound — convenience wrappers used by gameplay scripts to notify
        // the iOS host of map interactions.
        // -------------------------------------------------------------------

        public static void EmitSpotTapped(string spotId)
            => NativeNotify.PostString("spot.tapped", spotId ?? string.Empty);

        public static void EmitRegionTapped(string regionId)
            => NativeNotify.PostString("region.tapped", regionId ?? string.Empty);
    }
}
