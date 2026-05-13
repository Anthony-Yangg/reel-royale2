using System;
using System.Runtime.CompilerServices;
using System.Text;

namespace PokemonGo.VectorTiles
{
    /// <summary>
    /// Tight, allocation-conscious Protocol Buffers reader for Mapbox Vector
    /// Tiles. Supports only the wire types and field kinds used by the MVT
    /// schema (varint, length-delimited, fixed32). We do not call into any
    /// protobuf runtime to keep the IL2CPP-stripped binary lean.
    ///
    /// Spec references:
    /// - MVT 2.1: https://github.com/mapbox/vector-tile-spec/tree/master/2.1
    /// - Protobuf wire format: https://protobuf.dev/programming-guides/encoding/
    /// </summary>
    public ref struct ProtobufReader
    {
        public enum WireType : byte
        {
            Varint = 0,
            Fixed64 = 1,
            LengthDelimited = 2,
            Fixed32 = 5
        }

        private readonly ReadOnlySpan<byte> _data;
        private int _position;

        public ProtobufReader(ReadOnlySpan<byte> data) { _data = data; _position = 0; }

        public int Position => _position;
        public int Length => _data.Length;
        public bool HasMore => _position < _data.Length;
        public ReadOnlySpan<byte> Buffer => _data;

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public void Reset() => _position = 0;

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public bool ReadTag(out int fieldNumber, out WireType wireType)
        {
            if (_position >= _data.Length) { fieldNumber = 0; wireType = 0; return false; }
            ulong key = ReadVarint();
            fieldNumber = (int)(key >> 3);
            wireType = (WireType)(byte)(key & 0x7);
            return true;
        }

        public ulong ReadVarint()
        {
            ulong result = 0;
            int shift = 0;
            while (true)
            {
                if (_position >= _data.Length)
                    throw new FormatException("Protobuf varint truncated.");
                byte b = _data[_position++];
                result |= (ulong)(b & 0x7F) << shift;
                if ((b & 0x80) == 0) break;
                shift += 7;
                if (shift > 70) throw new FormatException("Protobuf varint overflow.");
            }
            return result;
        }

        public int ReadInt32() => (int)ReadVarint();
        public long ReadInt64() => (long)ReadVarint();
        public uint ReadUInt32() => (uint)ReadVarint();
        public ulong ReadUInt64() => ReadVarint();

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public int ReadSInt32()
        {
            uint n = (uint)ReadVarint();
            return (int)((n >> 1) ^ (uint)-(int)(n & 1));
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public long ReadSInt64()
        {
            ulong n = ReadVarint();
            return (long)((n >> 1) ^ (ulong)-(long)(n & 1));
        }

        public bool ReadBool() => ReadVarint() != 0;

        public float ReadFloat()
        {
            if (_position + 4 > _data.Length)
                throw new FormatException("Protobuf fixed32 truncated.");
            uint bits = (uint)(_data[_position] |
                               (_data[_position + 1] << 8) |
                               (_data[_position + 2] << 16) |
                               (_data[_position + 3] << 24));
            _position += 4;
            return BitConverter.Int32BitsToSingle((int)bits);
        }

        public double ReadDouble()
        {
            if (_position + 8 > _data.Length)
                throw new FormatException("Protobuf fixed64 truncated.");
            ulong bits = 0;
            for (int i = 0; i < 8; i++)
                bits |= (ulong)_data[_position + i] << (i * 8);
            _position += 8;
            return BitConverter.Int64BitsToDouble((long)bits);
        }

        public string ReadString()
        {
            int len = (int)ReadVarint();
            if (_position + len > _data.Length)
                throw new FormatException("Protobuf string truncated.");
            var span = _data.Slice(_position, len);
            _position += len;
            return Encoding.UTF8.GetString(span);
        }

        public ReadOnlySpan<byte> ReadBytes()
        {
            int len = (int)ReadVarint();
            if (_position + len > _data.Length)
                throw new FormatException("Protobuf bytes truncated.");
            var slice = _data.Slice(_position, len);
            _position += len;
            return slice;
        }

        /// <summary>Skip the next value matching the wire type.</summary>
        public void SkipField(WireType wt)
        {
            switch (wt)
            {
                case WireType.Varint:           ReadVarint(); break;
                case WireType.Fixed64:          _position += 8; break;
                case WireType.LengthDelimited:  _position += (int)ReadVarint(); break;
                case WireType.Fixed32:          _position += 4; break;
                default:
                    throw new FormatException($"Unsupported wire type {wt}");
            }
            if (_position > _data.Length)
                throw new FormatException("Protobuf truncated while skipping.");
        }

        /// <summary>Return a sub-reader over a length-delimited message.</summary>
        public ProtobufReader OpenSubMessage()
        {
            int len = (int)ReadVarint();
            if (_position + len > _data.Length)
                throw new FormatException("Protobuf sub-message truncated.");
            var slice = _data.Slice(_position, len);
            _position += len;
            return new ProtobufReader(slice);
        }
    }
}
