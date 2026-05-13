using System.Collections.Generic;
using Unity.Mathematics;

namespace PokemonGo.VectorTiles
{
    /// <summary>
    /// Subset of the MVT feature classification we actually render. We deliberately
    /// collapse the noisy upstream taxonomy into engine-friendly buckets so the
    /// stylization stage doesn't have to know about 80+ raw 'class' strings.
    /// </summary>
    public enum LayerKind : byte
    {
        Unknown,
        Road,
        Building,
        Water,
        Park,
        Landuse,
        Boundary,
        Poi,
        Place,
        Transit
    }

    public enum GeomKind : byte { Unknown, Point, Line, Polygon }

    public enum RoadClass : byte
    {
        Unknown,
        Motorway,
        Trunk,
        Primary,
        Secondary,
        Tertiary,
        Street,
        Path,
        Service,
        Pedestrian
    }

    /// <summary>
    /// Decoded vector feature. Geometry is stored as flat int32 spans in
    /// tile-local units (0..extent on each axis, Y-down). The mesh pipeline
    /// converts these to world meters in a Burst job.
    /// </summary>
    public sealed class VectorFeature
    {
        public ulong Id;
        public LayerKind Layer;
        public GeomKind Geometry;
        public RoadClass Road;
        public string Name;
        public int MinZoom;
        public float HeightMeters;   // building extrusion
        public int LayerOrder;       // for z-fighting resolution

        /// <summary>One ring per polygon contour; exteriors followed by interiors.</summary>
        public readonly List<int2[]> Rings = new(2);

        /// <summary>For line/point features: one polyline per stroke.</summary>
        public readonly List<int2[]> Lines = new(1);

        public override string ToString()
            => $"{Layer}/{Geometry} '{Name}' (h={HeightMeters}m)";
    }

    /// <summary>One decoded MVT layer.</summary>
    public sealed class VectorLayer
    {
        public string Name;
        public int Version = 1;
        public int Extent = 4096;
        public LayerKind Kind;
        public readonly List<VectorFeature> Features = new(64);
    }

    /// <summary>Fully decoded MVT tile, ready for mesh generation.</summary>
    public sealed class VectorTile
    {
        public int Z, X, Y;
        public readonly List<VectorLayer> Layers = new(8);

        public VectorLayer FindLayer(LayerKind kind)
        {
            for (int i = 0; i < Layers.Count; i++)
                if (Layers[i].Kind == kind) return Layers[i];
            return null;
        }
    }
}
