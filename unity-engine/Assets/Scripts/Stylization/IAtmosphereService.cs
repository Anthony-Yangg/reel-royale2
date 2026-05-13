using PokemonGo.Core;
using UnityEngine;

namespace PokemonGo.Rendering
{
    /// <summary>
    /// Drives the engine's global atmosphere: sky-gradient, fog, time-of-day
    /// sun direction, ambient color, emissive boost for nighttime windows.
    /// Implemented as a service so other systems (camera, debug UI) can
    /// query the current state without sampling lighting at runtime.
    /// </summary>
    public interface IAtmosphereService : IService, ILateTickable
    {
        /// <summary>Normalised time of day in [0,1). 0=midnight, 0.5=noon.</summary>
        float TimeOfDay01 { get; set; }
        bool AutoAdvance { get; set; }
        Color CurrentSunColor { get; }
        Color CurrentAmbientColor { get; }
        Color CurrentFogColor { get; }
        Vector3 SunDirection { get; }
    }
}
