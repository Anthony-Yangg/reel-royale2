using UnityEngine;

namespace PokemonGo.Rendering
{
    /// <summary>
    /// Cheap CPU-side frustum culler. Unity already culls per renderer, but
    /// when we have thousands of pooled chunks the per-renderer cost adds up;
    /// performing a frustum vs. chunk-AABB check before enabling the chunk
    /// avoids that work entirely.
    /// </summary>
    public static class FrustumCuller
    {
        private static readonly Plane[] s_planes = new Plane[6];

        public static void Update(Camera cam)
        {
            GeometryUtility.CalculateFrustumPlanes(cam, s_planes);
        }

        public static bool IsVisible(in Bounds b)
            => GeometryUtility.TestPlanesAABB(s_planes, b);
    }
}
