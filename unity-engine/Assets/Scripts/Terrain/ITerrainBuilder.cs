using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.VectorTiles;
using UnityEngine;

namespace PokemonGo.Terrain
{
    /// <summary>
    /// Minimal surface a builder needs from a streamed chunk. Implemented by
    /// <c>PokemonGo.Streaming.Chunk</c>. Defined here so the Terrain assembly
    /// does not have to reference Streaming (which already references Terrain
    /// — avoiding a circular dependency).
    /// </summary>
    public interface ITerrainBuildTarget
    {
        TileId Id { get; }
        VectorTile Tile { get; }
        Transform Transform { get; }
        Bounds WorldBounds { get; set; }

        GameObject TerrainRoot { get; set; }
        GameObject RoadsRoot { get; set; }
        GameObject BuildingsRoot { get; set; }
        GameObject WaterRoot { get; set; }
        GameObject ParksRoot { get; set; }

        void EnsureLayerRoot(ref GameObject root, string name);
    }

    public interface ITerrainBuilder : IService
    {
        Task BuildChunkAsync(ITerrainBuildTarget target, CancellationToken ct);
    }
}
