using PokemonGo.Camera;
using PokemonGo.Core;
using PokemonGo.Rendering;
using PokemonGo.Streaming;
using UnityEngine;

namespace PokemonGo.Bootstrap
{
    /// <summary>
    /// Per-frame LOD switcher that toggles per-layer renderers on active
    /// chunks based on the chunk's planar distance to the camera anchor.
    /// Lives in <see cref="PokemonGo.Bootstrap"/> so it can freely reference
    /// every subsystem (Streaming + Camera + Rendering) without inducing
    /// cycles in the leaf assemblies.
    ///
    /// We deliberately do not use Unity's <see cref="LODGroup"/> here
    /// because chunks are streamed runtime entities; aggregating them into
    /// shared LOD groups would force continuous structural edits which are
    /// expensive on mobile.
    /// </summary>
    [DefaultExecutionOrder(8000)]
    public sealed class ChunkLodController : MonoBehaviour
    {
        private IChunkManager _chunks;
        private IMapCameraService _camera;
        private EngineSettings _settings;
        private float _l1Distance, _l2Distance, _l3Distance;

        private void Start()
        {
            var rt = EngineRuntime.Active;
            if (rt == null) { enabled = false; return; }
            if (!rt.IsBooted) rt.BootCompleted += Bind;
            else Bind();
        }

        private void Bind()
        {
            _chunks   = ServiceLocator.Instance.Resolve<IChunkManager>();
            _camera   = ServiceLocator.Instance.Resolve<IMapCameraService>();
            _settings = EngineRuntime.Settings;
            _l1Distance = _settings.buildingFullDetailDistance;
            _l2Distance = _settings.maxRenderDistance * 0.6f;
            _l3Distance = _settings.maxRenderDistance;
        }

        private void LateUpdate()
        {
            if (_chunks == null || _camera == null) return;

            FrustumCuller.Update(_camera.Camera);
            Vector3 pivot = _camera.Pivot.position;

            foreach (var c in _chunks.ActiveChunks)
            {
                if (c.Root == null) continue;

                float dSqr = (c.WorldBounds.center - pivot).sqrMagnitude;
                c.DistanceToCameraSqr = dSqr;

                bool inFrustum = FrustumCuller.IsVisible(c.WorldBounds);
                if (!inFrustum) { c.Root.SetActive(false); continue; }

                if (!c.Root.activeSelf) c.Root.SetActive(true);

                int lod;
                if (dSqr < _l1Distance * _l1Distance)       lod = 0;
                else if (dSqr < _l2Distance * _l2Distance)  lod = 1;
                else if (dSqr < _l3Distance * _l3Distance)  lod = 2;
                else                                        lod = 3;

                if (lod == c.LodLevel) continue;
                c.LodLevel = lod;
                ApplyLod(c, lod);
            }
        }

        private void ApplyLod(Chunk c, int lod)
        {
            // Always-on layers
            SetActive(c.TerrainRoot, lod < 3);
            SetActive(c.WaterRoot,   lod < 3);
            SetActive(c.ParksRoot,   lod < 3);

            // Layers that collapse with distance
            SetActive(c.RoadsRoot,     lod < 2);
            SetActive(c.BuildingsRoot, lod < 2);
        }

        private static void SetActive(GameObject go, bool active)
        {
            if (go != null && go.activeSelf != active) go.SetActive(active);
        }
    }
}
