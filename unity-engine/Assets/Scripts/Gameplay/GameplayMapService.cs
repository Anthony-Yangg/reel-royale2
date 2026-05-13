using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.NativeBridge;
using UnityEngine;
using UnityEngine.Rendering;
using Bridge = PokemonGo.NativeBridge.NativeBridge;

namespace PokemonGo.Gameplay
{
    public interface IGameplayMapService : IService { }

    /// <summary>
    /// Builds the "game" layer that sits above streamed GIS geometry: player
    /// avatar, interaction radius, glowing fishing spots, and territory fills.
    /// Without this layer the Unity map is technically correct but emotionally
    /// flat.
    /// </summary>
    public sealed class GameplayMapService : IGameplayMapService, ITickable
    {
        public string ServiceName => "GameplayMapService";
        public int InitOrder => -80;

        private readonly Dictionary<string, SpotMarkerState> _spotMarkers = new(128);
        private readonly Dictionary<string, RegionPayload> _regions = new(64);

        private ICoordinateService _coords;
        private IEventBus _bus;
        private Bridge _bridge;

        private Transform _root;
        private Transform _spotsRoot;
        private Transform _regionsRoot;
        private Transform _playerRoot;

        private Material _playerMaterial;
        private Material _playerDarkMaterial;
        private Material _radiusMaterial;
        private Material _whiteMaterial;
        private GeoCoordinate? _playerCoordinate;
        private float _clock;
        private bool _bridgeBound;

        public Task InitializeAsync(CancellationToken ct)
        {
            var root = new GameObject("ReelRoyale Gameplay Layer");
            UnityEngine.Object.DontDestroyOnLoad(root);
            _root = root.transform;
            _regionsRoot = new GameObject("Territory Regions").transform;
            _regionsRoot.SetParent(_root, false);
            _spotsRoot = new GameObject("Fishing Spot Markers").transform;
            _spotsRoot.SetParent(_root, false);

            _playerMaterial = MakeMaterial("M_PlayerMint", new Color(0.16f, 0.82f, 0.72f, 1f));
            _playerDarkMaterial = MakeMaterial("M_PlayerInk", new Color(0.03f, 0.18f, 0.25f, 1f));
            _radiusMaterial = MakeMaterial("M_PlayerRadius", new Color(0.35f, 0.92f, 1f, 0.18f), transparent: true);
            _whiteMaterial = MakeMaterial("M_GameWhite", new Color(1f, 0.98f, 0.88f, 1f));
            return Task.CompletedTask;
        }

        public void OnAllServicesReady()
        {
            var loc = ServiceLocator.Instance;
            _coords = loc.Resolve<ICoordinateService>();
            _bus = loc.Resolve<IEventBus>();
            _bus.Subscribe<GpsLocationChangedEvent>(OnGpsChanged);
            _bus.Subscribe<OriginShiftedEvent>(OnOriginShifted);

            TryBindBridge();
            EnsurePlayer(_coords.Origin);
        }

        public void Tick(float deltaTime)
        {
            _clock += deltaTime;
            if (!_bridgeBound) TryBindBridge();

            foreach (var state in _spotMarkers.Values)
            {
                var p = state.BasePosition;
                p.y += 0.55f + Mathf.Sin(_clock * 2.2f + state.BobPhase) * 0.7f;
                state.Root.position = p;
                state.Head.localRotation = Quaternion.Euler(0f, _clock * 34f + state.BobPhase * 20f, 0f);
            }

            if (_playerRoot != null)
            {
                var scale = 1f + Mathf.Sin(_clock * 2.0f) * 0.035f;
                _playerRoot.localScale = new Vector3(scale, 1f, scale);
            }
        }

        public void Dispose()
        {
            if (_bus != null)
            {
                _bus.Unsubscribe<GpsLocationChangedEvent>(OnGpsChanged);
                _bus.Unsubscribe<OriginShiftedEvent>(OnOriginShifted);
            }
            if (_bridge != null)
            {
                _bridge.SpotsChanged -= ApplySpots;
                _bridge.RegionsChanged -= ApplyRegions;
                _bridge.PlayerMoved -= SetPlayer;
            }
            if (_root != null) UnityEngine.Object.Destroy(_root.gameObject);
        }

