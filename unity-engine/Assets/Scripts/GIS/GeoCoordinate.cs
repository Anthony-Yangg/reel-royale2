using System;
using System.Runtime.CompilerServices;
using Unity.Mathematics;

namespace PokemonGo.GIS
{
    /// <summary>
    /// WGS84 geographic coordinate. Latitude and longitude are stored as
    /// <see cref="double"/> because the float epsilon at zoom 22 is on the
    /// order of centimetres-per-bit globally — well within mobile GPS error
    /// but enough to cause stitching cracks between tiles.
    /// </summary>
    [Serializable]
    public readonly struct GeoCoordinate : IEquatable<GeoCoordinate>
    {
        public readonly double Latitude;
        public readonly double Longitude;
        public readonly float AltitudeMeters;

        public GeoCoordinate(double lat, double lng, float alt = 0f)
        {
            Latitude = lat; Longitude = lng; AltitudeMeters = alt;
        }

        public static readonly GeoCoordinate Zero = new(0, 0, 0);

        /// <summary>True if the coordinate falls within valid WGS84 limits.</summary>
        public bool IsValid =>
            Latitude is >= -85.05112878 and <= 85.05112878 &&
            Longitude is >= -180 and <= 180;

        /// <summary>
        /// Haversine great-circle distance in meters. Accurate enough for the
        /// sub-kilometer game range; for global routing use Vincenty.
        /// </summary>
        public double DistanceMetersTo(in GeoCoordinate other)
        {
            const double R = 6_378_137.0; // WGS84 equatorial radius
            double lat1 = Latitude * math.PI_DBL / 180.0;
            double lat2 = other.Latitude * math.PI_DBL / 180.0;
            double dLat = (other.Latitude - Latitude) * math.PI_DBL / 180.0;
            double dLng = (other.Longitude - Longitude) * math.PI_DBL / 180.0;

            double a = math.sin(dLat * 0.5) * math.sin(dLat * 0.5) +
                       math.cos(lat1) * math.cos(lat2) *
                       math.sin(dLng * 0.5) * math.sin(dLng * 0.5);
            double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
            return R * c;
        }

        /// <summary>
        /// Compass bearing (degrees from north, clockwise) towards another
        /// coordinate. Used by the camera heading-align feature.
        /// </summary>
        public double BearingTo(in GeoCoordinate other)
        {
            double lat1 = Latitude * math.PI_DBL / 180.0;
            double lat2 = other.Latitude * math.PI_DBL / 180.0;
            double dLng = (other.Longitude - Longitude) * math.PI_DBL / 180.0;
            double y = math.sin(dLng) * math.cos(lat2);
            double x = math.cos(lat1) * math.sin(lat2) -
                       math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
            double brng = math.atan2(y, x) * 180.0 / math.PI_DBL;
            return (brng + 360.0) % 360.0;
        }

        public bool Equals(GeoCoordinate o) =>
            Latitude == o.Latitude && Longitude == o.Longitude && AltitudeMeters == o.AltitudeMeters;
        public override bool Equals(object obj) => obj is GeoCoordinate g && Equals(g);
        public override int GetHashCode() => HashCode.Combine(Latitude, Longitude, AltitudeMeters);
        public override string ToString() => $"({Latitude:F6}, {Longitude:F6})";

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static double DegToRad(double d) => d * math.PI_DBL / 180.0;
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static double RadToDeg(double r) => r * 180.0 / math.PI_DBL;
    }
}
