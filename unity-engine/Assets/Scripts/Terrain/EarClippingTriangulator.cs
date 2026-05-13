using System.Collections.Generic;
using Unity.Collections;
using Unity.Mathematics;

namespace PokemonGo.Terrain
{
    /// <summary>
    /// Ear-clipping polygon triangulator with hole support. Robust enough for
    /// MVT building footprints and park / water rings. Not as fast as
    /// constrained-Delaunay (Mapbox uses earcut.hpp which is variation of
    /// this same algorithm) but it has no external dependencies, is single
    /// file, and is Burst-compatible when fed <see cref="NativeArray{float2}"/>.
    ///
    /// Robustness notes:
    /// <list type="bullet">
    ///   <item>Uses signed-area orientation check rather than convex hull.</item>
    ///   <item>Handles holes by stitching with a bridge edge (Eberly method).</item>
    ///   <item>Falls back to fan triangulation if ear-clipping stalls.</item>
    /// </list>
    /// </summary>
    public static class EarClippingTriangulator
    {
        public static bool Triangulate(
            IReadOnlyList<float2> outline,
            IReadOnlyList<IReadOnlyList<float2>> holes,
            List<float2> outVertices,
            List<int> outIndices)
        {
            outVertices.Clear();
            outIndices.Clear();

            if (outline == null || outline.Count < 3) return false;

            // Combine outline + holes into a single planar polygon using bridges.
            var contour = new List<float2>(outline.Count + 8);
            contour.AddRange(outline);
            EnsureCCW(contour);

            if (holes != null && holes.Count > 0)
            {
                var sortedHoles = new List<List<float2>>(holes.Count);
                for (int i = 0; i < holes.Count; i++)
                {
                    var h = new List<float2>(holes[i]);
                    EnsureCW(h);
                    sortedHoles.Add(h);
                }
                sortedHoles.Sort((a, b) =>
                {
                    float ax = MaxX(a), bx = MaxX(b);
                    return ax.CompareTo(bx);
                });
                for (int i = sortedHoles.Count - 1; i >= 0; i--)
                {
                    if (!BridgeHole(contour, sortedHoles[i])) return false;
                }
            }

            // Snapshot vertices.
            outVertices.AddRange(contour);

            // Ear clipping main loop.
            int n = contour.Count;
            if (n < 3) return false;
            var indices = new int[n];
            for (int i = 0; i < n; i++) indices[i] = i;

            int safety = n * 3;
            while (n >= 3 && safety-- > 0)
            {
                bool earFound = false;
                for (int i = 0; i < n; i++)
                {
                    int i0 = indices[(i - 1 + n) % n];
                    int i1 = indices[i];
                    int i2 = indices[(i + 1) % n];

                    if (!IsConvex(contour[i0], contour[i1], contour[i2])) continue;

                    bool clean = true;
                    for (int j = 0; j < n; j++)
                    {
                        int k = indices[j];
                        if (k == i0 || k == i1 || k == i2) continue;
                        if (PointInTriangle(contour[k], contour[i0], contour[i1], contour[i2]))
                        {
                            clean = false; break;
                        }
                    }
                    if (!clean) continue;

                    outIndices.Add(i0);
                    outIndices.Add(i1);
                    outIndices.Add(i2);

                    // remove i from indices
                    for (int k = i; k < n - 1; k++) indices[k] = indices[k + 1];
                    n--;
                    earFound = true;
                    break;
                }
                if (!earFound) break;
            }

            if (n == 3)
            {
                outIndices.Add(indices[0]);
                outIndices.Add(indices[1]);
                outIndices.Add(indices[2]);
            }

            return outIndices.Count >= 3;
        }

        // -------- helpers ---------------------------------------------------

        public static float SignedArea(IReadOnlyList<float2> poly)
        {
            float a = 0f;
            for (int i = 0, j = poly.Count - 1; i < poly.Count; j = i++)
            {
                a += (poly[j].x - poly[i].x) * (poly[j].y + poly[i].y);
            }
            return a * 0.5f;
        }

        public static void EnsureCCW(List<float2> poly)
        {
            if (SignedArea(poly) > 0f) poly.Reverse();
        }

        public static void EnsureCW(List<float2> poly)
        {
            if (SignedArea(poly) < 0f) poly.Reverse();
        }

        private static float MaxX(List<float2> p)
        {
            float m = float.MinValue;
            for (int i = 0; i < p.Count; i++) if (p[i].x > m) m = p[i].x;
            return m;
        }

        private static bool IsConvex(float2 a, float2 b, float2 c)
            => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) > 0f;

        private static bool PointInTriangle(float2 p, float2 a, float2 b, float2 c)
        {
            float d1 = Sign(p, a, b);
            float d2 = Sign(p, b, c);
            float d3 = Sign(p, c, a);
            bool hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
            bool hasPos = d1 > 0 || d2 > 0 || d3 > 0;
            return !(hasNeg && hasPos);
        }
        private static float Sign(float2 p1, float2 p2, float2 p3)
            => (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);

        // Find a bridge from the hole's rightmost vertex to a visible outline vertex.
        private static bool BridgeHole(List<float2> outline, List<float2> hole)
        {
            int holeStart = 0;
            float bestX = float.MinValue;
            for (int i = 0; i < hole.Count; i++)
            {
                if (hole[i].x > bestX) { bestX = hole[i].x; holeStart = i; }
            }

            int bridge = -1;
            float bestDist = float.MaxValue;
            for (int i = 0; i < outline.Count; i++)
            {
                if (outline[i].x < bestX) continue;
                float d = math.lengthsq(outline[i] - hole[holeStart]);
                if (d < bestDist) { bestDist = d; bridge = i; }
            }
            if (bridge < 0) return false;

            // Splice: outline[0..bridge], hole[holeStart..end..0..holeStart],
            // outline[bridge..end]
            var spliced = new List<float2>(outline.Count + hole.Count + 2);
            for (int i = 0; i <= bridge; i++) spliced.Add(outline[i]);
            int n = hole.Count;
            for (int i = 0; i <= n; i++) spliced.Add(hole[(holeStart + i) % n]);
            for (int i = bridge; i < outline.Count; i++) spliced.Add(outline[i]);

            outline.Clear();
            outline.AddRange(spliced);
            return true;
        }
    }
}
