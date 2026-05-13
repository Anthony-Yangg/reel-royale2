using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;

namespace PokemonGo.Jobs
{
    /// <summary>
    /// Bulk transforms a buffer of vector-tile local coordinates (0..extent
    /// per axis, Y down) to Unity world meters. Used when a single tile has
    /// hundreds of features and we want to batch the projection on worker
    /// threads instead of doing it inline on the main thread.
    ///
    /// Caller fills <see cref="LocalCoords"/>, sets the tile parameters,
    /// schedules the job, then reads <see cref="WorldCoords"/> on completion.
    /// </summary>
    [BurstCompile(FloatPrecision.Standard, FloatMode.Fast)]
    public struct TileLocalToWorldJob : IJobParallelFor
    {
        [ReadOnly] public NativeArray<int2> LocalCoords;
        [WriteOnly] public NativeArray<float2> WorldCoords;

        public int Extent;
        public int TileX;
        public int TileY;
        public int Zoom;
        public double2 OriginMeters;

        public void Execute(int i)
        {
            int2 lc = LocalCoords[i];
            double tileSize = OriginShift * 2.0 / (1 << Zoom);
            // Re-implement WebMercator NW corner inline so we stay in Burst.
            double nwX = (TileX / (double)(1 << Zoom)) * 360.0 - 180.0;
            double nRad = math.atan(math.sinh(math.PI_DBL * (1 - 2.0 * TileY / (1 << Zoom))));
            double latNW = nRad * 180.0 / math.PI_DBL;
            double lngNW = nwX;

            // NW in EPSG:3857
            double clampedLat = math.clamp(latNW, -85.05112878, 85.05112878);
            double nwMx = lngNW * OriginShift / 180.0;
            double nwMy = math.log(math.tan((90.0 + clampedLat) * math.PI_DBL / 360.0))
                          / (math.PI_DBL / 180.0) * OriginShift / 180.0;

            double mx = nwMx + (lc.x / (double)Extent) * tileSize;
            double my = nwMy - (lc.y / (double)Extent) * tileSize;

            WorldCoords[i] = new float2(
                (float)(mx - OriginMeters.x),
                (float)(my - OriginMeters.y));
        }

        private const double OriginShift = math.PI_DBL * 6_378_137.0;
    }
}