        private void TryBindBridge()
        {
            if (_bridgeBound) return;
            _bridge = Bridge.Instance;
            if (_bridge == null) return;

            _bridge.SpotsChanged += ApplySpots;
            _bridge.RegionsChanged += ApplyRegions;
            _bridge.PlayerMoved += SetPlayer;
            _bridgeBound = true;

            if (_bridge.LatestSpots.Length > 0) ApplySpots(_bridge.LatestSpots);
            if (_bridge.LatestRegions.Length > 0) ApplyRegions(_bridge.LatestRegions);
            if (_bridge.PlayerCoordinate.HasValue) SetPlayer(_bridge.PlayerCoordinate.Value);
        }

        private void OnGpsChanged(GpsLocationChangedEvent evt)
            => SetPlayer(new GeoCoordinate(evt.latitude, evt.longitude));

        private void OnOriginShifted(OriginShiftedEvent evt)
        {
            if (_playerCoordinate.HasValue) PositionPlayer(_playerCoordinate.Value);
            RepositionSpots();
            RebuildRegions();
        }

        private void SetPlayer(GeoCoordinate coord)
        {
            _playerCoordinate = coord;
            EnsurePlayer(coord);
            PositionPlayer(coord);
        }

        private void EnsurePlayer(GeoCoordinate coord)
        {
            if (_playerRoot != null) return;

            _playerRoot = new GameObject("Player Avatar").transform;
            _playerRoot.SetParent(_root, false);

            CreatePrimitive(PrimitiveType.Cylinder, _playerRoot, "Interaction Radius",
                _radiusMaterial, new Vector3(0, 0.03f, 0), new Vector3(78f, 0.03f, 78f));
            CreatePrimitive(PrimitiveType.Cylinder, _playerRoot, "Inner Ring",
                _whiteMaterial, new Vector3(0, 0.06f, 0), new Vector3(28f, 0.025f, 28f));
            CreatePrimitive(PrimitiveType.Capsule, _playerRoot, "Body",
                _playerMaterial, new Vector3(0, 2.2f, 0), new Vector3(1.4f, 1.7f, 1.4f));
            CreatePrimitive(PrimitiveType.Sphere, _playerRoot, "Head",
                _whiteMaterial, new Vector3(0, 4.65f, 0), new Vector3(1.25f, 1.25f, 1.25f));
            CreatePrimitive(PrimitiveType.Sphere, _playerRoot, "Backpack",
                _playerDarkMaterial, new Vector3(0, 2.45f, -0.95f), new Vector3(1.5f, 1.8f, 0.7f));
            CreatePrimitive(PrimitiveType.Cube, _playerRoot, "Casting Direction",
                _playerDarkMaterial, new Vector3(0, 0.22f, 7.8f), new Vector3(1.0f, 0.16f, 8.0f));

            PositionPlayer(coord);
        }

        private void PositionPlayer(GeoCoordinate coord)
        {
            if (_playerRoot == null || _coords == null) return;
            var p = _coords.GeoToUnity(coord);
            p.y = 0f;
            _playerRoot.position = p;
        }

        private void ApplySpots(SpotPayload[] spots)
        {
            ClearChildren(_spotsRoot);
            _spotMarkers.Clear();
            if (spots == null) return;

            for (int i = 0; i < spots.Length; i++)
            {
                var payload = spots[i];
                if (string.IsNullOrEmpty(payload.id)) continue;
                _spotMarkers[payload.id] = CreateSpotMarker(payload, i);
            }
        }

