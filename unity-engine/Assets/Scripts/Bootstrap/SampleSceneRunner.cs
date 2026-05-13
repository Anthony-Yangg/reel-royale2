using PokemonGo.Camera;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.GPS;
using PokemonGo.Streaming;
using UnityEngine;

namespace PokemonGo.Bootstrap
{
    /// <summary>
    /// Optional helper that seeds the simulated GPS with a few interesting
    /// waypoints (San Francisco Embarcadero, Boston Common, Tokyo Shibuya)
    /// and rotates between them so a developer can immediately see streaming
    /// behaviour without authoring an input scenario. Disable in production.
    /// </summary>
    [DefaultExecutionOrder(-10999)]
    public sealed class SampleSceneRunner : MonoBehaviour
    {
        [SerializeField] private bool _enableTour = false;
        [SerializeField] private float _waypointHoldSeconds = 12f;

        private static readonly GeoCoordinate[] kTour =
        {
            new(37.795160, -122.393562), // SF Embarcadero
            new(40.758896, -73.985130),  // NYC Times Square
            new(51.503399, -0.119519),   // London Westminster
            new(35.659483, 139.700456),  // Tokyo Shibuya
            new(48.858844,  2.294351),   // Paris Eiffel
            new(-22.951916, -43.210487), // Rio Copacabana
        };

        private int _idx;
        private float _holdTimer;
        private IGpsService _gps;
        private IMapCameraService _camera;
        private ITileStreamer _streamer;
        private ICoordinateService _coords;

        private void Start()
        {
            var rt = EngineRuntime.Active;
            if (rt == null) { enabled = false; return; }
            if (!rt.IsBooted) rt.BootCompleted += Bind;
            else Bind();
        }

        private void Bind()
        {
            var loc = ServiceLocator.Instance;
            loc.TryResolve(out _gps);
            loc.TryResolve(out _camera);
            loc.TryResolve(out _streamer);
            loc.TryResolve(out _coords);

            // Snap camera/origin to first waypoint for a clean cold start.
            if (_coords != null)
            {
                _coords.SetOrigin(kTour[0]);
                _streamer?.SetAnchor(kTour[0]);
                _streamer?.ForceRefresh();
                _camera?.SetTarget(kTour[0], snap: true);
            }
        }

        private void Update()
        {
            if (!_enableTour || _gps == null) return;
            _holdTimer += Time.deltaTime;
            if (_holdTimer < _waypointHoldSeconds) return;
            _holdTimer = 0f;
            _idx = (_idx + 1) % kTour.Length;
            _gps.SetSimulatedTarget(kTour[_idx]);
            if (_coords != null)
            {
                _coords.SetOrigin(kTour[_idx]);
                _streamer?.ForceRefresh();
                _camera?.SetTarget(kTour[_idx], snap: true);
            }
        }
    }
}
