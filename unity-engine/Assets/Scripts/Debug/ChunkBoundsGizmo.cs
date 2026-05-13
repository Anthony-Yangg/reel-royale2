using PokemonGo.Core;
using PokemonGo.Streaming;
using UnityEngine;

namespace PokemonGo.DebugTools
{
    /// <summary>
    /// Draws chunk AABBs and tile boundaries in the scene view when
    /// <c>EngineSettings.drawChunkBounds</c> is true. Adds nothing to
    /// rendering cost in builds when stripped.
    /// </summary>
    [ExecuteAlways]
    public sealed class ChunkBoundsGizmo : MonoBehaviour
    {
        private IChunkManager _chunks;

        private void OnDrawGizmos()
        {
            if (EngineRuntime.Settings == null) return;
            if (!EngineRuntime.Settings.drawChunkBounds) return;
            if (_chunks == null && !ServiceLocator.Instance.TryResolve(out _chunks)) return;

            Gizmos.color = new Color(1f, 0.6f, 0.2f, 0.8f);
            foreach (var c in _chunks.ActiveChunks)
            {
                Gizmos.DrawWireCube(c.WorldBounds.center, c.WorldBounds.size);
            }
        }
    }
}
