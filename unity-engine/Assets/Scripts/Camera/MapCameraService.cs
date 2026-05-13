using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.Streaming;
using UnityEngine;

namespace PokemonGo.Camera
{
    /// <summary>
    /// Pokémon-GO-style orbit camera. A pivot transform sits on the ground,
    /// the rig orbits it at <see cref="TiltDegrees"/> tilt and
    /// <see cref="YawDegrees"/> azimuth, the camera sits at
    /// <see cref="Distance"/> on the rig's local +Z. Smoothing is critically
    /// damped (SmoothDamp) so input feels weighted but never overshoots.
    /// </summary>
    public sealed class MapCameraService : IMapCameraService
    {
        public string ServiceName => "MapCameraService";
        public int InitOrder => -110;

        private readonly EngineSettings _settings;

        private UnityEngine.Camera _camera;
        private Transform _pivot;
        private Transform _rig;
        private Transform _follow;

        private ICoordinateService _coords;
        private ITileStreamer _streamer;

        // Target state (where the camera *wants* to be).
        private float _targetTilt;
        private float _targetYaw;
        private float _targetDistance;
        private Vector3 _targetPivot;

        // Current smoothed state.
        private float _curTilt, _velTilt;
        private float _curYaw, _velYaw;
        private float _curDistance, _velDistance;
        private Vector3 _curPivot, _velPivot;

        // Pan inertia.
        private Vector2 _panVelocity;

        public UnityEngine.Camera Camera => _camera;
        public Transform Pivot => _pivot;
        public Transform Rig => _rig;

        public float TiltDegrees { get => _targetTilt; set => _targetTilt = Mathf.Clamp(value, 25f, 80f); }
        public float YawDegrees  { get => _targetYaw;  set => _targetYaw = Mathf.Repeat(value, 360f); }
        public float Distance    { get => _targetDistance;
            set => _targetDistance = Mathf.Clamp(value, _settings.minCameraDistance, _settings.maxCameraDistance); }

        public GeoCoordinate TargetCoord =>
            _coords != null ? _coords.UnityToGeo(_targetPivot)
                            : new GeoCoordinate(_settings.simulatedLatitude, _settings.simulatedLongitude);

        public MapCameraService(EngineSettings settings) { _settings = settings; }

        public Task InitializeAsync(CancellationToken ct)
        {
            // Construct rig: Pivot (world ground anchor) → Rig (yaw) → CamPivot (tilt) → Camera.
            var pivotGo = new GameObject("MapCameraPivot");
            _pivot = pivotGo.transform;

            var rigGo = new GameObject("MapCameraRig");
            _rig = rigGo.transform;
            _rig.SetParent(_pivot, false);

            var tiltGo = new GameObject("MapCameraTilt");
            tiltGo.transform.SetParent(_rig, false);

            var camGo = new GameObject("MapCamera", typeof(UnityEngine.Camera));
            camGo.tag = "MainCamera";
            _camera = camGo.GetComponent<UnityEngine.Camera>();
            _camera.fieldOfView = 35f;
            _camera.nearClipPlane = 0.5f;
            _camera.farClipPlane = _settings.maxRenderDistance * 1.3f;
            _camera.clearFlags = CameraClearFlags.SolidColor;
            _camera.backgroundColor = new Color(0.84f, 0.92f, 0.98f);
            camGo.transform.SetParent(tiltGo.transform, false);

            _targetTilt = _curTilt = _settings.defaultCameraTiltDegrees;
            _targetYaw  = _curYaw  = 0f;
            _targetDistance = _curDistance = _settings.defaultCameraDistance;
            return Task.CompletedTask;
        }

        public void OnAllServicesReady()
        {
            var loc = ServiceLocator.Instance;
            _coords = loc.Resolve<ICoordinateService>();
            _streamer = loc.Resolve<ITileStreamer>();
        }

        public void Dispose()
        {
            if (_pivot != null) UnityEngine.Object.Destroy(_pivot.gameObject);
            _camera = null;
            _pivot = null;
            _rig = null;
            _follow = null;
        }

        public void SetTarget(in GeoCoordinate coord, bool snap)
        {
            Vector3 p = _coords.GeoToUnity(coord);
            _targetPivot = new Vector3(p.x, 0f, p.z);
            if (snap) _curPivot = _targetPivot;
        }

        public void SetFollowTarget(Transform t) => _follow = t;

        public void NudgePan(Vector2 worldDelta)
        {
            // Convert screen-aligned pan into world-aligned pan (account for yaw).
            float rad = _curYaw * Mathf.Deg2Rad;
            float sin = Mathf.Sin(rad), cos = Mathf.Cos(rad);
            Vector2 r = new(cos * worldDelta.x - sin * worldDelta.y,
                            sin * worldDelta.x + cos * worldDelta.y);
            _targetPivot += new Vector3(r.x, 0, r.y);
            _panVelocity = r / Mathf.Max(Time.deltaTime, 0.0001f);
        }

        public void NudgeZoom(float multiplier)
        {
            _targetDistance = Mathf.Clamp(_targetDistance * multiplier,
                _settings.minCameraDistance, _settings.maxCameraDistance);
        }

        public void NudgeRotate(float yawDelta)
        {
            _targetYaw = Mathf.Repeat(_targetYaw + yawDelta, 360f);
        }

        public void Tick(float dt)
        {
            // Inertia: decay pan velocity each frame.
            if (_panVelocity.sqrMagnitude > 0.001f)
            {
                _targetPivot += new Vector3(_panVelocity.x, 0, _panVelocity.y) * dt;
                _panVelocity *= Mathf.Exp(-dt / _settings.cameraInertiaSeconds);
            }

            // Follow GPS-driven transform.
            if (_follow != null)
            {
                Vector3 lookAt = _follow.position;
                lookAt.y = 0f;
                _targetPivot = Vector3.Lerp(_targetPivot, lookAt, 1f - Mathf.Exp(-dt * 4f));
            }

            // Smoothed camera state.
            _curTilt    = Mathf.SmoothDamp(_curTilt,    _targetTilt,    ref _velTilt,    0.10f);
            _curYaw     = Mathf.SmoothDampAngle(_curYaw, _targetYaw,    ref _velYaw,     0.18f);
            _curDistance= Mathf.SmoothDamp(_curDistance,_targetDistance,ref _velDistance,0.18f);
            _curPivot   = Vector3.SmoothDamp(_curPivot, _targetPivot,   ref _velPivot,   0.12f);
        }

        public void LateTick(float dt)
        {
            if (_pivot == null) return;

            _pivot.position = _curPivot;
            _rig.localRotation = Quaternion.Euler(0f, _curYaw, 0f);
            var tilt = _rig.GetChild(0);
            tilt.localRotation = Quaternion.Euler(_curTilt, 0f, 0f);

            // Camera sits behind pivot at distance, looking towards pivot.
            _camera.transform.localPosition = new Vector3(0, 0, -_curDistance);
            _camera.transform.localRotation = Quaternion.identity;

            // Push tile streamer anchor.
            if (_streamer != null && _coords != null)
            {
                var geo = _coords.UnityToGeo(new Vector3(_curPivot.x, 0f, _curPivot.z));
                _streamer.SetAnchor(geo);
            }

            // Maybe shift floating origin.
            if (_coords != null && _coords.MaybeShiftOrigin(_curPivot, out var delta))
            {
                _curPivot += delta;
                _targetPivot += delta;
                _pivot.position = _curPivot;
            }
        }
    }
}
