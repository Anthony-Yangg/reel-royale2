using PokemonGo.Core;
using UnityEngine;

namespace PokemonGo.Rendering
{
    /// <summary>
    /// Single source of truth for engine materials. Materials are shared and
    /// SRP-batcher-compatible so the GPU draws hundreds of chunks in just a
    /// few draw calls. The library tries to load actual material assets from
    /// Resources/Materials first, then falls back to runtime-constructed
    /// instances using the stylized shaders so the engine can boot in any
    /// project state (including before art is authored).
    /// </summary>
    public interface IMaterialLibrary : IService
    {
        Material Terrain { get; }
        Material Road { get; }
        Material Building { get; }
        Material Water { get; }
        Material Park { get; }
        Material Landuse { get; }

        Material BuildingLOD { get; }
    }
}
