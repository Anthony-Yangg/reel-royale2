using System.Text;
using PokemonGo.Camera;
using PokemonGo.Core;
using PokemonGo.GPS;
using PokemonGo.Streaming;
using UnityEngine;

namespace PokemonGo.DebugTools
{
    /// <summary>
    /// In-game IMGUI overlay: FPS, GPS, streamer state, draw call hints.
    /// Toggle with the back-quote key (PC) or three-finger tap (mobile).
    /// Pure IMGUI to avoid pulling in UGUI/Canvas overhead for diagnostics.
    /// </summary>
    [DefaultExecutionOrder(10000)]
    public sealed class DebugHud : MonoBehaviour
    {
        [SerializeField] private bool _visible = true;
        [SerializeField] private int _fontSize = 14;
        [SerializeField] private Color _bg = new(0, 0, 0, 0.55f);
        [SerializeField] private Color _fg = new(0.95f, 0.97f, 1.0f, 1f);

        private float _fpsSmoothed = 60f;
        private readonly StringBuilder _sb = new(512);
        private GUIStyle _style;
        private GUIStyle _bgStyle;
        private Texture2D _bgTex;

        private ITileStreamer _streamer;
        private IGpsService _gps;
        private IMapCameraService _camera;
        private ITileCache _cache;
        private ITileDownloader _downloader;
        private IChunkManager _chunks;

        private void Start()
        {
            var rt = EngineRuntime.Active;
            if (rt == null) { enabled = false; return; }
            if (!rt.IsBooted) rt.BootCompleted += Bind;
            else Bind();
        }

        private void Bind()
        {
            var rt = EngineRuntime.Active;
            if (rt != null) rt.BootCompleted -= Bind;

            var loc = ServiceLocator.Instance;
            loc.TryResolve(out _streamer);
            loc.TryResolve(out _gps);
            loc.TryResolve(out _camera);
            loc.TryResolve(out _cache);
            loc.TryResolve(out _downloader);
            loc.TryResolve(out _chunks);
        }

        private void OnDestroy()
        {
            var rt = EngineRuntime.Active;
            if (rt != null) rt.BootCompleted -= Bind;
            if (_bgTex != null) Destroy(_bgTex);
        }

        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.BackQuote)) _visible = !_visible;
            float dt = Time.unscaledDeltaTime;
            float fps = 1f / Mathf.Max(dt, 1e-5f);
            _fpsSmoothed = Mathf.Lerp(_fpsSmoothed, fps, 0.05f);
        }

        private void OnGUI()
        {
            if (!_visible || _streamer == null) return;
            EnsureStyles();
            _sb.Clear();
            _sb.AppendLine("<b>PoGo Engine HUD</b> (press ` to toggle)");
            _sb.Append("FPS: ").AppendFormat("{0,4:0.0}", _fpsSmoothed).Append("   ");
            _sb.Append("dt: ").AppendFormat("{0:0.0}ms", Time.unscaledDeltaTime * 1000f).AppendLine();

            if (_gps != null)
            {
                _sb.AppendLine($"GPS: {_gps.Current.Latitude:F5}, {_gps.Current.Longitude:F5}");
                _sb.Append("Acc: ").AppendFormat("{0:0.0}m", _gps.AccuracyMeters);
                _sb.Append("  Hdg: ").AppendFormat("{0:0}°", _gps.HeadingDegrees);
                _sb.Append("  Speed: ").AppendFormat("{0:0.0}m/s", _gps.SpeedMps);
                _sb.Append(_gps.IsSimulated ? "  [SIM]" : "  [DEVICE]");
                _sb.AppendLine();
            }
            if (_camera != null)
            {
                _sb.AppendLine($"Cam tilt={_camera.TiltDegrees:0}° yaw={_camera.YawDegrees:0}° d={_camera.Distance:0}m");
            }
            _sb.Append("Tiles active: ").Append(_streamer.TilesActive);
            _sb.Append("  inflight: ").Append(_streamer.TilesInFlight);
            _sb.Append("  mem-cache: ").Append(_streamer.TilesCached).AppendLine();

            if (_cache != null)
            {
                _sb.AppendFormat("Cache mem={0:0.0}MB disk={1:0.0}MB",
                    _cache.MemBytes / 1024f / 1024f,
                    _cache.DiskBytes / 1024f / 1024f).AppendLine();
            }
            if (_downloader != null)
            {
                _sb.AppendFormat("Net {0:0.0}MB total, {1} in-flight",
                    _downloader.BytesDownloaded / 1024f / 1024f, _downloader.InFlight).AppendLine();
            }
            if (_chunks != null)
            {
                _sb.AppendFormat("ChunkPool size={0}", _chunks.PoolSize).AppendLine();
            }

            var rect = new Rect(8, 8, 410, 220);
            GUI.Box(rect, GUIContent.none, _bgStyle);
            GUI.Label(new Rect(rect.x + 8, rect.y + 6, rect.width - 16, rect.height - 12),
                      _sb.ToString(), _style);
        }

        private void EnsureStyles()
        {
            if (_style != null) return;
            _style = new GUIStyle(GUI.skin.label) { fontSize = _fontSize, richText = true };
            _style.normal.textColor = _fg;
            _bgTex = new Texture2D(1, 1);
            _bgTex.SetPixel(0, 0, _bg);
            _bgTex.Apply();
            _bgStyle = new GUIStyle(GUI.skin.box);
            _bgStyle.normal.background = _bgTex;
        }
    }
}
