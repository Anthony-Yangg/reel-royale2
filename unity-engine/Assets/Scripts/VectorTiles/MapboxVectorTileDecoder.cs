using System;
using System.Buffers;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using Unity.Mathematics;

namespace PokemonGo.VectorTiles
{
    public interface IVectorTileDecoder : IService
    {
        VectorTile Decode(ReadOnlySpan<byte> bytes, int z, int x, int y);
        Task<VectorTile> DecodeAsync(byte[] bytes, int z, int x, int y, CancellationToken ct);
    }

    /// <summary>
    /// Decoder for the Mapbox / OSM vector-tile binary format.
    ///
    /// Schema (MVT 2.1):
    /// <code>
    /// message Tile {
    ///   repeated Layer layers = 3;
    /// }
    /// message Layer {
    ///   required uint32 version = 15 [default=1];
    ///   required string name = 1;
    ///   repeated Feature features = 2;
    ///   repeated string keys = 3;
    ///   repeated Value values = 4;
    ///   optional uint32 extent = 5 [default=4096];
    /// }
    /// message Feature {
    ///   optional uint64 id = 1;
    ///   repeated uint32 tags = 2 [packed=true];
    ///   optional GeomType type = 3 [default=UNKNOWN];
    ///   repeated uint32 geometry = 4 [packed=true];
    /// }
    /// message Value {
    ///   optional string string_value = 1;
    ///   optional float float_value = 2;
    ///   optional double double_value = 3;
    ///   optional int64 int_value = 4;
    ///   optional uint64 uint_value = 5;
    ///   optional sint64 sint_value = 6;
    ///   optional bool bool_value = 7;
    /// }
    /// </code>
    /// </summary>
    public sealed class MapboxVectorTileDecoder : IVectorTileDecoder
    {
        public string ServiceName => "MapboxVectorTileDecoder";
        public int InitOrder => -500;
        public Task InitializeAsync(CancellationToken ct) => Task.CompletedTask;
        public void OnAllServicesReady() { }
        public void Dispose() { }

        public Task<VectorTile> DecodeAsync(byte[] bytes, int z, int x, int y, CancellationToken ct)
        {
            return Task.Run(() => Decode(bytes, z, x, y), ct);
        }

        public VectorTile Decode(ReadOnlySpan<byte> bytes, int z, int x, int y)
        {
            // MVT tiles are commonly gzipped over the wire. Detect magic header.
            if (bytes.Length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b)
            {
                bytes = Gunzip(bytes);
            }

            var tile = new VectorTile { Z = z, X = x, Y = y };
            var reader = new ProtobufReader(bytes);

            while (reader.ReadTag(out int field, out var wt))
            {
                if (field == 3 && wt == ProtobufReader.WireType.LengthDelimited)
                {
                    var layerReader = reader.OpenSubMessage();
                    var layer = DecodeLayer(ref layerReader);
                    if (layer != null && layer.Features.Count > 0)
                        tile.Layers.Add(layer);
                }
                else
                {
                    reader.SkipField(wt);
                }
            }

            return tile;
        }

        // ------------------------------------------------------------------
        // Layer
        // ------------------------------------------------------------------

        private VectorLayer DecodeLayer(ref ProtobufReader r)
        {
            var layer = new VectorLayer();
            var rawFeatures = new List<RawFeature>(64);
            var keys = new List<string>(16);
            var values = new List<object>(16);

            while (r.ReadTag(out int field, out var wt))
            {
                switch (field)
                {
                    case 15: layer.Version = (int)r.ReadVarint(); break;
                    case 1:  layer.Name = r.ReadString(); break;
                    case 5:  layer.Extent = (int)r.ReadVarint(); break;
                    case 3:  keys.Add(r.ReadString()); break;
                    case 4:
                    {
                        var v = r.OpenSubMessage();
                        values.Add(DecodeValue(ref v));
                        break;
                    }
                    case 2:
                    {
                        var f = r.OpenSubMessage();
                        rawFeatures.Add(DecodeRawFeature(ref f));
                        break;
                    }
                    default: r.SkipField(wt); break;
                }
            }

            layer.Kind = ClassifyLayer(layer.Name);

            for (int i = 0; i < rawFeatures.Count; i++)
            {
                var f = ToVectorFeature(rawFeatures[i], keys, values, layer.Kind);
                if (f != null) layer.Features.Add(f);
            }
            return layer;
        }