        private SpotMarkerState CreateSpotMarker(SpotPayload spot, int index)
        {
            var root = new GameObject($"Spot Marker - {spot.name}");
            root.transform.SetParent(_spotsRoot, false);

            var color = SpotColor(spot);
            var glow = MakeMaterial($"M_SpotGlow_{spot.id}", WithAlpha(color, 0.22f), transparent: true);
            var core = MakeMaterial($"M_SpotCore_{spot.id}", color);
            var dark = MakeMaterial($"M_SpotDark_{spot.id}", new Color(0.05f, 0.20f, 0.24f, 1f));

            CreatePrimitive(PrimitiveType.Cylinder, root.transform, "Proximity Disc",
                glow, new Vector3(0, 0.08f, 0), new Vector3(28f, 0.025f, 28f));
            CreatePrimitive(PrimitiveType.Cylinder, root.transform, "Stem",
                _whiteMaterial, new Vector3(0, 2.2f, 0), new Vector3(1.2f, 4.2f, 1.2f));
            var head = CreatePrimitive(PrimitiveType.Sphere, root.transform, "Floating Spot",
                core, new Vector3(0, 6.0f, 0), new Vector3(5.6f, 5.6f, 5.6f));
            CreatePrimitive(PrimitiveType.Sphere, head.transform, "Icon Dot",
                dark, new Vector3(0.55f, 0.25f, -0.62f), new Vector3(0.36f, 0.36f, 0.36f));
            CreatePrimitive(PrimitiveType.Cube, head.transform, "Icon Tail",
                dark, new Vector3(-0.45f, -0.12f, -0.62f), new Vector3(1.1f, 0.45f, 0.45f));

            var collider = root.AddComponent<SphereCollider>();
            collider.center = new Vector3(0, 6f, 0);
            collider.radius = 6f;
            root.AddComponent<MapTapTarget>().ConfigureSpot(spot.id);

            var state = new SpotMarkerState
            {
                Root = root.transform,
                Head = head.transform,
                Payload = spot,
                BobPhase = index * 0.77f
            };
            state.BasePosition = CoordinateFor(spot.lat, spot.lng);
            state.Root.position = state.BasePosition;
            return state;
        }

        private void RepositionSpots()
        {
            foreach (var state in _spotMarkers.Values)
            {
                state.BasePosition = CoordinateFor(state.Payload.lat, state.Payload.lng);
                state.Root.position = state.BasePosition;
            }
        }

        private void ApplyRegions(RegionPayload[] regions)
        {
            _regions.Clear();
            if (regions != null)
            {
                for (int i = 0; i < regions.Length; i++)
                {
                    if (!string.IsNullOrEmpty(regions[i].id))
                    {
                        _regions[regions[i].id] = regions[i];
                    }
                }
            }
            RebuildRegions();
        }

        private void RebuildRegions()
        {
            ClearChildren(_regionsRoot);
            foreach (var region in _regions.Values) CreateRegion(region);
        }

        private void CreateRegion(RegionPayload region)
        {
            if (region.polygon == null || region.polygon.Length < 3) return;

            var go = new GameObject($"Territory - {region.name}");
            go.transform.SetParent(_regionsRoot, false);

            var verts = new Vector3[region.polygon.Length + 1];
            var center = Vector3.zero;
            for (int i = 0; i < region.polygon.Length; i++)
            {
                var p = CoordinateFor(region.polygon[i].lat, region.polygon[i].lng);
                p.y = 0.12f;
                verts[i + 1] = p;
                center += p;
            }
            center /= region.polygon.Length;
            center.y = 0.13f;
            verts[0] = center;

            var tris = new int[region.polygon.Length * 3];
            for (int i = 0; i < region.polygon.Length; i++)
            {
                int o = i * 3;
                tris[o] = 0;
                tris[o + 1] = i + 1;
                tris[o + 2] = i == region.polygon.Length - 1 ? 1 : i + 2;
            }

            var mesh = new Mesh { name = $"M_{region.id}_Territory" };
            mesh.vertices = verts;
            mesh.triangles = tris;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();

            var color = ParseHex(region.rulerColorHex, new Color(0.18f, 0.78f, 0.72f, 1f));
            float alpha = region.isCurrentUserRuler ? 0.24f : (region.isVacant ? 0.12f : 0.18f);
            var mf = go.AddComponent<MeshFilter>();
            var mr = go.AddComponent<MeshRenderer>();
            mf.sharedMesh = mesh;
            mr.sharedMaterial = MakeMaterial($"M_Region_{region.id}", WithAlpha(color, alpha), transparent: true);
            go.AddComponent<MeshCollider>().sharedMesh = mesh;
            go.AddComponent<MapTapTarget>().ConfigureRegion(region.id);
        }

