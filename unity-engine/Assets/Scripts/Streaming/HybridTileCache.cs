using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;
using UnityEngine;

namespace PokemonGo.Streaming
{
    public interface ITileCache : IService
    {
        Task<byte[]> TryGetAsync(TileId id, CancellationToken ct);
        Task PutAsync(TileId id, byte[] bytes, CancellationToken ct);
        int MemEntryCount { get; }
        long MemBytes { get; }
        long DiskBytes { get; }
        void Trim();
    }

    /// <summary>
    /// Two-level LRU tile cache:
    /// <list type="number">
    ///   <item>L1 — in-memory <see cref="byte[]"/> bag keyed by tile id.</item>
    ///   <item>L2 — application-persistent file directory under
    ///     <see cref="Application.persistentDataPath"/>/tiles/{z}/{x}/{y}.mvt.</item>
    /// </list>
    /// Both levels enforce byte budgets from <see cref="EngineSettings"/>
    /// via LRU eviction. Writes are async to keep the main thread free.
    /// </summary>
    public sealed class HybridTileCache : ITileCache
    {
        public string ServiceName => "HybridTileCache";
        public int InitOrder => -390;

        private readonly EngineSettings _settings;
        private readonly LinkedList<TileId> _lru = new();
        private readonly Dictionary<TileId, MemEntry> _mem = new(256);
        private long _memBytes;
        private long _diskBytes;
        private string _diskRoot;
        private readonly object _lock = new();

        public int MemEntryCount { get { lock (_lock) return _mem.Count; } }
        public long MemBytes => Interlocked.Read(ref _memBytes);
        public long DiskBytes => Interlocked.Read(ref _diskBytes);

        private class MemEntry
        {
            public byte[] Bytes;
            public LinkedListNode<TileId> Node;
            public long Bytes64 => Bytes?.LongLength ?? 0;
        }

        public HybridTileCache(EngineSettings settings) { _settings = settings; }

        public Task InitializeAsync(CancellationToken ct)
        {
            _diskRoot = Path.Combine(Application.persistentDataPath, "tiles");
            Directory.CreateDirectory(_diskRoot);
            _diskBytes = MeasureDirSize(_diskRoot);
            return Task.CompletedTask;
        }

        public void OnAllServicesReady() { }
        public void Dispose() { }

        public async Task<byte[]> TryGetAsync(TileId id, CancellationToken ct)
        {
            lock (_lock)
            {
                if (_mem.TryGetValue(id, out var e))
                {
                    _lru.Remove(e.Node);
                    _lru.AddFirst(e.Node);
                    return e.Bytes;
                }
            }

            string path = PathFor(id);
            if (!File.Exists(path)) return null;
            try
            {
                byte[] bytes;
                using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read,
                                              FileShare.Read, 4096, useAsync: true))
                {
                    bytes = new byte[fs.Length];
                    int total = 0;
                    while (total < bytes.Length)
                    {
                        int read = await fs.ReadAsync(bytes, total, bytes.Length - total, ct)
                                           .ConfigureAwait(false);
                        if (read <= 0) break;
                        total += read;
                    }
                }
                PutInMemory(id, bytes);
                return bytes;
            }
            catch (Exception e)
            {
                EngineLog.Warn($"Cache read failed {id}: {e.Message}");
                return null;
            }
        }

        public async Task PutAsync(TileId id, byte[] bytes, CancellationToken ct)
        {
            if (bytes == null || bytes.Length == 0) return;
            PutInMemory(id, bytes);

            try
            {
                string path = PathFor(id);
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                using var fs = new FileStream(path, FileMode.Create, FileAccess.Write,
                                              FileShare.None, 4096, useAsync: true);
                await fs.WriteAsync(bytes, 0, bytes.Length, ct).ConfigureAwait(false);
                Interlocked.Add(ref _diskBytes, bytes.LongLength);
                MaybeTrimDisk();
            }
            catch (Exception e)
            {
                EngineLog.Warn($"Cache write failed {id}: {e.Message}");
            }
        }

        private void PutInMemory(TileId id, byte[] bytes)
        {
            lock (_lock)
            {
                if (_mem.TryGetValue(id, out var existing))
                {
                    Interlocked.Add(ref _memBytes, -existing.Bytes64);
                    existing.Bytes = bytes;
                    _lru.Remove(existing.Node);
                    _lru.AddFirst(existing.Node);
                }
                else
                {
                    var node = _lru.AddFirst(id);
                    _mem[id] = new MemEntry { Bytes = bytes, Node = node };
                }
                Interlocked.Add(ref _memBytes, bytes.LongLength);
                TrimMemoryLocked();
            }
        }

        public void Trim()
        {
            lock (_lock) TrimMemoryLocked();
            MaybeTrimDisk();
        }

        private void TrimMemoryLocked()
        {
            long budget = (long)_settings.memoryCacheBudgetMB * 1024 * 1024;
            while (_memBytes > budget && _lru.Last != null)
            {
                var oldest = _lru.Last.Value;
                _lru.RemoveLast();
                if (_mem.TryGetValue(oldest, out var e))
                {
                    Interlocked.Add(ref _memBytes, -e.Bytes64);
                    _mem.Remove(oldest);
                }
            }
        }

        private void MaybeTrimDisk()
        {
            long budget = (long)_settings.diskCacheBudgetMB * 1024 * 1024;
            if (_diskBytes <= budget) return;

            try
            {
                var dir = new DirectoryInfo(_diskRoot);
                var files = dir.GetFiles("*.mvt", SearchOption.AllDirectories);
                Array.Sort(files, (a, b) => a.LastAccessTimeUtc.CompareTo(b.LastAccessTimeUtc));
                int i = 0;
                while (_diskBytes > budget * 0.9 && i < files.Length)
                {
                    long sz = files[i].Length;
                    try { files[i].Delete(); Interlocked.Add(ref _diskBytes, -sz); }
                    catch { /* ignore eviction errors */ }
                    i++;
                }
            }
            catch (Exception e)
            {
                EngineLog.Warn($"Cache disk trim failed: {e.Message}");
            }
        }

        private string PathFor(TileId id)
            => Path.Combine(_diskRoot, id.Z.ToString(), id.X.ToString(), id.Y + ".mvt");

        private static long MeasureDirSize(string root)
        {
            long total = 0;
            try
            {
                foreach (var f in new DirectoryInfo(root).GetFiles("*", SearchOption.AllDirectories))
                    total += f.Length;
            }
            catch { /* fresh install */ }
            return total;
        }
    }
}
