using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;

namespace PokemonGo.Jobs
{
    /// <summary>
    /// Generates a triangle-strip ribbon along a polyline with mitred joins.
    /// Outputs two vertices per input point (left, right). The C# caller
    /// generates triangle indices since they are deterministic.
    /// </summary>
    [BurstCompile(FloatPrecision.Standard, FloatMode.Fast)]
    public struct PolylineRibbonJob : IJob
    {
        [ReadOnly] public NativeArray<float2> Points;
        public float HalfWidth;
        [WriteOnly] public NativeArray<float2> LeftVerts;
        [WriteOnly] public NativeArray<float2> RightVerts;

        public void Execute()
        {
            int n = Points.Length;
            if (n < 2) return;

            for (int i = 0; i < n; i++)
            {
                float2 prev = i == 0 ? Points[i] : Points[i - 1];
                float2 next = i == n - 1 ? Points[i] : Points[i + 1];
                float2 dirIn  = math.normalizesafe(Points[i] - prev, float2.zero);
                float2 dirOut = math.normalizesafe(next - Points[i], float2.zero);
                if (math.all(dirIn == 0f)) dirIn = dirOut;
                if (math.all(dirOut == 0f)) dirOut = dirIn;
                float2 normalIn  = new float2(-dirIn.y, dirIn.x);
                float2 normalOut = new float2(-dirOut.y, dirOut.x);
                float2 miter = math.normalizesafe(normalIn + normalOut, normalIn);
                float dot = math.max(math.dot(miter, normalIn), 0.1f);
                float2 offset = miter * (HalfWidth / dot);
                LeftVerts[i]  = Points[i] - offset;
                RightVerts[i] = Points[i] + offset;
            }
        }
    }
}
