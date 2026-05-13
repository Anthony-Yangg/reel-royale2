using System;
using PokemonGo.GIS;
using PokemonGo.Rendering;
using PokemonGo.Terrain;
using PokemonGo.VectorTiles;
using UnityEngine;

namespace PokemonGo.Streaming
{
    /// <summary>
    /// Lifecycle states for a streamed tile chunk. The Streamer state-machine
    /// drives each chunk through these transitions in order.
    /// </summary>
    public enum ChunkState : byte
    {
        Idle,
        Requested,
        Downloading,
        Downloaded,
        Decoding,
        Decoded,
        Building,
        Active,
        Unloading,
        Failed
    }

    /// <summary>
    /// One streamed map tile materialised as a Unity GameObject hierarchy.
    /// A Chunk owns its layer meshes, materials and pool tokens. The Chunk is
    /// the unit of streaming, culling, recycling and LOD switching.
    /// </summary>
    public sealed class Chunk : IDisposable, ITerrainBuildTarget
    {
        public TileId Id { get; set; }
        public readonly GameObject Root;
        public Transform Transform { get; }
        private readonly IMeshPool _meshPool;

        public ChunkState State;
        public VectorTile Tile { get; set; }
        public float LastTouchedSeconds;
        public float DistanceToCameraSqr;
        public Bounds WorldBounds { get; set; }
        public int LodLevel = 0;

        // Per-layer renderable holders, recycled into the pool on unload.
        public GameObject RoadsRoot     { get; set; }
        public GameObject BuildingsRoot { get; set; }
        public GameObject WaterRoot     { get; set; }
        public GameObject ParksRoot     { get; set; }
        public GameObject TerrainRoot   { get; set; }

        public Chunk(TileId id, Transform parent, IMeshPool meshPool)
        {
            Id = id;
            _meshPool = meshPool;
            Root = new GameObject($"Chunk_{id}");
            Root.transform.SetParent(parent, worldPositionStays: false);
            Transform = Root.transform;
            State = ChunkState.Idle;
        }

        public void EnsureLayerRoot(ref GameObject root, string name)
        {
            if (root == null)
            {
                root = new GameObject(name);
                root.transform.SetParent(Transform, false);
            }
            else if (!root.activeSelf)
            {
                root.SetActive(true);
            }
        }

        public void ClearLayers()
        {
            DestroyPooledChildren(RoadsRoot);
            DestroyPooledChildren(BuildingsRoot);
            DestroyPooledChildren(WaterRoot);
            DestroyPooledChildren(ParksRoot);
            DestroyPooledChildren(TerrainRoot);
        }

        private void DestroyPooledChildren(GameObject go)
        {
            DestroyChildren(go, _meshPool);
        }

        private static void DestroyChildren(GameObject go, IMeshPool meshPool)
        {
            if (go == null) return;
            for (int i = go.transform.childCount - 1; i >= 0; i--)
            {
                var c = go.transform.GetChild(i).gameObject;
                if (meshPool != null && c.TryGetComponent<MeshFilter>(out var mf) && mf.sharedMesh != null)
                {
                    var mesh = mf.sharedMesh;
                    mf.sharedMesh = null;
                    meshPool.ReturnMesh(mesh);
                }
                UnityEngine.Object.Destroy(c);
            }
        }

        public void Dispose()
        {
            DestroyPooledChildren(RoadsRoot);
            DestroyPooledChildren(BuildingsRoot);
            DestroyPooledChildren(WaterRoot);
            DestroyPooledChildren(ParksRoot);
            DestroyPooledChildren(TerrainRoot);
            if (Root != null) UnityEngine.Object.Destroy(Root);
        }
    }
}
