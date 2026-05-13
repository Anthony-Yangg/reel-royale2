using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.Rendering;
using UnityEngine;

namespace PokemonGo.Streaming
{
    /// <summary>
    /// Owns the active chunk dictionary and a free-list of recycled Chunk
    /// GameObjects. Chunks are heavy (have child renderers and mesh handles)
    /// so we pool them aggressively — destroying and reallocating them on
    /// every pan kills mobile frame times due to GC and Mesh registration.
    /// </summary>
    public sealed class ChunkManager : IChunkManager
    {
        public string ServiceName => "ChunkManager";
        public int InitOrder => -350;

        private readonly Transform _parent;
        private readonly EngineSettings _settings;
        private readonly Dictionary<TileId, Chunk> _active = new(128);
        private readonly Stack<Chunk> _pool = new(64);
        private Transform _worldRoot;
        private IMeshPool _meshPool;

        public IReadOnlyCollection<Chunk> ActiveChunks => _active.Values;
        public int ActiveCount => _active.Count;
        public int PoolSize => _pool.Count;

        public ChunkManager(EngineSettings settings, Transform parent)
        {
            _settings = settings;
            _parent = parent;
        }

        public Task InitializeAsync(CancellationToken ct)
        {
            var go = new GameObject("WorldRoot");
            go.transform.SetParent(_parent, false);
            _worldRoot = go.transform;
            return Task.CompletedTask;
        }

        public void OnAllServicesReady()
        {
            // Translate the entire baked world when the floating origin shifts
            // so that pre-baked meshes stay registered to their real lat/lng.
            var loc = ServiceLocator.Instance;
            _meshPool = loc.Resolve<IMeshPool>();
            var bus = loc.Resolve<IEventBus>();
            bus.Subscribe<OriginShiftedEvent>(OnOriginShifted);
        }

        private void OnOriginShifted(OriginShiftedEvent evt)
        {
            if (_worldRoot != null)
                _worldRoot.position += evt.deltaMeters;
        }

        public Chunk GetOrCreate(TileId id)
        {
            if (_active.TryGetValue(id, out var existing)) return existing;

            Chunk c;
            if (_pool.Count > 0)
            {
                c = _pool.Pop();
                c.Id = id;
                c.Root.name = $"Chunk_{id}";
                c.Root.SetActive(true);
                c.State = ChunkState.Idle;
                _active[id] = c;
                return c;
            }

            c = new Chunk(id, _worldRoot, _meshPool);
            _active[id] = c;
            return c;
        }

        public bool TryGet(TileId id, out Chunk chunk) => _active.TryGetValue(id, out chunk);

        public void Release(TileId id)
        {
            if (!_active.TryGetValue(id, out var chunk)) return;
            _active.Remove(id);
            chunk.ClearLayers();
            chunk.State = ChunkState.Idle;
            chunk.Root.SetActive(false);
            _pool.Push(chunk);
        }

        public void Dispose()
        {
            foreach (var c in _active.Values) c.Dispose();
            foreach (var c in _pool) c.Dispose();
            _active.Clear();
            _pool.Clear();
        }
    }
}
