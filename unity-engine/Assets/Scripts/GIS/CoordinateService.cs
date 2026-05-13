using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using Unity.Mathematics;
using UnityEngine;

namespace PokemonGo.GIS
{
    /// <summary>
    /// Authoritative coordinate transform service. Owns the engine's
    /// floating-origin so that Unity worldspace coordinates stay near
    /// (0,0,0) for float precision. The "origin" is a chosen lat/lng that
    /// shifts as the player walks far away.
    /// </summary>
    public interface ICoordinateService : IService
    {
        GeoCoordinate Origin { get; }
        double2 OriginMeters { get; }
        void SetOrigin(GeoCoordinate origin);

        Vector3 GeoToUnity(in GeoCoordinate geo);
        GeoCoordinate UnityToGeo(in Vector3 unity);
        Vector3 MetersToUnity(double2 webMercatorMeters);
        double2 UnityToMeters(in Vector3 unity);

        /// <summary>Re-anchor the origin when the camera pivot drifts too far.</summary>
        bool MaybeShiftOrigin(in Vector3 cameraPivot, out Vector3 deltaApplied);
    }

    public sealed class CoordinateService : ICoordinateService
    {
        public string ServiceName => "CoordinateService";
        public int InitOrder => -900;

        private readonly EngineSettings _settings;
        private GeoCoordinate _origin;
        private double2 _originMeters;
        private IEventBus _bus;

        public GeoCoordinate Origin => _origin;
        public double2 OriginMeters => _originMeters;

        public CoordinateService(EngineSettings settings)
        {
            _settings = settings;
            _origin = new GeoCoordinate(_settings.simulatedLatitude, _settings.simulatedLongitude);
            _originMeters = WebMercator.LatLngToMeters(_origin.Latitude, _origin.Longitude);
        }

        public Task InitializeAsync(CancellationToken ct) => Task.CompletedTask;

        public void OnAllServicesReady()
        {
            _bus = ServiceLocator.Instance.Resolve<IEventBus>();
        }

        public void SetOrigin(GeoCoordinate origin)
        {
            _origin = origin;
            _originMeters = WebMercator.LatLngToMeters(origin.Latitude, origin.Longitude);
        }

        /// <summary>
        /// Lat/Lng → Unity world position. Unity's +X is east, +Z is north.
        /// Web Mercator y increases north too so a sign flip on Z is *not*
        /// needed (we use the meters value directly). We invert in
        /// <see cref="WebMercator.VectorTileLocalToMeters"/> for tile-local
        /// pixels where +Y is south.
        /// </summary>
        public Vector3 GeoToUnity(in GeoCoordinate geo)
        {
            double2 m = WebMercator.LatLngToMeters(geo.Latitude, geo.Longitude);
            double2 d = m - _originMeters;
            return new Vector3((float)d.x, geo.AltitudeMeters, (float)d.y);
        }

        public GeoCoordinate UnityToGeo(in Vector3 unity)
        {
            double mx = _originMeters.x + unity.x;
            double my = _originMeters.y + unity.z;
            var (lat, lng) = WebMercator.MetersToLatLng(mx, my);
            return new GeoCoordinate(lat, lng, unity.y);
        }

        public Vector3 MetersToUnity(double2 m)
        {
            double2 d = m - _originMeters;
            return new Vector3((float)d.x, 0f, (float)d.y);
        }

        public double2 UnityToMeters(in Vector3 unity)
            => _originMeters + new double2(unity.x, unity.z);

        public bool MaybeShiftOrigin(in Vector3 cameraPivot, out Vector3 deltaApplied)
        {
            float planar = math.length(new float2(cameraPivot.x, cameraPivot.z));
            if (planar < _settings.floatingOriginThresholdMeters)
            {
                deltaApplied = Vector3.zero;
                return false;
            }

            // Recenter the origin to the camera pivot's current geo location.
            var newOriginGeo = UnityToGeo(new Vector3(cameraPivot.x, 0f, cameraPivot.z));
            SetOrigin(newOriginGeo);
            deltaApplied = new Vector3(-cameraPivot.x, 0f, -cameraPivot.z);

            _bus?.Publish(new OriginShiftedEvent(deltaApplied));
            EngineLog.Info($"[CoordinateService] Origin shifted by {deltaApplied} → {newOriginGeo}");
            return true;
        }

        public void Dispose() { }
    }
}
