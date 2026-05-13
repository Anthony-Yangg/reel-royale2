using System.Collections.Generic;
using PokemonGo.GIS;
using PokemonGo.Rendering;
using PokemonGo.VectorTiles;
using Unity.Mathematics;
using UnityEngine;

namespace PokemonGo.Terrain
{
    /// <summary>
    /// Flat-polygon generator used for water, parks, landuse, and terrain base.
    /// All faces are emitted on a horizontal plane at <c>yOffset</c>.
    /// </summary>
    public static class PolygonMeshGenerator
    {
        public static void BuildFlat(
            VectorLayer layer, MeshData mesh, ICoordinateService coords,
            int z, int tileX, int tileY,
            Color32 fillColor, float yOffset)
        {
            if (layer == null) return;
            int extent = layer.Extent;
            var verts = new List<float2>(64);
            var inds = new List<int>(192);

            for (int i = 0; i < layer.Features.Count; i++)
            {
                var f = layer.Features[i];
                if (f.Geometry != GeomKind.Polygon) continue;
                if (f.Rings.Count == 0) continue;

                var rings = new List<float2[]>(f.Rings.Count);
                for (int r = 0; r < f.Rings.Count; r++)
                {
                    rings.Add(ConvertRing(f.Rings[r], coords, z, tileX, tileY, extent));
                }

                var exteriors = new List<float2[]>(2);
                var holes = new List<float2[]>(2);
                for (int r = 0; r < rings.Count; r++)
                {
                    float area = SignedArea(rings[r]);
                    if (area < 0f) exteriors.Add(rings[r]);
                    else           holes.Add(rings[r]);
                }

                for (int e = 0; e < exteriors.Count; e++)
                {
                    var outer = new List<float2>(exteriors[e]);
                    var relevantHoles = new List<IReadOnlyList<float2>>(holes.Count);
                    for (int h = 0; h < holes.Count; h++)
                    {
                        if (PolygonContains(outer, holes[h][0])) relevantHoles.Add(holes[h]);
                    }

                    verts.Clear();
                    inds.Clear();
                    if (!EarClippingTriangulator.Triangulate(outer, relevantHoles, verts, inds))
                        continue;

                    int baseV = mesh.Vertices.Count;
                    for (int v = 0; v < verts.Count; v++)
                    {
                        mesh.Vertices.Add(new Vector3(verts[v].x, yOffset, verts[v].y));
                        mesh.Normals.Add(Vector3.up);
                        mesh.Uvs.Add(new Vector2(verts[v].x * 0.05f, verts[v].y * 0.05f));
                        mesh.Colors.Add(fillColor);
                    }
                    for (int t = 0; t < inds.Count; t++) mesh.Indices.Add(baseV + inds[t]);
                }
            }
        }

        private static float2[] ConvertRing(
            int2[] ring, ICoordinateService coords,
            int z, int tileX, int tileY, int extent)
        {
            int n = ring.Length;
            var outRing = new float2[n];
            for (int i = 0; i < n; i++)
            {
                double2 mm = WebMercator.VectorTileLocalToMeters(
                    ring[i].x, ring[i].y, extent, tileX, tileY, z);
                Vector3 u = coords.MetersToUnity(mm);
                outRing[i] = new float2(u.x, u.z);
            }
            return outRing;
        }

        private static float SignedArea(float2[] poly)
        {
            float a = 0f;
            for (int i = 0, j = poly.Length - 1; i < poly.Length; j = i++)
                a += (poly[j].x - poly[i].x) * (poly[j].y + poly[i].y);
            return a * 0.5f;
        }

        private static bool PolygonContains(List<float2> poly, float2 p)
        {
            bool inside = false;
            for (int i = 0, j = poly.Count - 1; i < poly.Count; j = i++)
            {
                if (((poly[i].y > p.y) != (poly[j].y > p.y)) &&
                    (p.x < (poly[j].x - poly[i].x) * (p.y - poly[i].y) /
                     (poly[j].y - poly[i].y + 1e-7f) + poly[i].x))
                {
                    inside = !inside;
                }
            }
            return inside;
        }
    }
}
