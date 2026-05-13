using Unity.Mathematics;

namespace PokemonGo.GIS
{
    /// <summary>
    /// Axis-aligned geo bounding box. Stored as (min lat/lng, max lat/lng).
    /// </summary>
    public readonly struct GeoBounds
    {
        public readonly double MinLat, MinLng, MaxLat, MaxLng;

        public GeoBounds(double minLat, double minLng, double maxLat, double maxLng)
        {
            MinLat = minLat; MinLng = minLng; MaxLat = maxLat; MaxLng = maxLng;
        }

        public bool Contains(in GeoCoordinate c) =>
            c.Latitude >= MinLat && c.Latitude <= MaxLat &&
            c.Longitude >= MinLng && c.Longitude <= MaxLng;

        public bool Intersects(in GeoBounds b) =>
            !(b.MaxLng < MinLng || b.MinLng > MaxLng ||
              b.MaxLat < MinLat || b.MinLat > MaxLat);

        /// <summary>Bounds covering a given tile.</summary>
        public static GeoBounds FromTile(TileId tile)
        {
            var (lat1, lng1) = WebMercator.TileToLatLng(tile.X, tile.Y, tile.Z);
            var (lat2, lng2) = WebMercator.TileToLatLng(tile.X + 1, tile.Y + 1, tile.Z);
            return new GeoBounds(math.min(lat1, lat2), math.min(lng1, lng2),
                                 math.max(lat1, lat2), math.max(lng1, lng2));
        }
    }
}
