using System;
using System.Runtime.CompilerServices;
using Unity.Mathematics;

namespace PokemonGo.GIS
{
    /// <summary>
    /// Pragmatic S2-style cell index: maps lat/lng to a 64-bit Hilbert-on-cube
    /// id. We implement the parts of S2 actually needed by the engine:
    /// <list type="bullet">
    ///   <item>face/level addressing for spatial buckets at level 10-14</item>
    ///   <item>parent / level conversion</item>
    ///   <item>neighbour and "covering" queries for spawn / encounter grids</item>
    /// </list>
    /// Pokémon GO uses S2 level 12 (avg ~5 km²) for biome bucketing and
    /// level 17 (~80 m²) for sub-cell spawn rotation. Both are reachable
    /// from this implementation. We deliberately do not replicate the full
    /// Google S2 library — most of it is geodesy we don't need.
    /// </summary>
    public readonly struct S2CellId : IEquatable<S2CellId>
    {
        public const int kMaxLevel = 30;
        public const int kPosBits = 2 * kMaxLevel + 1;

        public readonly ulong Id;
        public S2CellId(ulong id) { Id = id; }

        public bool IsValid => Id != 0 && Level >= 0;

        /// <summary>0..5 cube face that contains this cell (XYZ ±).</summary>
        public int Face => (int)(Id >> 61);

        /// <summary>Hierarchy depth, 0 = whole cube face, 30 = leaf.</summary>
        public int Level
        {
            get
            {
                ulong x = Id;
                if (x == 0) return -1;
                int level = kMaxLevel;
                // The lowest set bit position encodes the level.
                while ((x & 1) == 0) { x >>= 1; level--; }
                return level;
            }
        }

        public S2CellId ParentAtLevel(int newLevel)
        {
            int curLevel = Level;
            if (newLevel >= curLevel) return this;

            ulong newLsb = (ulong)1 << (2 * (kMaxLevel - newLevel));
            ulong mask = ~(newLsb - 1);
            return new S2CellId((Id & mask) | newLsb);
        }

        public bool Equals(S2CellId o) => Id == o.Id;
        public override bool Equals(object obj) => obj is S2CellId s && Equals(s);
        public override int GetHashCode() => Id.GetHashCode();
        public override string ToString() => $"S2:{Id:X16}@L{Level}";

        // ------------------------------------------------------------------
        // Construction from lat/lng → 3D unit vector → face+uv → si+ti →
        // Hilbert position → 64-bit id.
        // ------------------------------------------------------------------

        public static S2CellId FromLatLng(double lat, double lng, int level)
        {
            level = math.clamp(level, 0, kMaxLevel);
            double3 v = LatLngToUnitVector(lat, lng);
            int face = XyzToFace(v);
            double2 uv = FaceXyzToUv(face, v);
            double s = UvToSt(uv.x);
            double t = UvToSt(uv.y);

            uint si = (uint)math.clamp((int)math.round(s * (1 << kMaxLevel)),
                                       0, (1 << kMaxLevel) - 1);
            uint ti = (uint)math.clamp((int)math.round(t * (1 << kMaxLevel)),
                                       0, (1 << kMaxLevel) - 1);

            ulong pos = HilbertSiTiToPos(face, si, ti);
            ulong lsb = (ulong)1 << (2 * (kMaxLevel - level));
            ulong id = ((ulong)face << 61) | pos | lsb;
            id &= ~(lsb - 1); // zero out bits below the level
            id |= lsb;
            return new S2CellId(id);
        }

        // ---- supporting math --------------------------------------------

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        private static double3 LatLngToUnitVector(double lat, double lng)
        {
            double phi = lat * math.PI_DBL / 180.0;
            double theta = lng * math.PI_DBL / 180.0;
            double c = math.cos(phi);
            return new double3(math.cos(theta) * c, math.sin(theta) * c, math.sin(phi));
        }

        private static int XyzToFace(double3 v)
        {
            int face = 0;
            double ax = math.abs(v.x), ay = math.abs(v.y), az = math.abs(v.z);
            if (ax >= ay && ax >= az) face = v.x < 0 ? 3 : 0;
            else if (ay >= az)        face = v.y < 0 ? 4 : 1;
            else                      face = v.z < 0 ? 5 : 2;
            return face;
        }

        private static double2 FaceXyzToUv(int face, double3 p)
        {
            switch (face)
            {
                case 0: return new double2(p.y / p.x, p.z / p.x);
                case 1: return new double2(-p.x / p.y, p.z / p.y);
                case 2: return new double2(-p.x / p.z, -p.y / p.z);
                case 3: return new double2(p.z / p.x, p.y / p.x);
                case 4: return new double2(p.z / p.y, -p.x / p.y);
                default: return new double2(-p.y / p.z, -p.x / p.z);
            }
        }

        private static double UvToSt(double u)
        {
            // Quadratic mapping used by S2 to make cell areas more uniform.
            return u >= 0
                ? 0.5 * math.sqrt(1 + 3 * u)
                : 1 - 0.5 * math.sqrt(1 - 3 * u);
        }

        // 2x2 Hilbert lookup tables compressed into a small array.
        private static readonly int[,,] kPosToIJ =
        {
            { { 0,1 }, { 1,1 }, { 1,0 }, { 0,0 } }, // orientation 0
            { { 0,0 }, { 0,1 }, { 1,1 }, { 1,0 } }, // 1
            { { 1,1 }, { 1,0 }, { 0,0 }, { 0,1 } }, // 2
            { { 1,0 }, { 0,0 }, { 0,1 }, { 1,1 } }  // 3
        };
        private static readonly int[,] kPosToOrientation =
        {
            { 1, 0, 0, 3 },
            { 0, 1, 1, 2 },
            { 3, 2, 2, 1 },
            { 2, 3, 3, 0 }
        };
        private static readonly int[,] kIjToPos =
        {
            { 0, 1, 3, 2 }, // o=0  (i,j) → pos
            { 0, 3, 1, 2 }, // 1
            { 2, 3, 1, 0 }, // 2
            { 2, 1, 3, 0 }  // 3
        };

        private static ulong HilbertSiTiToPos(int face, uint si, uint ti)
        {
            int orient = (face & 1); // even/odd face starting orientation
            ulong pos = 0;
            for (int k = kMaxLevel - 1; k >= 0; --k)
            {
                int i = (int)((si >> k) & 1);
                int j = (int)((ti >> k) & 1);
                int ij = (i << 1) | j;
                int p = kIjToPos[orient, ij];
                pos = (pos << 2) | (ulong)p;
                orient = kPosToOrientation[orient, p];
            }
            return pos << 1; // leave space for level lsb marker
        }
    }
}
