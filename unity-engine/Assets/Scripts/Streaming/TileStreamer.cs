using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.Terrain;
using PokemonGo.VectorTiles;
using Unity.Mathematics;

namespace PokemonGo.Streaming
{
    /// <summary>
    /// Orchestrator that takes the camera/player <see cref="Anchor"/> position
    /// and ensures the right tiles are loaded, decoded, built and unloaded.
    ///
    /// Algorithm (per frame):
    /// <list type="number">
    ///   <item>Compute the slippy tile under the anchor.</item>
    ///   <item>Compute the visible ring set (radius from settings).</item>
    ///   <item>Diff against the active set; schedule loads / unloads.</item>
    ///   <item>Drive a small budget of background tasks (cache, decode, build)
    ///         so the main thread never stalls.</item>
    /// </list>
    /// </summary>
    public sealed class TileStreamer : ITileStreamer
    {
        public string ServiceName => "TileStreamer";
        public int InitOrder => -100;

        private readonly EngineSettings _settings;
        private GeoCoordinate _anchor;
        private int _zoom;
        private TileId _lastCenterTile = TileId.Invalid;
        private CancellationTokenSource _cts;

        private ITileCache _cache;
        private ITileDownloader _downloader;
        private IVectorTileDecoder _decoder;
        private IChunkManager _chunks;
        private ITerrainBuilder _builder;
        private IEventBus _bus;

        private readonly HashSet<TileId> _inFlight = new(64);
        private readonly object _inFlightLock = new();
        private readonly HashSet<TileId> _keep = new(128);
        private readonly List<TileId> _toRelease = new(64);

        public GeoCoordinate Anchor => _anchor;
        public int Zoom => _zoom;
        public int TilesActive => _chunks?.ActiveCount ?? 0;
        public int TilesInFlight { get { lock (_inFlightLock) return _inFlight.Count; } }
        public int TilesCached => _cache?.MemEntryCount ?? 0;

        public TileStreamer(EngineSettings settings)
        {
            _settings = settings;
            _zoom = settings.baseZoom;
            _anchor = new GeoCoordinate(settings.simulatedLatitude, settings.simulatedLongitude);
        }

        public Task InitializeAsync(CancellationToken ct)
        {
            _cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            return Task.CompletedTask;
        }

        public void OnAllServicesReady()
        {
            var loc = ServiceLocator.Instance;
            _cache      = loc.Resolve<ITileCache>();
            _downloader = loc.Resolve<ITileDownloader>();
            _decoder    = loc.Resolve<IVectorTileDecoder>();
            _chunks     = loc.Resolve<IChunkManager>();
            _builder    = loc.Resolve<ITerrainBuilder>();
            _bus        = loc.Resolve<IEventBus>();
        }

        public void SetAnchor(in GeoCoordinate coord)
        {
            _anchor = coord;
        }

        public void SetZoom(int z)
        {
            int clamped = math.clamp(z, 10, 18);
            if (clamped == _zoom) return;
            _zoom = clamped;
            ForceRefresh();
        }

        public void ForceRefresh() => _lastCenterTile = TileId.Invalid;

        public void Tick(float deltaTime)
        {
            var center = WebMercator.LatLngToTile(_anchor.Latitude, _anchor.Longitude, _zoom);
            var centerId = new TileId(_zoom, center.x, center.y);
            if (centerId.Equals(_lastCenterTile)) return;
            _lastCenterTile = centerId;

            UpdateVisibleSet(centerId);
        }

        // ------------------------------------------------------------------
        // Visible set diff
        // ------------------------------------------------------------------

        private void UpdateVisibleSet(TileId center)
        {
            int load = _settings.loadRadiusTiles;
            int retain = load + _settings.retainRadiusTiles;
            int n = 1 << _zoom;

            _keep.Clear();
            for (int dy = -retain; dy <= retain; dy++)
            {
                for (int dx = -retain; dx <= retain; dx++)
                {
                    int tx = ((center.X + dx) % n + n) % n; // wrap horizontally
                    int ty = center.Y + dy;
                    if (ty < 0 || ty >= n) continue;
                    _keep.Add(new TileId(_zoom, tx, ty));
                }
            }

            // Schedule loads inside the load radius (square wrt Chebyshev distance).
            for (int dy = -load; dy <= load; dy++)
            {
                for (int dx = -load; dx <= load; dx++)
                {
                    int tx = ((center.X + dx) % n + n) % n;
                    int ty = center.Y + dy;
                    if (ty < 0 || ty >= n) continue;
                    var id = new TileId(_zoom, tx, ty);
                    if (!_chunks.TryGet(id, out _) && TryBeginLoad(id))
                    {
                        _ = LoadTileAsync(id, _cts.Token);
                    }
                }
            }

            // Unload anything outside the retain radius.
            _toRelease.Clear();
            foreach (var existing in _chunks.ActiveChunks)
            {
                if (!_keep.Contains(existing.Id)) _toRelease.Add(existing.Id);
            }
            for (int i = 0; i < _toRelease.Count; i++)
            {
                _bus.Publish(new TileUnloadedEvent(_toRelease[i].Z, _toRelease[i].X, _toRelease[i].Y));
                _chunks.Release(_toRelease[i]);
            }
        }

        private bool TryBeginLoad(TileId id)
        {
            lock (_inFlightLock) return _inFlight.Add(id);
        }

        private void FinishLoad(TileId id)
        {
            lock (_inFlightLock) _inFlight.Remove(id);
        }

        // ------------------------------------------------------------------
        // Tile pipeline
        // ------------------------------------------------------------------

        private async Task LoadTileAsync(TileId id, CancellationToken ct)
        {
            try
            {
                byte[] bytes = await _cache.TryGetAsync(id, ct).ConfigureAwait(false);
                if (bytes == null || bytes.Length == 0)
                {
                    var dl = await _downloader.DownloadAsync(id, ct).ConfigureAwait(false);
                    if (!dl.Success || dl.Bytes == null || dl.Bytes.Length == 0)
                    {
                        EngineLog.Warn($"Tile {id} fetch failed: {dl.Error} ({dl.HttpStatus})");
                        return;
                    }
                    bytes = dl.Bytes;
                    await _cache.PutAsync(id, bytes, ct).ConfigureAwait(false);
                }

                var vt = await _decoder.DecodeAsync(bytes, id.Z, id.X, id.Y, ct).ConfigureAwait(false);
                if (ct.IsCancellationRequested) return;

                // The mesh build step must run on the main thread (Unity API
                // restriction). Hop back via Unity's SyncContext.
                await UnityMainThread.SwitchAsync(ct);
                if (ct.IsCancellationRequested) return;

                var chunk = _chunks.GetOrCreate(id);
                chunk.Tile = vt;
                chunk.State = ChunkState.Building;
                await _builder.BuildChunkAsync(chunk, ct).ConfigureAwait(false);
                if (chunk.State != ChunkState.Active) chunk.State = ChunkState.Active;
                _bus.Publish(new TileLoadedEvent(id.Z, id.X, id.Y));
                _bus.Publish(new ChunkActivatedEvent(id.Z, id.X, id.Y));
            }
            catch (OperationCanceledException) { /* graceful */ }
            catch (System.Exception e)
            {
                EngineLog.Error($"LoadTile {id} failed: {e}");
            }
            finally
            {
                FinishLoad(id);
            }
        }

        public void Dispose()
        {
            try { _cts?.Cancel(); } catch { }
            _cts?.Dispose();
        }
    }
}
