using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using UnityEngine;

namespace PokemonGo.Rendering
{
    /// <summary>
    /// Hand-tuned gradient ramps for sky, fog, sun and ambient at 4 keyframes
    /// (midnight, dawn, noon, dusk). The service pushes these as global
    /// shader variables every frame so every material — including custom
    /// HLSL — picks them up without per-material updates.
    /// </summary>
    public sealed class AtmosphereService : IAtmosphereService
    {
        public string ServiceName => "AtmosphereService";
        public int InitOrder => -120;

        // Global shader property hashes.
        private static readonly int _ID_SunDir       = Shader.PropertyToID("_PoGo_SunDir");
        private static readonly int _ID_SunColor     = Shader.PropertyToID("_PoGo_SunColor");
        private static readonly int _ID_AmbientColor = Shader.PropertyToID("_PoGo_AmbientColor");
        private static readonly int _ID_FogColor     = Shader.PropertyToID("_PoGo_FogColor");
        private static readonly int _ID_FogParams    = Shader.PropertyToID("_PoGo_FogParams");
        private static readonly int _ID_SkyTop       = Shader.PropertyToID("_PoGo_SkyTop");
        private static readonly int _ID_SkyHorizon   = Shader.PropertyToID("_PoGo_SkyHorizon");
        private static readonly int _ID_NightGlow    = Shader.PropertyToID("_PoGo_NightGlow");
        private static readonly int _ID_TimeOfDay    = Shader.PropertyToID("_PoGo_TimeOfDay");
        private static readonly int _ID_WorldOrigin  = Shader.PropertyToID("_PoGo_WorldOrigin");

        private readonly EngineSettings _settings;
        public float TimeOfDay01 { get; set; }
        public bool AutoAdvance { get; set; } = false;
        public Color CurrentSunColor { get; private set; }
        public Color CurrentAmbientColor { get; private set; }
        public Color CurrentFogColor { get; private set; }
        public Vector3 SunDirection { get; private set; }

        // Keyframe palette (midnight, dawn, noon, dusk).
        private static readonly Color[] kSun = {
            new(0.20f, 0.25f, 0.45f), new(1.00f, 0.78f, 0.60f),
            new(1.00f, 0.97f, 0.92f), new(1.00f, 0.62f, 0.45f)
        };
        private static readonly Color[] kAmbient = {
            new(0.10f, 0.12f, 0.20f), new(0.55f, 0.50f, 0.55f),
            new(0.85f, 0.88f, 0.94f), new(0.50f, 0.40f, 0.45f)
        };
        private static readonly Color[] kFog = {
            new(0.08f, 0.10f, 0.18f), new(0.78f, 0.70f, 0.72f),
            new(0.84f, 0.92f, 0.98f), new(0.92f, 0.65f, 0.55f)
        };
        private static readonly Color[] kSkyTop = {
            new(0.05f, 0.07f, 0.18f), new(0.40f, 0.55f, 0.85f),
            new(0.45f, 0.72f, 0.95f), new(0.70f, 0.45f, 0.65f)
        };
        private static readonly Color[] kSkyHorizon = {
            new(0.10f, 0.10f, 0.25f), new(1.00f, 0.78f, 0.70f),
            new(0.85f, 0.92f, 1.00f), new(1.00f, 0.62f, 0.55f)
        };
        private static readonly float[] kNightGlow = { 1.0f, 0.4f, 0.0f, 0.4f };

        public AtmosphereService(EngineSettings settings)
        {
            _settings = settings;
            TimeOfDay01 = Mathf.Clamp01(settings.atmosphereTimeOfDay01);
        }

        public Task InitializeAsync(CancellationToken ct) => Task.CompletedTask;
        public void OnAllServicesReady() => PushGlobals();
        public void Dispose() { }

        public void LateTick(float dt)
        {
            if (AutoAdvance) TimeOfDay01 = Mathf.Repeat(TimeOfDay01 + dt / 240f, 1f);
            PushGlobals();
        }

        private void PushGlobals()
        {
            float t = TimeOfDay01;
            (int a, int b, float lerp) = TimeOfDayPhase(t);

            CurrentSunColor     = Color.Lerp(kSun[a],        kSun[b],        lerp);
            CurrentAmbientColor = Color.Lerp(kAmbient[a],    kAmbient[b],    lerp);
            CurrentFogColor     = Color.Lerp(kFog[a],        kFog[b],        lerp);
            Color skyTop        = Color.Lerp(kSkyTop[a],     kSkyTop[b],     lerp);
            Color skyHor        = Color.Lerp(kSkyHorizon[a], kSkyHorizon[b], lerp);
            float nightGlow     = Mathf.Lerp(kNightGlow[a],  kNightGlow[b],  lerp);

            // Sun arcs across the sky (south-up local).
            float angle = (t - 0.25f) * Mathf.PI * 2f;
            SunDirection = new Vector3(Mathf.Cos(angle), Mathf.Sin(angle), 0.1f).normalized;

            Shader.SetGlobalVector(_ID_SunDir, new Vector4(-SunDirection.x, -SunDirection.y, -SunDirection.z, 0));
            Shader.SetGlobalColor(_ID_SunColor, CurrentSunColor);
            Shader.SetGlobalColor(_ID_AmbientColor, CurrentAmbientColor);
            Shader.SetGlobalColor(_ID_FogColor, CurrentFogColor);
            // x = start, y = end, z = density, w = exponent
            Shader.SetGlobalVector(_ID_FogParams, new Vector4(150f, _settings.maxRenderDistance, 0.85f, 1.4f));
            Shader.SetGlobalColor(_ID_SkyTop, skyTop);
            Shader.SetGlobalColor(_ID_SkyHorizon, skyHor);
            Shader.SetGlobalFloat(_ID_NightGlow, nightGlow);
            Shader.SetGlobalFloat(_ID_TimeOfDay, t);
            Shader.SetGlobalVector(_ID_WorldOrigin, Vector4.zero);
        }

        private static (int a, int b, float t) TimeOfDayPhase(float tod)
        {
            float scaled = tod * 4f; // 4 keyframes
            int a = Mathf.FloorToInt(scaled) % 4;
            int b = (a + 1) % 4;
            float lerp = scaled - Mathf.Floor(scaled);
            return (a, b, lerp);
        }
    }
}
