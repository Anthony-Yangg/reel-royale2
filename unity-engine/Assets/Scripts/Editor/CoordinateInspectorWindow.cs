#if UNITY_EDITOR
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.Streaming;
using PokemonGo.GPS;
using UnityEditor;
using UnityEngine;

namespace PokemonGo.Editor
{
    /// <summary>
    /// Inspect / jump-to lat-lng. Useful for previewing locations without
    /// physically moving (or simulating) the GPS.
    /// </summary>
    public sealed class CoordinateInspectorWindow : EditorWindow
    {
        private string _latStr = "37.81";
        private string _lngStr = "-122.41";

        [MenuItem("Window/PokemonGo/Coordinate Inspector")]
        public static void Open()
        {
            var w = GetWindow<CoordinateInspectorWindow>();
            w.titleContent = new GUIContent("PoGo Coords");
        }

        private void OnGUI()
        {
            EditorGUILayout.LabelField("Coordinate Inspector", EditorStyles.boldLabel);
            _latStr = EditorGUILayout.TextField("Latitude",  _latStr);
            _lngStr = EditorGUILayout.TextField("Longitude", _lngStr);

            if (!Application.isPlaying)
            {
                EditorGUILayout.HelpBox("Enter play mode to jump.", MessageType.Info);
                return;
            }

            if (GUILayout.Button("Jump GPS to here"))
            {
                if (double.TryParse(_latStr, out var lat) &&
                    double.TryParse(_lngStr, out var lng))
                {
                    var coord = new GeoCoordinate(lat, lng);
                    var loc = ServiceLocator.Instance;
                    if (loc.TryResolve<IGpsService>(out var gps)) gps.SetSimulatedTarget(coord);
                    if (loc.TryResolve<ICoordinateService>(out var c)) c.SetOrigin(coord);
                    if (loc.TryResolve<ITileStreamer>(out var s)) { s.SetAnchor(coord); s.ForceRefresh(); }
                }
            }
        }
    }
}
#endif
