using System.Collections.Generic;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.Rendering;
using PokemonGo.VectorTiles;
using Unity.Mathematics;
using UnityEngine;

namespace PokemonGo.Terrain
{
    /// <summary>
    /// Extrudes building polygons into prism meshes with separate vertex
    /// groups for sides (window-lit) and roofs (flat-shaded). Heights come
    /// from OSM <c>height</c> tags or are inferred from level count.
    /// </summary>
    public static class BuildingMeshGenerator
    {
        public static void Build(
            VectorLayer layer, MeshData mesh, ICoordinateService coords,
            EngineSettings settings, int z, int x, int y)
        {
            if (layer == null) return;
            int extent = layer.Extent;

            // Re-usable triangulation scratch buffers.
            var vertList = new List<float2>(64);
            var indList = new List<int>(192);
            var holes = new List<IReadOnlyList<float2>>(2);

            for (int i = 0; i < layer.Features.Count; i++)
            {
                var f = layer.Features[i];
                if (f.Geometry != GeomKind.Polygon) continue;
                if (f.Rings.Count == 0) continue;

                float h = f.HeightMeters;
                if (h <= 0f) h = settings.metersPerBuildingLevel * 2f;

                BuildOnePolygon(f, h, mesh, coords, z, x, y, extent,
                                vertList, indList, holes);
            }
        }

        private static void BuildOnePolygon(
            VectorFeature feature, float height, MeshData mesh,
            ICoordinateService coords, int z, int tileX, int tileY, int extent,
            List<float2> vertList, List<int> indList, List<IReadOnlyList<float2>> holes)
        {
            // Identify exteriors vs holes using ring winding (MVT 2.x convention).
            var exteriors = new List<float2[]>(2);
            var interiors = new List<float2[]>(2);
            for (int r = 0; r < feature.Rings.Count; r++)
            {
                var ring = ConvertRingToMeters(feature.Rings[r], coords, z, tileX, tileY, extent);
                if (ring.Length < 3) continue;
                float area = SignedArea(ring);
                if (area < 0f) exteriors.Add(ring);
                else           interiors.Add(ring);
            }

            for (int e = 0; e < exteriors.Count; e++)
            {
                var outer = new List<float2>(exteriors[e]);
                EarClippingTriangulator.EnsureCCW(outer);

                holes.Clear();
                for (int h = 0; h < interiors.Count; h++)
                {
                    if (PolygonContains(outer, interiors[h][0])) holes.Add(interiors[h]);
                }

                vertList.Clear();
                indList.Clear();
                if (!EarClippingTriangulator.Triangulate(outer, holes, vertList, indList)) continue;

                int baseRoof = mesh.Vertices.Count;
                Color32 roofCol = new Color32(220, 218, 230, 255);
                Color32 wallCol = new Color32(240, 235, 245, 255);

                // Roof (top) -------------------------------------------------
                for (int v = 0; v < vertList.Count; v++)
                {
                    mesh.Vertices.Add(new Vector3(vertList[v].x, height, vertList[v].y));
                    mesh.Normals.Add(Vector3.up);
                    mesh.Uvs.Add(new Vector2(vertList[v].x * 0.1f, vertList[v].y * 0.1f));
                    mesh.Colors.Add(roofCol);
                }
                for (int t = 0; t < indList.Count; t++) mesh.Indices.Add(baseRoof + indList[t]);

                // Walls ------------------------------------------------------
                EmitWalls(outer, height, mesh, wallCol);
                for (int h = 0; h < holes.Count; h++)
                {
                    var hole = new List<float2>(holes[h]);
                    EmitWalls(hole, height, mesh, wallCol);
                }
            }
        }

        private static void EmitWalls(
            List<float2> ring, float height, MeshData mesh, Color32 col)
        {
            int n = ring.Count;
            for (int i = 0; i < n; i++)
            {
                float2 a2 = ring[i];
                float2 b2 = ring[(i + 1) % n];
                Vector3 a = new Vector3(a2.x, 0, a2.y);
                Vector3 b = new Vector3(b2.x, 0, b2.y);
                Vector3 a1 = a; a1.y = height;
                Vector3 b1 = b; b1.y = height;
                Vector3 normal = Vector3.Cross(b - a, Vector3.up).normalized;
                float u = math.length(b - a);
                int baseV = mesh.Vertices.Count;
                mesh.Vertices.Add(a);  mesh.Normals.Add(normal); mesh.Uvs.Add(new Vector2(0, 0));      mesh.Colors.Add(col);
                mesh.Vertices.Add(b);  mesh.Normals.Add(normal); mesh.Uvs.Add(new Vector2(u, 0));      mesh.Colors.Add(col);
                mesh.Vertices.Add(a1); mesh.Normals.Add(normal); mesh.Uvs.Add(new Vector2(0, height)); mesh.Colors.Add(col);
                mesh.Vertices.Add(b1); mesh.Normals.Add(normal); mesh.Uvs.Add(new Vector2(u, height)); mesh.Colors.Add(col);
                mesh.Indices.Add(baseV); mesh.Indices.Add(baseV + 2); mesh.Indices.Add(baseV + 1);
                mesh.Indices.Add(baseV + 1); mesh.Indices.Add(baseV + 2); mesh.Indices.Add(baseV + 3);
            }
        }

        private static float2[] ConvertRingToMeters(
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
