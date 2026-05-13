using System.Runtime.CompilerServices;
using Unity.Mathematics;

namespace PokemonGo.GIS
{
    /// <summary>
    /// Web Mercator (EPSG:3857) projection math. This is the projection used
    /// by Mapbox, Google, Bing and OSM slippy tiles. Latitude is clipped to
    /// ±85.05112878° (where the projection becomes infinite). Coordinates are
    /// in *meters* on a sphere of radius <see cref="EarthRadiusMeters"/>.
    ///
    /// All methods are pure, allocation-free, and Burst-compilable.
    /// </summary>
    public static class WebMercator
    {
        public const double EarthRadiusMeters = 6_378_137.0;
        public const double OriginShift = math.PI_DBL * EarthRadiusMeters; // ≈ 20037508.34
        public const double MaxLatitude = 85.05112878;

        // ------------------------------------------------------------------
        // Lat/Lng <-> Meters (EPSG:3857)
        // ------------------------------------------------------------------

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static double2 LatLngToMeters(double lat, double lng)
        {
            lat = math.clamp(lat, -MaxLatitude, MaxLatitude);
            double mx = lng * OriginShift / 180.0;
            double my = math.log(math.tan((90.0 + lat) * math.PI_DBL / 360.0))
                        / (math.PI_DBL / 180.0);
            my = my * OriginShift / 180.0;
            return new double2(mx, my);
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static (double lat, double lng) MetersToLatLng(double mx, double my)
        {
            double lng = (mx / OriginShift) * 180.0;
            double lat = (my / OriginShift) * 180.0;
            lat = 180.0 / math.PI_DBL *
                  (2.0 * math.atan(math.exp(lat * math.PI_DBL / 180.0)) - math.PI_DBL * 0.5);
            return (lat, lng);
        }

        // ------------------------------------------------------------------
        // Lat/Lng <-> Tile XYZ (slippy map)
        // ------------------------------------------------------------------

        /// <summary>Compute the slippy XY of the tile that contains the lat/lng at zoom z.</summary>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static int2 LatLngToTile(double lat, double lng, int zoom)
        {
            int n = 1 << zoom;
            double latRad = lat * math.PI_DBL / 180.0;
            int x = (int)math.floor((lng + 180.0) / 360.0 * n);
            int y = (int)math.floor(
                (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.PI_DBL)
                * 0.5 * n);
            x = math.clamp(x, 0, n - 1);
            y = math.clamp(y, 0, n - 1);
            return new int2(x, y);
        }

        /// <summary>Lat/Lng of the top-left corner of a tile (NW corner).</summary>
        public static (double lat, double lng) TileToLatLng(int x, int y, int zoom)
        {
            int n = 1 << zoom;
            double lng = x / (double)n * 360.0 - 180.0;
            double latRad = math.atan(math.sinh(math.PI_DBL * (1 - 2.0 * y / n)));
            double lat = latRad * 180.0 / math.PI_DBL;
            return (lat, lng);
        }

        /// <summary>Web Mercator (meters) origin of the NW corner of the tile.</summary>
        public static double2 TileNorthWestMeters(int x, int y, int zoom)
        {
            var (lat, lng) = TileToLatLng(x, y, zoom);
            return LatLngToMeters(lat, lng);
        }

        /// <summary>Meters covered by a single tile along x/y at the given zoom.</summary>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static double TileSizeMeters(int zoom)
            => OriginShift * 2.0 / (1 << zoom);

        /// <summary>
        /// Convert a vector-tile local coordinate (0..extent on each axis,
        /// y-axis inverted relative to screen) to meters in EPSG:3857.
        /// </summary>
        public static double2 VectorTileLocalToMeters(
            int localX, int localY, int extent, int tileX, int tileY, int zoom)
        {
            double tileSize = TileSizeMeters(zoom);
            double2 nw = TileNorthWestMeters(tileX, tileY, zoom);
            double mx = nw.x + (localX / (double)extent) * tileSize;
            double my = nw.y - (localY / (double)extent) * tileSize;
            return new double2(mx, my);
        }

        /// <summary>Ground resolution (meters per pixel at 256 px tile) at lat / zoom.</summary>
        public static double GroundResolutionMetersPerPixel(double lat, int zoom)
            => math.cos(lat * math.PI_DBL / 180.0) * 2 * math.PI_DBL * EarthRadiusMeters
               / (256.0 * (1 << zoom));
    }
}
