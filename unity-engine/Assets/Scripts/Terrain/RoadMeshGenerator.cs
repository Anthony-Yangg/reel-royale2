using System.Collections.Generic;
using PokemonGo.GIS;
using PokemonGo.Rendering;
using PokemonGo.VectorTiles;
using Unity.Mathematics;
using UnityEngine;

namespace PokemonGo.Terrain
{
    /// <summary>
    /// Extrudes vector-tile road polylines into ribbon meshes with mitred
    /// joins. Each road class gets a fixed width and a vertex-color channel
    /// the shader uses for tinting / emissive lookup.
    /// </summary>
    public static class RoadMeshGenerator
    {
        // Road widths in meters per class. Tuned to Pokémon-GO-style chunky look.
        private static readonly Dictionary<RoadClass, float> Width = new()
        {
            [RoadClass.Motorway]  = 18f,
            [RoadClass.Trunk]     = 16f,
            [RoadClass.Primary]   = 14f,
            [RoadClass.Secondary] = 11f,
            [RoadClass.Tertiary]  = 9f,
            [RoadClass.Street]    = 8f,
            [RoadClass.Service]   = 6f,
            [RoadClass.Path]      = 4.2f,
            [RoadClass.Pedestrian]= 5f,
            [RoadClass.Unknown]   = 8f
        };

        // Warm, high-value ribbon tints. The shader supplies teal edging, so
        // the roads read as chunky game paths instead of technical linework.
        private static readonly Dictionary<RoadClass, Color32> Tint = new()
        {
            [RoadClass.Motorway]  = new Color32(255, 235, 166, 255),
            [RoadClass.Trunk]     = new Color32(255, 230, 158, 255),
            [RoadClass.Primary]   = new Color32(250, 224, 148, 255),
            [RoadClass.Secondary] = new Color32(242, 218, 146, 255),
            [RoadClass.Tertiary]  = new Color32(236, 212, 148, 255),
            [RoadClass.Street]    = new Color32(230, 208, 150, 255),
            [RoadClass.Service]   = new Color32(222, 204, 154, 255),
            [RoadClass.Path]      = new Color32(214, 204, 164, 255),
            [RoadClass.Pedestrian]= new Color32(220, 208, 164, 255),
            [RoadClass.Unknown]   = new Color32(234, 212, 150, 255),
        };

        public static void Build(
            VectorLayer layer, MeshData mesh, ICoordinateService coords,
            int z, int x, int y, float yOffset = 0.05f)
        {
            if (layer == null) return;
            int extent = layer.Extent;
            for (int i = 0; i < layer.Features.Count; i++)
            {
                var f = layer.Features[i];
                if (f.Geometry != GeomKind.Line) continue;

                float width = Width.TryGetValue(f.Road, out var w) ? w : Width[RoadClass.Unknown];
                Color32 tint = Tint.TryGetValue(f.Road, out var c) ? c : Tint[RoadClass.Unknown];

                for (int li = 0; li < f.Lines.Count; li++)
                {
                    AppendRibbon(f.Lines[li], width, tint, mesh, coords,
                                 z, x, y, extent, yOffset);
                }
            }
        }

        private static void AppendRibbon(
            int2[] line, float width, Color32 tint, MeshData mesh,
            ICoordinateService coords, int z, int tileX, int tileY,
            int extent, float yOffset)
        {
            if (line == null || line.Length < 2) return;
            int n = line.Length;

            // Convert tile-local pixels → meters → unity worldspace.
            var pts = new Vector3[n];
            for (int i = 0; i < n; i++)
            {
                double2 m = WebMercator.VectorTileLocalToMeters(
                    line[i].x, line[i].y, extent, tileX, tileY, z);
                Vector3 w = coords.MetersToUnity(m);
                w.y = yOffset;
                pts[i] = w;
            }

            float halfW = width * 0.5f;
            int baseV = mesh.Vertices.Count;

            // Precompute per-vertex extruded points using mitered joins.
            var left = new Vector3[n];
            var right = new Vector3[n];
            for (int i = 0; i < n; i++)
            {
                Vector3 prev = i == 0 ? pts[i] : pts[i - 1];
                Vector3 next = i == n - 1 ? pts[i] : pts[i + 1];
                Vector3 dirIn  = (pts[i] - prev);
                Vector3 dirOut = (next - pts[i]);
                if (dirIn.sqrMagnitude < 1e-6f) dirIn = dirOut;
                if (dirOut.sqrMagnitude < 1e-6f) dirOut = dirIn;
                dirIn.Normalize(); dirOut.Normalize();
                Vector3 normalIn  = new Vector3(-dirIn.z, 0, dirIn.x);
                Vector3 normalOut = new Vector3(-dirOut.z, 0, dirOut.x);
                Vector3 miter = (normalIn + normalOut).normalized;
                float dot = Mathf.Max(Vector3.Dot(miter, normalIn), 0.1f);
                Vector3 offset = miter * (halfW / dot);
                left[i]  = pts[i] - offset;
                right[i] = pts[i] + offset;
            }

            // Emit quads.
            for (int i = 0; i < n; i++)
            {
                mesh.Vertices.Add(left[i]);
                mesh.Vertices.Add(right[i]);
                mesh.Normals.Add(Vector3.up);
                mesh.Normals.Add(Vector3.up);
                float t = i / (float)(n - 1);
                mesh.Uvs.Add(new Vector2(0, t * 12f));
                mesh.Uvs.Add(new Vector2(1, t * 12f));
                mesh.Colors.Add(tint);
                mesh.Colors.Add(tint);
            }
            for (int i = 0; i < n - 1; i++)
            {
                int a = baseV + i * 2;
                int b = a + 1;
                int c = a + 2;
                int d = a + 3;
                mesh.Indices.Add(a); mesh.Indices.Add(c); mesh.Indices.Add(b);
                mesh.Indices.Add(b); mesh.Indices.Add(c); mesh.Indices.Add(d);
            }
        }
    }
}
