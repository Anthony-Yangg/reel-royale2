using PokemonGo.Camera;
using PokemonGo.Core;
using PokemonGo.DebugTools;
using PokemonGo.Rendering;
using UnityEngine;

namespace PokemonGo.Bootstrap
{
    /// <summary>
    /// Convenience component that spins up the engine in a fresh scene. Drop
    /// this on a single GameObject, assign an <see cref="EngineSettings"/>
    /// asset and press play — the engine will:
    /// <list type="number">
    ///   <item>Construct an <see cref="EngineRuntime"/> driver.</item>
    ///   <item>Register every service via <see cref="EngineBootstrap"/>.</item>
    ///   <item>Add the touch / mouse <see cref="MapCameraInput"/> handler.</item>
    ///   <item>Spawn the LOD controller and debug HUD.</item>
    ///   <item>Create a sky-dome using <c>PokemonGo/AtmosphereSkydome</c>.</item>
    /// </list>
    /// Lives in its own assembly so the Core asmdef stays leaf-light.
    /// </summary>
    [DefaultExecutionOrder(-11000)]
    [DisallowMultipleComponent]
    public sealed class EngineSceneBootstrap : MonoBehaviour
    {
        [SerializeField] private EngineSettings _settings;
        [SerializeField] private bool _spawnDebugHud = true;
        [SerializeField] private bool _spawnInput = true;
        [SerializeField] private bool _spawnLodController = true;
        [SerializeField] private bool _spawnSkydome = true;

        public EngineSettings Settings { get => _settings; set => _settings = value; }

        private void Awake()
        {
            var rt = gameObject.GetComponent<EngineRuntime>();
            if (rt == null) rt = gameObject.AddComponent<EngineRuntime>();
            AssignSettingsViaReflection(rt, _settings);

            if (_spawnInput)         gameObject.AddComponent<MapCameraInput>();
            if (_spawnLodController) gameObject.AddComponent<ChunkLodController>();
            if (_spawnDebugHud)      gameObject.AddComponent<DebugHud>();
            if (_spawnSkydome)       CreateSkydome();
        }

        private void CreateSkydome()
        {
            var sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphere.name = "Skydome";
            sphere.transform.SetParent(transform, false);
            sphere.transform.localScale = Vector3.one * 6000f;
            Destroy(sphere.GetComponent<Collider>());

            var mr = sphere.GetComponent<MeshRenderer>();
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            mr.receiveShadows = false;
            var sh = Shader.Find("PokemonGo/AtmosphereSkydome");
            if (sh != null) mr.sharedMaterial = new Material(sh) { name = "M_Sky" };
        }

        private static void AssignSettingsViaReflection(EngineRuntime rt, EngineSettings s)
        {
            // EngineRuntime exposes Settings only as a public static after Awake.
            // We still need to seed its private _settings field on inspector
            // workflows where the user assigned settings here, not on Runtime.
            var fld = typeof(EngineRuntime).GetField("_settings",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            if (fld != null && fld.GetValue(rt) == null) fld.SetValue(rt, s);
        }
    }
}
