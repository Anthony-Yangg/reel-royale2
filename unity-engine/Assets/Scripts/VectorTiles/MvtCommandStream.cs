using System;
using System.Collections.Generic;
using Unity.Mathematics;

namespace PokemonGo.VectorTiles
{
    /// <summary>
    /// Decodes the MVT geometry "command integer stream" into discrete ring
    /// or line arrays. The stream is a packed sequence of:
    /// <code>
    ///   command-id          (3 bits) | repeat-count (29 bits)
    ///   followed by 2*repeat-count zigzag-encoded varints (dx, dy)
    /// </code>
    /// Commands: MoveTo=1, LineTo=2, ClosePath=7.
    /// </summary>
    public static class MvtCommandStream
    {
        private const int CMD_MOVE_TO = 1;
        private const int CMD_LINE_TO = 2;
        private const int CMD_CLOSE_PATH = 7;

        /// <summary>
        /// Decode a polygon command stream to a list of rings. Each MoveTo
        /// starts a new ring; ClosePath finalises it.
        /// </summary>
        public static void DecodePolygon(ReadOnlySpan<uint> packed, List<int2[]> outRings)
        {
            outRings.Clear();
            int cursorX = 0, cursorY = 0;
            int i = 0;
            List<int2> current = null;

            while (i < packed.Length)
            {
                uint cmdInt = packed[i++];
                int cmd = (int)(cmdInt & 0x7);
                int count = (int)(cmdInt >> 3);

                switch (cmd)
                {
                    case CMD_MOVE_TO:
                        for (int k = 0; k < count; k++)
                        {
                            if (i + 1 >= packed.Length) return;
                            cursorX += ZigZag((int)packed[i++]);
                            cursorY += ZigZag((int)packed[i++]);
                            current = new List<int2>(16) { new int2(cursorX, cursorY) };
                        }
                        break;

                    case CMD_LINE_TO:
                        if (current == null) current = new List<int2>(16);
                        for (int k = 0; k < count; k++)
                        {
                            if (i + 1 >= packed.Length) return;
                            cursorX += ZigZag((int)packed[i++]);
                            cursorY += ZigZag((int)packed[i++]);
                            current.Add(new int2(cursorX, cursorY));
                        }
                        break;

                    case CMD_CLOSE_PATH:
                        if (current != null && current.Count > 0)
                        {
                            outRings.Add(current.ToArray());
                            current = null;
                        }
                        break;
                }
            }
            if (current != null && current.Count > 0)
                outRings.Add(current.ToArray());
        }

        /// <summary>
        /// Decode a linestring/polyline command stream. Each MoveTo starts a
        /// new polyline; subsequent LineTos extend it.
        /// </summary>
        public static void DecodeLine(ReadOnlySpan<uint> packed, List<int2[]> outLines)
        {
            outLines.Clear();
            int cursorX = 0, cursorY = 0;
            int i = 0;
            List<int2> current = null;

            while (i < packed.Length)
            {
                uint cmdInt = packed[i++];
                int cmd = (int)(cmdInt & 0x7);
                int count = (int)(cmdInt >> 3);

                if (cmd == CMD_MOVE_TO)
                {
                    if (current != null && current.Count > 1)
                        outLines.Add(current.ToArray());
                    for (int k = 0; k < count; k++)
                    {
                        if (i + 1 >= packed.Length) return;
                        cursorX += ZigZag((int)packed[i++]);
                        cursorY += ZigZag((int)packed[i++]);
                        current = new List<int2>(32) { new int2(cursorX, cursorY) };
                    }
                }
                else if (cmd == CMD_LINE_TO)
                {
                    if (current == null) current = new List<int2>(32);
                    for (int k = 0; k < count; k++)
                    {
                        if (i + 1 >= packed.Length) return;
                        cursorX += ZigZag((int)packed[i++]);
                        cursorY += ZigZag((int)packed[i++]);
                        current.Add(new int2(cursorX, cursorY));
                    }
                }
            }
            if (current != null && current.Count > 1)
                outLines.Add(current.ToArray());
        }

        /// <summary>Decode a point geometry. A single MoveTo with N points.</summary>
        public static void DecodePoints(ReadOnlySpan<uint> packed, List<int2> outPoints)
        {
            outPoints.Clear();
            int cursorX = 0, cursorY = 0;
            int i = 0;
            while (i < packed.Length)
            {
                uint cmdInt = packed[i++];
                int cmd = (int)(cmdInt & 0x7);
                int count = (int)(cmdInt >> 3);
                if (cmd != CMD_MOVE_TO) return;
                for (int k = 0; k < count; k++)
                {
                    if (i + 1 >= packed.Length) return;
                    cursorX += ZigZag((int)packed[i++]);
                    cursorY += ZigZag((int)packed[i++]);
                    outPoints.Add(new int2(cursorX, cursorY));
                }
            }
        }

        private static int ZigZag(int n) => (n >> 1) ^ -(n & 1);
    }
}
