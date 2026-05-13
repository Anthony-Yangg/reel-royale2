using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.Rendering;
using PokemonGo.VectorTiles;
using UnityEngine;

namespace PokemonGo.Terrain
{
    /// <summary>
    /// Builds the renderable mesh hierarchy for a single chunk by dispatching
    /// each layer to its specialised generator. Runs on the main thread but
    /// budgets total work using <see cref="EngineSettings.mainThreadGenBudgetMs"/>
    /// to avoid framerate spikes during pans.
    /// </summary>
    public sealed class TerrainBuilder : ITerrainBuilder
    {
        public string ServiceName => "TerrainBuilder";
        public int InitOrder => -300;

        private readonly EngineSettings _settings;
        private ICoordinateService _coords;
        private IMaterialLibrary _materials;
        private IMeshPool _pool;
        private readonly List<Renderer> _rendererScratch = new(16);

        public TerrainBuilder(EngineSettings settings) { _settings = settings; }

        public Task InitializeAsync(CancellationToken ct) => Task.CompletedTask;

        public void OnAllServicesReady()
        {
            var loc = ServiceLocator.Instance;
            _coords    = loc.Resolve<ICoordinateService>();
            _materials = loc.Resolve<IMaterialLibrary>();
            _pool      = loc.Resolve<IMeshPool>();
        }

        public async Task BuildChunkAsync(ITerrainBuildTarget chunk, CancellationToken ct)
        {
            if (chunk?.Tile == null) return;
            var tile = chunk.Tile;
            int z = tile.Z, x = tile.X, y = tile.Y;

            // Terrain base ----------------------------------------------------
            var terrainRoot = chunk.TerrainRoot;
            chunk.EnsureLayerRoot(ref terrainRoot, "Terrain");
            chunk.TerrainRoot = terrainRoot;
            BuildLayer(chunk.TerrainRoot, _materials.Terrain, builder =>
                TerrainBaseGenerator.Build(builder, _coords, z, x, y,
                    new Color32(154, 226, 194, 255), -0.02f));

            await YieldIfBudgetExceeded(ct);

            // Water -----------------------------------------------------------
            var water = tile.FindLayer(LayerKind.Water);
            if (water != null && water.Features.Count > 0)
            {
                var waterRoot = chunk.WaterRoot;
                chunk.EnsureLayerRoot(ref waterRoot, "Water");
                chunk.WaterRoot = waterRoot;
                BuildLayer(chunk.WaterRoot, _materials.Water, builder =>
                    PolygonMeshGenerator.BuildFlat(water, builder, _coords,
                        z, x, y, new Color32(82, 188, 226, 255), 0.01f));
            }
            await YieldIfBudgetExceeded(ct);

            // Parks -----------------------------------------------------------
            var parks = tile.FindLayer(LayerKind.Park);
            if (parks != null && parks.Features.Count > 0)
            {
                var parksRoot = chunk.ParksRoot;
                chunk.EnsureLayerRoot(ref parksRoot, "Parks");
                chunk.ParksRoot = parksRoot;
                BuildLayer(chunk.ParksRoot, _materials.Park, builder =>
                    PolygonMeshGenerator.BuildFlat(parks, builder, _coords,
                        z, x, y, new Color32(92, 202, 90, 255), 0.02f));
            }
            await YieldIfBudgetExceeded(ct);

            // Landuse (fallback overlay) --------------------------------------
            var land = tile.FindLayer(LayerKind.Landuse);
            if (land != null && land.Features.Count > 0)
            {
                BuildLayer(chunk.TerrainRoot, _materials.Landuse, builder =>
                    PolygonMeshGenerator.BuildFlat(land, builder, _coords,
                        z, x, y, new Color32(124, 216, 178, 255), 0.015f));
            }
            await YieldIfBudgetExceeded(ct);

            // Roads ----------------------------------------------------------
            var roads = tile.FindLayer(LayerKind.Road);
            if (roads != null && roads.Features.Count > 0)
            {
                var roadsRoot = chunk.RoadsRoot;
                chunk.EnsureLayerRoot(ref roadsRoot, "Roads");
                chunk.RoadsRoot = roadsRoot;
                BuildLayer(chunk.RoadsRoot, _materials.Road, builder =>
                    RoadMeshGenerator.Build(roads, builder, _coords, z, x, y, 0.05f));
            }
            await YieldIfBudgetExceeded(ct);

            // Buildings ------------------------------------------------------
            var buildings = tile.FindLayer(LayerKind.Building);
            if (buildings != null && buildings.Features.Count > 0)
            {
                var bRoot = chunk.BuildingsRoot;
                chunk.EnsureLayerRoot(ref bRoot, "Buildings");
                chunk.BuildingsRoot = bRoot;
                BuildLayer(chunk.BuildingsRoot, _materials.Building, builder =>
                    BuildingMeshGenerator.Build(buildings, builder, _coords,
                                                _settings, z, x, y));
            }

            // Update chunk bounds for culling.
            chunk.WorldBounds = ComputeBounds(chunk.Transform.gameObject);
        }

        // ------------------------------------------------------------------
        // Helpers
        // ------------------------------------------------------------------

        private void BuildLayer(GameObject root, Material material, System.Action<MeshData> fill)
        {
            var data = _pool.RentMeshData();
            try
            {
                fill(data);
                if (data.Vertices.Count == 0) return;
                var go = new GameObject("Layer", typeof(MeshFilter), typeof(MeshRenderer));
                go.transform.SetParent(root.transform, false);
                go.isStatic = true;
                var mf = go.GetComponent<MeshFilter>();
                var mr = go.GetComponent<MeshRenderer>();
                var mesh = _pool.RentMesh();
                data.ApplyTo(mesh);
                mf.sharedMesh = mesh;
                mr.sharedMaterial = material;
                mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                mr.lightProbeUsage = UnityEngine.Rendering.LightProbeUsage.Off;
                mr.reflectionProbeUsage = UnityEngine.Rendering.ReflectionProbeUsage.Off;
                mr.allowOcclusionWhenDynamic = false;
            }
            finally
            {
                _pool.ReturnMeshData(data);
            }
        }

        private Bounds ComputeBounds(GameObject root)
        {
            _rendererScratch.Clear();
            root.GetComponentsInChildren(_rendererScratch);
            if (_rendererScratch.Count == 0) return new Bounds(root.transform.position, Vector3.one);
            var b = _rendererScratch[0].bounds;
            for (int i = 1; i < _rendererScratch.Count; i++) b.Encapsulate(_rendererScratch[i].bounds);
            _rendererScratch.Clear();
            return b;
        }

        private float _budgetUsedMs;
        private System.Diagnostics.Stopwatch _sw;

        private async Task YieldIfBudgetExceeded(CancellationToken ct)
        {
            _sw ??= System.Diagnostics.Stopwatch.StartNew();
            _budgetUsedMs += (float)_sw.Elapsed.TotalMilliseconds;
            _sw.Restart();
            if (_budgetUsedMs >= _settings.mainThreadGenBudgetMs)
            {
                _budgetUsedMs = 0f;
                await Task.Yield();
            }
            if (ct.IsCancellationRequested) ct.ThrowIfCancellationRequested();
        }

        public void Dispose() { }
    }
}
