using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;
using UnityEngine;

namespace PokemonGo.GPS
{
    /// <summary>
    /// In-editor / mock GPS source. Walks the player towards a configurable
    /// target lat/lng at <see cref="EngineSettings.simulatedWalkSpeedMps"/>,
    /// or holds the current position if no target is set. Useful for
    /// repeatable testing and for desktop builds where there is no GPS.
    /// </summary>
    public sealed class SimulatedGpsService : IGpsService
    {
        public string ServiceName => "SimulatedGpsService";
        public int InitOrder => -130;

        private readonly EngineSettings _settings;
        private GeoCoordinate _current;
        private GeoCoordinate _target;
        private float _heading;
        private IEventBus _bus;

        public bool IsAvailable => true;
        public bool IsSimulated => true;
        public GeoCoordinate Current => _current;
        public float HeadingDegrees => _heading;
        public float AccuracyMeters => 5f;
        public float SpeedMps { get; private set; }

        public SimulatedGpsService(EngineSettings settings)
        {
            _settings = settings;
            _current = new GeoCoordinate(_settings.simulatedLatitude, _settings.simulatedLongitude);
            _target = _current;
        }

        public Task InitializeAsync(CancellationToken ct) => Task.CompletedTask;
        public void OnAllServicesReady()
        {
            _bus = ServiceLocator.Instance.Resolve<IEventBus>();
            _bus.Publish(new GpsLocationChangedEvent(
                _current.Latitude, _current.Longitude, AccuracyMeters, _heading, true));
        }
        public void Dispose() { }

        public void SetSimulatedTarget(in GeoCoordinate t) { _target = t; }

        public void Tick(float dt)
        {
            double distM = _current.DistanceMetersTo(_target);
            if (distM < 0.5) { SpeedMps = 0f; return; }

            double bearing = _current.BearingTo(_target);
            _heading = (float)bearing;
            double step = _settings.simulatedWalkSpeedMps * dt;
            if (step > distM) step = distM;
            var next = GeoMath.Offset(_current, bearing, step);
            SpeedMps = (float)(step / dt);
            _current = next;

            _bus?.Publish(new GpsLocationChangedEvent(
                _current.Latitude, _current.Longitude, AccuracyMeters, _heading, true));
        }
    }
}
