using System.Collections.Generic;
using UnityEngine;

namespace PokemonGo.Rendering
{
    /// <summary>
    /// Mutable mesh accumulator. Mesh generators push vertices/indices into
    /// one of these and the terrain builder converts it to a Unity Mesh in
    /// one allocation. Indices are 32-bit so we can stitch larger chunks
    /// without splitting (Unity Mesh supports >65k indices when
    /// <see cref="UnityEngine.Rendering.IndexFormat.UInt32"/> is set).
    ///
    /// Lives in <see cref="PokemonGo.Rendering"/> so it can be referenced
    /// by both the Terrain generators (which produce it) and the Rendering
    /// MeshPool (which pools it).
    /// </summary>
    public sealed class MeshData
    {
        public readonly List<Vector3> Vertices = new(512);
        public readonly List<Vector3> Normals  = new(512);
        public readonly List<Vector2> Uvs      = new(512);
        public readonly List<Color32> Colors   = new(512);
        public readonly List<int>     Indices  = new(1024);

        public bool HasUvs => Uvs.Count > 0;
        public bool HasColors => Colors.Count > 0;

        public void Clear()
        {
            Vertices.Clear();
            Normals.Clear();
            Uvs.Clear();
            Colors.Clear();
            Indices.Clear();
        }

        public void Reserve(int verts, int tris)
        {
            if (Vertices.Capacity < verts) Vertices.Capacity = verts;
            if (Normals.Capacity < verts)  Normals.Capacity = verts;
            if (Uvs.Capacity < verts)      Uvs.Capacity = verts;
            if (Colors.Capacity < verts)   Colors.Capacity = verts;
            if (Indices.Capacity < tris * 3) Indices.Capacity = tris * 3;
        }

        public void ApplyTo(Mesh mesh)
        {
            mesh.Clear();
            mesh.indexFormat = Vertices.Count >= 60000
                ? UnityEngine.Rendering.IndexFormat.UInt32
                : UnityEngine.Rendering.IndexFormat.UInt16;

            mesh.SetVertices(Vertices);
            if (Normals.Count == Vertices.Count) mesh.SetNormals(Normals);
            if (HasUvs)    mesh.SetUVs(0, Uvs);
            if (HasColors) mesh.SetColors(Colors);
            mesh.SetTriangles(Indices, 0, calculateBounds: true);
            if (Normals.Count != Vertices.Count) mesh.RecalculateNormals();
            // The custom shader suite does not sample normal maps, so tangents
            // would be pure CPU cost on the streaming path.
            mesh.UploadMeshData(markNoLongerReadable: false);
        }
    }
}
