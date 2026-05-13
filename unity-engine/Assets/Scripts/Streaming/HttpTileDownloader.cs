using System;
using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;
using UnityEngine;
using UnityEngine.Networking;

namespace PokemonGo.Streaming
{
    /// <summary>
    /// Concurrency-limited HTTP downloader using UnityWebRequest so it works
    /// on Android/iOS without depending on .NET's HttpClient (which has had
    /// instability on IL2CPP across Unity versions).
    /// </summary>
    public sealed class HttpTileDownloader : ITileDownloader
    {
        public string ServiceName => "HttpTileDownloader";
        public int InitOrder => -400;

        private readonly EngineSettings _settings;
        private SemaphoreSlim _gate;
        private int _inFlight;
        private long _bytes;

        public int InFlight => _inFlight;
        public long BytesDownloaded => _bytes;

        public HttpTileDownloader(EngineSettings settings) { _settings = settings; }

        public Task InitializeAsync(CancellationToken ct)
        {
            _gate = new SemaphoreSlim(_settings.maxConcurrentDownloads, _settings.maxConcurrentDownloads);
            return Task.CompletedTask;
        }

        public void OnAllServicesReady() { }
        public void Dispose() => _gate?.Dispose();

        public async Task<TileDownloadResult> DownloadAsync(TileId id, CancellationToken ct)
        {
            await _gate.WaitAsync(ct).ConfigureAwait(false);
            Interlocked.Increment(ref _inFlight);
            try
            {
                await UnityMainThread.SwitchAsync(ct);
                string url = BuildUrl(id);
                using var req = UnityWebRequest.Get(url);
                req.timeout = 12;
                req.SetRequestHeader("Accept-Encoding", "gzip");
                req.SetRequestHeader("User-Agent", "PokemonGoEngine/1.0 (Unity)");

                var op = req.SendWebRequest();
                while (!op.isDone)
                {
                    if (ct.IsCancellationRequested)
                    {
                        req.Abort();
                        return TileDownloadResult.Fail(id, "cancelled", -1);
                    }
                    await Task.Yield();
                }

                if (req.result != UnityWebRequest.Result.Success)
                {
                    return TileDownloadResult.Fail(id, req.error, (int)req.responseCode);
                }

                var bytes = req.downloadHandler.data;
                Interlocked.Add(ref _bytes, bytes != null ? bytes.LongLength : 0);
                return TileDownloadResult.Ok(id, bytes ?? Array.Empty<byte>(), (int)req.responseCode);
            }
            catch (OperationCanceledException)
            {
                return TileDownloadResult.Fail(id, "cancelled", -1);
            }
            catch (Exception e)
            {
                return TileDownloadResult.Fail(id, e.Message, -1);
            }
            finally
            {
                Interlocked.Decrement(ref _inFlight);
                _gate.Release();
            }
        }

        private string BuildUrl(TileId id)
        {
            string token = _settings.mapboxAccessToken ?? "";
            return _settings.vectorTileUrlTemplate
                .Replace("{z}", id.Z.ToString())
                .Replace("{x}", id.X.ToString())
                .Replace("{y}", id.Y.ToString())
                .Replace("{token}", token);
        }
    }
}
