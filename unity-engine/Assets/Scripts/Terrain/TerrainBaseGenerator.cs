using PokemonGo.GIS;
using PokemonGo.Rendering;
using Unity.Mathematics;
using UnityEngine;

namespace PokemonGo.Terrain
{
    /// <summary>
    /// Produces a single tile-sized quad that acts as the base ground plane
    /// behind all other layers. We tessellate it (8×8 by default) so the
    /// shader can pull subtle world-curvature in the vertex stage to give
    /// the map that signature Pokémon-GO "globe" feel.
    /// </summary>
    public static class TerrainBaseGenerator
    {
        private const int kSubdiv = 8;

        public static void Build(
            MeshData mesh, ICoordinateService coords,
            int z, int tileX, int tileY,
            Color32 fillColor, float yOffset = -0.02f)
        {
            int extent = 4096;
            double2 nw = WebMercator.TileNorthWestMeters(tileX, tileY, z);
            double tileSize = WebMercator.TileSizeMeters(z);

            Vector3[,] grid = new Vector3[kSubdiv + 1, kSubdiv + 1];
            for (int j = 0; j <= kSubdiv; j++)
            {
                for (int i = 0; i <= kSubdiv; i++)
                {
                    double mx = nw.x + tileSize * (i / (double)kSubdiv);
                    double my = nw.y - tileSize * (j / (double)kSubdiv);
                    Vector3 w = coords.MetersToUnity(new double2(mx, my));
                    w.y = yOffset;
                    grid[i, j] = w;
                }
            }

            int baseV = mesh.Vertices.Count;
            for (int j = 0; j <= kSubdiv; j++)
            {
                for (int i = 0; i <= kSubdiv; i++)
                {
                    mesh.Vertices.Add(grid[i, j]);
                    mesh.Normals.Add(Vector3.up);
                    mesh.Uvs.Add(new Vector2(i / (float)kSubdiv, j / (float)kSubdiv));
                    mesh.Colors.Add(fillColor);
                }
            }

            int stride = kSubdiv + 1;
            for (int j = 0; j < kSubdiv; j++)
            {
                for (int i = 0; i < kSubdiv; i++)
                {
                    int a = baseV + j * stride + i;
                    int b = a + 1;
                    int c = a + stride;
                    int d = c + 1;
                    mesh.Indices.Add(a); mesh.Indices.Add(c); mesh.Indices.Add(b);
                    mesh.Indices.Add(b); mesh.Indices.Add(c); mesh.Indices.Add(d);
                }
            }
        }
    }
}
