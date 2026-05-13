#if UNITY_EDITOR
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.Streaming;
using UnityEditor;
using UnityEngine;

namespace PokemonGo.Editor
{
    /// <summary>
    /// Editor window that visualises every active chunk, its tile id, mesh
    /// count, state and download progress. Open via
    /// <c>Window > PokemonGo > Tile Visualizer</c>.
    /// </summary>
    public sealed class TileVisualizerWindow : EditorWindow
    {
        private Vector2 _scroll;

        [MenuItem("Window/PokemonGo/Tile Visualizer")]
        public static void Open()
        {
            var w = GetWindow<TileVisualizerWindow>();
            w.titleContent = new GUIContent("PoGo Tile Visualizer");
            w.minSize = new Vector2(420, 300);
        }

        private void OnInspectorUpdate() => Repaint();

        private void OnGUI()
        {
            if (!Application.isPlaying)
            {
                EditorGUILayout.HelpBox("Enter play mode to see active chunks.", MessageType.Info);
                return;
            }

            var loc = ServiceLocator.Instance;
            if (!loc.TryResolve<ITileStreamer>(out var streamer) ||
                !loc.TryResolve<IChunkManager>(out var chunks))
            {
                EditorGUILayout.LabelField("Engine not booted yet.");
                return;
            }

            EditorGUILayout.LabelField("Anchor", $"{streamer.Anchor}");
            EditorGUILayout.LabelField("Zoom", streamer.Zoom.ToString());
            EditorGUILayout.LabelField("Active chunks", $"{streamer.TilesActive}");
            EditorGUILayout.LabelField("In flight",     $"{streamer.TilesInFlight}");

            EditorGUILayout.Space(6);
            _scroll = EditorGUILayout.BeginScrollView(_scroll);

            foreach (var c in chunks.ActiveChunks)
            {
                EditorGUILayout.BeginHorizontal("box");
                EditorGUILayout.LabelField($"{c.Id}", GUILayout.Width(110));
                EditorGUILayout.LabelField(c.State.ToString(), GUILayout.Width(90));
                int meshes = c.Root != null ? c.Root.GetComponentsInChildren<MeshFilter>().Length : 0;
                EditorGUILayout.LabelField($"meshes={meshes}", GUILayout.Width(80));
                EditorGUILayout.LabelField($"lod={c.LodLevel}", GUILayout.Width(60));
                if (GUILayout.Button("Select"))
                    Selection.activeGameObject = c.Root;
                EditorGUILayout.EndHorizontal();
            }
            EditorGUILayout.EndScrollView();
        }
    }
}
#endif
