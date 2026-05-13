using PokemonGo.Core;
using PokemonGo.GIS;

namespace PokemonGo.GPS
{
    public interface IGpsService : IService, ITickable
    {
        bool IsAvailable { get; }
        bool IsSimulated { get; }
        GeoCoordinate Current { get; }
        float HeadingDegrees { get; }
        float AccuracyMeters { get; }
        float SpeedMps { get; }

        void SetSimulatedTarget(in GeoCoordinate target);
    }
}
