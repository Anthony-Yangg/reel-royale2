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
            Terrain     = Load("M_Terrain")  ?? Synth("PokemonGo/StylizedTerrain",  new Color(0.60f, 0.92f, 0.78f));
            Road        = Load("M_Road")     ?? Synth("PokemonGo/EmissiveRoad",     new Color(0.98f, 0.86f, 0.56f));
            Building    = Load("M_Building") ?? Synth("PokemonGo/StylizedBuilding", new Color(0.88f, 0.94f, 0.90f));
            Water       = Load("M_Water")    ?? Synth("PokemonGo/StylizedWater",    new Color(0.36f, 0.76f, 0.92f));
            Park        = Load("M_Park")     ?? Synth("PokemonGo/StylizedTerrain",  Color.white);
            Landuse     = Load("M_Landuse")  ?? Synth("PokemonGo/StylizedTerrain",  Color.white);
            BuildingLOD = Load("M_BuildingLOD") ?? Synth("PokemonGo/StylizedBuilding", new Color(0.74f, 0.84f, 0.84f));

            ApplyDaylightDefaults(Terrain, Road, Building, Water, Park, Landuse, BuildingLOD);

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
        /// Daylight location-game tuning when materials are shader-synthesised (no .mat assets).
        /// </summary>
        private static void ApplyDaylightDefaults(
            Material terrain,
            Material road,
            Material building,
            Material water,
            Material park,
            Material landuse,
            Material buildingLod)
        {
            if (terrain != null)
            {
                if (terrain.HasProperty("_BaseColor"))
                    terrain.SetColor("_BaseColor", new Color(0.58f, 0.92f, 0.78f));
                if (terrain.HasProperty("_Saturation"))
                    terrain.SetFloat("_Saturation", 1.18f);
            }
            if (road != null)
            {
                if (road.HasProperty("_BaseColor"))
                    road.SetColor("_BaseColor", new Color(0.96f, 0.82f, 0.50f));
                if (road.HasProperty("_EdgeColor"))
                    road.SetColor("_EdgeColor", new Color(0.18f, 0.44f, 0.50f));
                if (road.HasProperty("_NightColor"))
                    road.SetColor("_NightColor", new Color(1.0f, 0.70f, 0.35f));
                if (road.HasProperty("_NightIntensity"))
                    road.SetFloat("_NightIntensity", 0.55f);
                if (road.HasProperty("_EdgeWidth"))
                    road.SetFloat("_EdgeWidth", 0.24f);
                if (road.HasProperty("_CenterStripe"))
                    road.SetFloat("_CenterStripe", 0.18f);
            }
            if (building != null)
            {
                if (building.HasProperty("_BaseColor"))
                    building.SetColor("_BaseColor", new Color(0.90f, 0.96f, 0.91f));
                if (building.HasProperty("_RoofColor"))
                    building.SetColor("_RoofColor", new Color(0.76f, 0.88f, 0.88f));
                if (building.HasProperty("_ShadowColor"))
                    building.SetColor("_ShadowColor", new Color(0.54f, 0.66f, 0.72f));
            }
            if (water != null)
            {
                if (water.HasProperty("_DeepColor"))
                    water.SetColor("_DeepColor", new Color(0.18f, 0.58f, 0.84f));
                if (water.HasProperty("_ShallowColor"))
                    water.SetColor("_ShallowColor", new Color(0.58f, 0.90f, 0.96f));
                if (water.HasProperty("_NightEmissive"))
                    water.SetColor("_NightEmissive", new Color(0.26f, 0.68f, 0.96f));
                if (water.HasProperty("_CausticsStrength"))
                    water.SetFloat("_CausticsStrength", 0.72f);
            }
            if (park != null)
            {
                if (park.HasProperty("_BaseColor"))
                    park.SetColor("_BaseColor", new Color(0.50f, 0.88f, 0.42f));
                if (park.HasProperty("_Saturation"))
                    park.SetFloat("_Saturation", 1.22f);
            }
            if (landuse != null)
            {
                if (landuse.HasProperty("_BaseColor"))
                    landuse.SetColor("_BaseColor", new Color(0.50f, 0.84f, 0.70f));
                if (landuse.HasProperty("_Saturation"))
                    landuse.SetFloat("_Saturation", 1.14f);
            }
            if (buildingLod != null)
            {
                if (buildingLod.HasProperty("_BaseColor"))
                    buildingLod.SetColor("_BaseColor", new Color(0.74f, 0.84f, 0.84f));
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
