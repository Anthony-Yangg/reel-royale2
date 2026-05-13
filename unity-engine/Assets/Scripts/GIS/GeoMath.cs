using Unity.Mathematics;

namespace PokemonGo.GIS
{
    /// <summary>
    /// Spherical-earth helpers: distance, bearing, offset along a bearing.
    /// We use a sphere not an ellipsoid because at game scales the error is
    /// sub-centimetre.
    /// </summary>
    public static class GeoMath
    {
        public const double EarthRadiusMeters = 6_378_137.0;

        public static GeoCoordinate Offset(in GeoCoordinate from, double bearingDeg, double distanceMeters)
        {
            double d = distanceMeters / EarthRadiusMeters;
            double br = bearingDeg * math.PI_DBL / 180.0;
            double lat1 = from.Latitude * math.PI_DBL / 180.0;
            double lng1 = from.Longitude * math.PI_DBL / 180.0;

            double lat2 = math.asin(math.sin(lat1) * math.cos(d) +
                                    math.cos(lat1) * math.sin(d) * math.cos(br));
            double lng2 = lng1 + math.atan2(
                math.sin(br) * math.sin(d) * math.cos(lat1),
                math.cos(d) - math.sin(lat1) * math.sin(lat2));

            return new GeoCoordinate(
                lat2 * 180.0 / math.PI_DBL,
                lng2 * 180.0 / math.PI_DBL,
                from.AltitudeMeters);
        }

        /// <summary>Lerp two coordinates along the great-circle (small-distance approximation).</summary>
        public static GeoCoordinate Lerp(in GeoCoordinate a, in GeoCoordinate b, double t)
        {
            t = math.clamp(t, 0.0, 1.0);
            return new GeoCoordinate(
                a.Latitude * (1.0 - t) + b.Latitude * t,
                a.Longitude * (1.0 - t) + b.Longitude * t,
                math.lerp(a.AltitudeMeters, b.AltitudeMeters, (float)t));
        }
    }
}
