using PokemonGo.Core;
using PokemonGo.GIS;

namespace PokemonGo.Streaming
{
    public interface ITileStreamer : IService, ITickable
    {
        void SetAnchor(in GeoCoordinate coord);
        GeoCoordinate Anchor { get; }
        int Zoom { get; }
        void SetZoom(int z);
        int TilesActive { get; }
        int TilesInFlight { get; }
        int TilesCached { get; }
        void ForceRefresh();
    }
}
