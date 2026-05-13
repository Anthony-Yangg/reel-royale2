using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;

namespace PokemonGo.Streaming
{
    /// <summary>
    /// Tile fetcher abstraction. Implementations: HTTP, on-disk fixture
    /// replay (for offline dev), Addressables bundle, or a unit-test mock.
    /// </summary>
    public interface ITileDownloader : IService
    {
        Task<TileDownloadResult> DownloadAsync(TileId id, CancellationToken ct);
        int InFlight { get; }
        long BytesDownloaded { get; }
    }

    public readonly struct TileDownloadResult
    {
        public readonly TileId Id;
        public readonly byte[] Bytes;
        public readonly bool Success;
        public readonly string Error;
        public readonly int HttpStatus;

        public TileDownloadResult(TileId id, byte[] bytes, bool success, string error, int httpStatus)
        {
            Id = id; Bytes = bytes; Success = success; Error = error; HttpStatus = httpStatus;
        }

        public static TileDownloadResult Ok(TileId id, byte[] bytes, int status = 200)
            => new(id, bytes, true, null, status);
        public static TileDownloadResult Fail(TileId id, string err, int status)
            => new(id, null, false, err, status);
    }
}
