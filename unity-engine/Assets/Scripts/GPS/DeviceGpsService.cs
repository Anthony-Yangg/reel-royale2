using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;
using Unity.Mathematics;
using UnityEngine;

namespace PokemonGo.GPS
{
    /// <summary>
    /// Real-device GPS source using <see cref="UnityEngine.LocationService"/>
    /// and <see cref="UnityEngine.Compass"/>. Smoothed with a per-axis
    /// Kalman filter and an accuracy gate to drop wildly inaccurate fixes.
    /// </summary>
    public sealed class DeviceGpsService : IGpsService
    {
        public string ServiceName => "DeviceGpsService";
        public int InitOrder => -130;

        private readonly EngineSettings _settings;
        private readonly LocationKalmanFilter _latFilter = new();
        private readonly LocationKalmanFilter _lngFilter = new();

        private GeoCoordinate _current;
        private float _heading;
        private float _accuracy;
        private float _speed;
        private double _lastSample;
        private bool _hasFix;
        private bool _serviceStarted;
        private IEventBus _bus;

        public bool IsAvailable => Input.location.status == LocationServiceStatus.Running && _hasFix;
        public bool IsSimulated => false;
        public GeoCoordinate Current => _current;
        public float HeadingDegrees => _heading;
        public float AccuracyMeters => _accuracy;
        public float SpeedMps => _speed;

        public DeviceGpsService(EngineSettings settings)
        {
            _settings = settings;
            _current = new GeoCoordinate(_settings.simulatedLatitude, _settings.simulatedLongitude);
        }

        public async Task InitializeAsync(CancellationToken ct)
        {
            if (!Input.location.isEnabledByUser)
            {
                EngineLog.Warn("Location services disabled by user; GPS will fail open.");
                return;
            }

            Input.location.Start(desiredAccuracyInMeters: 5f, updateDistanceInMeters: 1f);
            Input.compass.enabled = true;
            _serviceStarted = true;

            // Poll-with-timeout for first fix to keep boot deterministic.
            int waited = 0;
            while (Input.location.status == LocationServiceStatus.Initializing && waited < 100)
            {
                await Task.Delay(100, ct).ConfigureAwait(false);
                waited++;
            }
            if (Input.location.status != LocationServiceStatus.Running)
                EngineLog.Warn("GPS did not reach Running state within 10s; will keep retrying in Tick.");
        }

        public void OnAllServicesReady()
        {
            _bus = ServiceLocator.Instance.Resolve<IEventBus>();
        }

        public void Dispose()
        {
            if (_serviceStarted) Input.location.Stop();
        }

        public void SetSimulatedTarget(in GeoCoordinate t)
        {
            // No-op on device; remains for interface symmetry.
        }

        public void Tick(float dt)
        {
            if (Input.location.status != LocationServiceStatus.Running) return;
            var data = Input.location.lastData;
            if (data.timestamp <= _lastSample) return;
            _lastSample = data.timestamp;
            _accuracy = data.horizontalAccuracy;

            if (_accuracy > _settings.gpsRejectAccuracyThresholdMeters)
            {
                // Reject low-confidence fix.
                return;
            }

            double now = Time.realtimeSinceStartupAsDouble;
            double measurementVariance = math.max(_accuracy * _accuracy, 4.0);
            double filteredLat = _latFilter.Filter(data.latitude, measurementVariance, now);
            double filteredLng = _lngFilter.Filter(data.longitude, measurementVariance, now);
            var nextCoord = new GeoCoordinate(filteredLat, filteredLng, data.altitude);
            if (_hasFix)
            {
                double moved = _current.DistanceMetersTo(nextCoord);
                _speed = (float)(moved / math.max(dt, 0.001f));
            }
            _current = nextCoord;
            _heading = Input.compass.enabled ? Input.compass.trueHeading : _heading;
            _hasFix = true;

            _bus?.Publish(new GpsLocationChangedEvent(
                _current.Latitude, _current.Longitude, _accuracy, _heading, false));
        }
    }
}
