using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using UnityEngine;

namespace PokemonGo.Rendering
{
    /// <summary>
    /// Default material library implementation. Attempts to load
    /// pre-authored materials from <c>Resources/Materials</c>; if any are
    /// missing it synthesises fallback materials from the stylized shaders
    /// shipped under <c>Assets/Shaders</c>. This lets the engine run
    /// end-to-end without first creating .mat assets in the editor.
    /// </summary>
    public sealed class MaterialLibrary : IMaterialLibrary
    {
        public string ServiceName => "MaterialLibrary";
        public int InitOrder => -250;

        private readonly EngineSettings _settings;

        public Material Terrain { get; private set; }
        public Material Road { get; private set; }
        public Material Building { get; private set; }
        public Material Water { get; private set; }
        public Material Park { get; private set; }
        public Material Landuse { get; private set; }
        public Material BuildingLOD { get; private set; }

        public MaterialLibrary(EngineSettings settings) { _settings = settings; }

        public Task InitializeAsync(CancellationToken ct)
        {
            Terrain     = Load("M_Terrain")  ?? Synth("PokemonGo/StylizedTerrain",  Color.white);
            Road        = Load("M_Road")     ?? Synth("PokemonGo/EmissiveRoad",     new Color(0.045f, 0.098f, 0.165f));
            Building    = Load("M_Building") ?? Synth("PokemonGo/StylizedBuilding", new Color(0.48f, 0.52f, 0.62f));
            Water       = Load("M_Water")    ?? Synth("PokemonGo/StylizedWater",    new Color(0.18f, 0.52f, 0.72f));
            Park        = Load("M_Park")     ?? Synth("PokemonGo/StylizedTerrain",  Color.white);
            Landuse     = Load("M_Landuse")  ?? Synth("PokemonGo/StylizedTerrain",  Color.white);
            BuildingLOD = Load("M_BuildingLOD") ?? Synth("PokemonGo/StylizedBuilding", new Color(0.38f, 0.42f, 0.52f));

            ApplyNightRoadWaterDefaults(Road, Water);

            foreach (var m in new[] { Terrain, Road, Building, Water, Park, Landuse, BuildingLOD })
            {
                if (m == null) continue;
                m.enableInstancing = _settings.enableGpuInstancing;
            }
            return Task.CompletedTask;
        }

        public void OnAllServicesReady() { }
        public void Dispose() { }

        private static Material Load(string name)
        {
            var m = Resources.Load<Material>($"Materials/{name}");
            return m;
        }

        /// <summary>
        /// Pokémon GO–night tuning when materials are shader-synthesised (no .mat assets).
        /// </summary>
        private static void ApplyNightRoadWaterDefaults(Material road, Material water)
        {
            if (road != null)
            {
                if (road.HasProperty("_EdgeColor"))
                    road.SetColor("_EdgeColor", new Color(0.05f, 0.72f, 0.92f));
                if (road.HasProperty("_NightColor"))
                    road.SetColor("_NightColor", new Color(0.35f, 0.92f, 1f));
                if (road.HasProperty("_NightIntensity"))
                    road.SetFloat("_NightIntensity", 2.1f);
                if (road.HasProperty("_EdgeWidth"))
                    road.SetFloat("_EdgeWidth", 0.22f);
            }
            if (water != null)
            {
                if (water.HasProperty("_DeepColor"))
                    water.SetColor("_DeepColor", new Color(0.015f, 0.13f, 0.34f));
                if (water.HasProperty("_ShallowColor"))
                    water.SetColor("_ShallowColor", new Color(0.06f, 0.30f, 0.52f));
                if (water.HasProperty("_NightEmissive"))
                    water.SetColor("_NightEmissive", new Color(0.15f, 0.38f, 0.72f));
            }
        }

        private static Material Synth(string shaderName, Color color)
        {
            var sh = Shader.Find(shaderName);
            if (sh == null)
            {
                EngineLog.Warn($"Shader '{shaderName}' not found; using URP/Lit fallback.");
                sh = Shader.Find("Universal Render Pipeline/Lit");
            }
            var mat = new Material(sh) { name = $"M_Auto_{shaderName.Replace('/', '_')}" };
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", color);
            else if (mat.HasProperty("_Color")) mat.SetColor("_Color", color);
            return mat;
        }
    }
}
