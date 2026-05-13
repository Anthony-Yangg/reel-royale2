using System.Collections.Generic;
using PokemonGo.Core;
using PokemonGo.GIS;

namespace PokemonGo.Streaming
{
    public interface IChunkManager : IService
    {
        Chunk GetOrCreate(TileId id);
        bool TryGet(TileId id, out Chunk chunk);
        void Release(TileId id);
        IReadOnlyCollection<Chunk> ActiveChunks { get; }
        int ActiveCount { get; }
        int PoolSize { get; }
    }
}