        private Vector3 CoordinateFor(double lat, double lng)
        {
            if (_coords == null) return Vector3.zero;
            var p = _coords.GeoToUnity(new GeoCoordinate(lat, lng));
            p.y = 0.5f;
            return p;
        }

        private static Color SpotColor(SpotPayload spot)
        {
            if (spot.isCurrentUserKing)
            {
                return new Color(1.0f, 0.78f, 0.22f, 1f);
            }
            if (!string.IsNullOrEmpty(spot.kingColorHex))
            {
                return ParseHex(spot.kingColorHex, new Color(0.96f, 0.42f, 0.35f, 1f));
            }
            return new Color(0.12f, 0.82f, 0.82f, 1f);
        }

        private static GameObject CreatePrimitive(
            PrimitiveType type,
            Transform parent,
            string name,
            Material material,
            Vector3 localPosition,
            Vector3 localScale)
        {
            var go = GameObject.CreatePrimitive(type);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPosition;
            go.transform.localScale = localScale;
            var renderer = go.GetComponent<Renderer>();
            if (renderer != null) renderer.sharedMaterial = material;
            var collider = go.GetComponent<Collider>();
            if (collider != null) UnityEngine.Object.Destroy(collider);
            return go;
        }

        private static Material MakeMaterial(string name, Color color, bool transparent = false)
        {
            var shader = Shader.Find("Universal Render Pipeline/Unlit")
                ?? Shader.Find("Universal Render Pipeline/Lit")
                ?? Shader.Find("Standard");
            var mat = new Material(shader) { name = name };
            SetMaterialColor(mat, color);
            if (transparent || color.a < 0.999f) MakeTransparent(mat);
            return mat;
        }

        private static void SetMaterialColor(Material mat, Color color)
        {
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", color);
            else if (mat.HasProperty("_Color")) mat.SetColor("_Color", color);
        }

        private static void MakeTransparent(Material mat)
        {
            mat.SetFloat("_Surface", 1f);
            mat.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
            mat.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
            mat.SetFloat("_ZWrite", 0f);
            mat.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
            mat.renderQueue = (int)RenderQueue.Transparent;
        }

        private static Color ParseHex(string hex, Color fallback)
        {
            if (string.IsNullOrWhiteSpace(hex)) return fallback;
            var clean = hex.Trim().TrimStart('#');
            if (clean.Length != 6) return fallback;
            if (!int.TryParse(clean, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var value)) return fallback;
            return new Color(
                ((value >> 16) & 0xFF) / 255f,
                ((value >> 8) & 0xFF) / 255f,
                (value & 0xFF) / 255f,
                1f);
        }

        private static Color WithAlpha(Color color, float alpha)
            => new(color.r, color.g, color.b, alpha);

        private static void ClearChildren(Transform parent)
        {
            if (parent == null) return;
            for (int i = parent.childCount - 1; i >= 0; i--)
            {
                UnityEngine.Object.Destroy(parent.GetChild(i).gameObject);
            }
        }

        private sealed class SpotMarkerState
        {
            public Transform Root;
            public Transform Head;
            public SpotPayload Payload;
            public Vector3 BasePosition;
            public float BobPhase;
        }
    }

    public sealed class MapTapTarget : MonoBehaviour
    {
        private string _id;
        private bool _isRegion;

        public void ConfigureSpot(string id)
        {
            _id = id;
            _isRegion = false;
        }

        public void ConfigureRegion(string id)
        {
            _id = id;
            _isRegion = true;
        }

        private void OnMouseUpAsButton()
        {
            if (string.IsNullOrEmpty(_id)) return;
            if (_isRegion) Bridge.EmitRegionTapped(_id);
            else Bridge.EmitSpotTapped(_id);
        }
    }
}
