using System;
using System.Runtime.CompilerServices;
using Unity.Mathematics;

namespace PokemonGo.GIS
{
    /// <summary>
    /// Fully-qualified slippy tile address (zoom + xy). 64 bits total so it
    /// fits in a native register and is a valid <c>NativeHashMap</c> key.
    /// </summary>
    [Serializable]
    public readonly struct TileId : IEquatable<TileId>, IComparable<TileId>
    {
        public readonly int Z;
        public readonly int X;
        public readonly int Y;

        public TileId(int z, int x, int y) { Z = z; X = x; Y = y; }

        public static readonly TileId Invalid = new(-1, -1, -1);
        public bool IsValid => Z >= 0;

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public ulong PackedKey =>
            ((ulong)(uint)Z << 56) | ((ulong)(uint)X << 28) | (ulong)(uint)Y;

        public bool Equals(TileId other) => Z == other.Z && X == other.X && Y == other.Y;
        public override bool Equals(object obj) => obj is TileId t && Equals(t);
        public override int GetHashCode() => unchecked(Z * 73856093 ^ X * 19349663 ^ Y * 83492791);
        public int CompareTo(TileId other) => PackedKey.CompareTo(other.PackedKey);
        public override string ToString() => $"{Z}/{X}/{Y}";

        public TileId Parent =>
            Z <= 0 ? Invalid : new TileId(Z - 1, X >> 1, Y >> 1);

        public bool IsNeighborOf(in TileId other)
            => Z == other.Z &&
               math.abs(X - other.X) <= 1 &&
               math.abs(Y - other.Y) <= 1 &&
               !Equals(other);

        public int ChebyshevDistance(in TileId other)
            => Z == other.Z
                ? math.max(math.abs(X - other.X), math.abs(Y - other.Y))
                : int.MaxValue;
    }
}