        private object DecodeValue(ref ProtobufReader r)
        {
            object val = null;
            while (r.ReadTag(out int field, out var wt))
            {
                switch (field)
                {
                    case 1: val = r.ReadString(); break;
                    case 2: val = r.ReadFloat(); break;
                    case 3: val = r.ReadDouble(); break;
                    case 4: val = r.ReadInt64(); break;
                    case 5: val = (long)r.ReadUInt64(); break;
                    case 6: val = r.ReadSInt64(); break;
                    case 7: val = r.ReadBool(); break;
                    default: r.SkipField(wt); break;
                }
            }
            return val;
        }

        // ------------------------------------------------------------------
        // Feature
        // ------------------------------------------------------------------

        private struct RawFeature
        {
            public ulong Id;
            public int GeomType; // 1=Point 2=Line 3=Polygon
            public uint[] Tags;
            public uint[] Geometry;
        }

        private RawFeature DecodeRawFeature(ref ProtobufReader r)
        {
            var f = new RawFeature();
            while (r.ReadTag(out int field, out var wt))
            {
                switch (field)
                {
                    case 1: f.Id = r.ReadVarint(); break;
                    case 3: f.GeomType = (int)r.ReadVarint(); break;
                    case 2: f.Tags = ReadPackedVarintU32(ref r); break;
                    case 4: f.Geometry = ReadPackedVarintU32(ref r); break;
                    default: r.SkipField(wt); break;
                }
            }
            return f;
        }

        private static uint[] ReadPackedVarintU32(ref ProtobufReader r)
        {
            var inner = r.OpenSubMessage();
            var list = new List<uint>(64);
            while (inner.HasMore) list.Add((uint)inner.ReadVarint());
            return list.ToArray();
        }

        // ------------------------------------------------------------------
        // Feature finalization (tag resolution, classification)
        // ------------------------------------------------------------------

        private VectorFeature ToVectorFeature(
            RawFeature raw, List<string> keys, List<object> values, LayerKind kind)
        {
            var f = new VectorFeature
            {
                Id = raw.Id,
                Layer = kind,
                Geometry = raw.GeomType switch
                {
                    1 => GeomKind.Point,
                    2 => GeomKind.Line,
                    3 => GeomKind.Polygon,
                    _ => GeomKind.Unknown
                }
            };

            // Resolve tag key/value pairs onto the structured fields we care about.
            if (raw.Tags != null)
            {
                for (int i = 0; i + 1 < raw.Tags.Length; i += 2)
                {
                    int ki = (int)raw.Tags[i];
                    int vi = (int)raw.Tags[i + 1];
                    if (ki >= keys.Count || vi >= values.Count) continue;

                    string key = keys[ki];
                    object val = values[vi];
                    ApplyTag(f, key, val);
                }
            }

            // Decode geometry into rings / lines / points.
            if (raw.Geometry != null && raw.Geometry.Length > 0)
            {
                switch (f.Geometry)
                {
                    case GeomKind.Polygon: MvtCommandStream.DecodePolygon(raw.Geometry, f.Rings); break;
                    case GeomKind.Line:    MvtCommandStream.DecodeLine(raw.Geometry, f.Lines); break;
                    case GeomKind.Point:
                    {
                        var pts = new List<int2>(2);
                        MvtCommandStream.DecodePoints(raw.Geometry, pts);
                        // Represent points as zero-length lines for downstream code.
                        for (int i = 0; i < pts.Count; i++)
                            f.Lines.Add(new[] { pts[i], pts[i] });
                        break;
                    }
                }
            }

            return f;
        }

        private void ApplyTag(VectorFeature f, string key, object val)
        {
            switch (key)
            {
                case "class":
                    if (val is string sClass)
                    {
                        f.Road = sClass switch
                        {
                            "motorway"  => RoadClass.Motorway,
                            "trunk"     => RoadClass.Trunk,
                            "primary"   => RoadClass.Primary,
                            "secondary" => RoadClass.Secondary,
                            "tertiary"  => RoadClass.Tertiary,
                            "street"    => RoadClass.Street,
                            "path"      => RoadClass.Path,
                            "service"   => RoadClass.Service,
                            "pedestrian"=> RoadClass.Pedestrian,
                            _ => RoadClass.Unknown
                        };
                    }
                    break;
                case "name":
                case "name_en":
                    if (val is string s) f.Name = s;
                    break;
                case "height":
                    f.HeightMeters = ToFloat(val);
                    break;
                case "min_height":
                    break;
                case "render_height":
                    f.HeightMeters = math.max(f.HeightMeters, ToFloat(val));
                    break;
                case "type":
                case "subclass":
                    // upgrade landuse to park/water classes when appropriate
                    if (val is string subType && f.Layer == LayerKind.Landuse &&
                        (subType == "park" || subType == "wood" ||
                         subType == "garden" || subType == "playground" ||
                         subType == "pitch" || subType == "grass"))
                    {
                        f.Layer = LayerKind.Park;
                    }
                    break;
                case "minzoom":
                    f.MinZoom = (int)ToFloat(val);
                    break;
                case "layer":
                    f.LayerOrder = (int)ToFloat(val);
                    break;
            }
        }

        private static float ToFloat(object o)
        {
            return o switch
            {
                float f => f,
                double d => (float)d,
                long l => (float)l,
                int i => (float)i,
                string s => float.TryParse(s, out var v) ? v : 0f,
                _ => 0f
            };
        }

        // ------------------------------------------------------------------
        // Layer name → engine layer-kind classification.
        // Mapbox streets-v8 uses lowercase singular layer names.
        // ------------------------------------------------------------------

        private static LayerKind ClassifyLayer(string name)
        {
            if (string.IsNullOrEmpty(name)) return LayerKind.Unknown;
            switch (name)
            {
                case "road":
                case "transportation":
                case "bridge":
                case "tunnel":
                    return LayerKind.Road;
                case "building":
                    return LayerKind.Building;
                case "water":
                case "waterway":
                case "ocean":
                    return LayerKind.Water;
                case "park":
                case "park_label":
                    return LayerKind.Park;
                case "landuse":
                case "landuse_overlay":
                case "landcover":
                    return LayerKind.Landuse;
                case "boundary":
                case "admin":
                    return LayerKind.Boundary;
                case "poi_label":
                case "poi":
                    return LayerKind.Poi;
                case "place_label":
                case "place":
                    return LayerKind.Place;
                case "aeroway":
                case "transit":
                    return LayerKind.Transit;
                default: return LayerKind.Unknown;
            }
        }

        // ------------------------------------------------------------------
        // Gzip helper. Lives here to avoid a separate utility namespace.
        // ------------------------------------------------------------------

        private static byte[] Gunzip(ReadOnlySpan<byte> compressed)
        {
            byte[] rented = ArrayPool<byte>.Shared.Rent(compressed.Length);
            try
            {
                compressed.CopyTo(rented);
                using var ms = new MemoryStream(rented, 0, compressed.Length, writable: false);
                using var gz = new GZipStream(ms, CompressionMode.Decompress);
                using var outMs = new MemoryStream(compressed.Length * 4);
                gz.CopyTo(outMs);
                return outMs.ToArray();
            }
            finally
            {
                ArrayPool<byte>.Shared.Return(rented);
            }
        }
    }
}
