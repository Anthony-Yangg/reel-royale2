using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace PokemonGo.Core
{
    public interface IEventBus : IService
    {
        void Subscribe<T>(Action<T> handler) where T : struct;
        void Unsubscribe<T>(Action<T> handler) where T : struct;
        void Publish<T>(in T evt) where T : struct;
    }

    /// <summary>
    /// Allocation-free strongly-typed event bus. Each event type gets a single
    /// static slot via the <see cref="Channel{T}"/> trick so dispatch is a
    /// dictionary-free direct invocation.
    /// </summary>
    public sealed class EventBus : IEventBus
    {
        public string ServiceName => "EventBus";
        public int InitOrder => -1000;

        public Task InitializeAsync(CancellationToken ct) => Task.CompletedTask;
        public void OnAllServicesReady() { }
        public void Dispose() { ChannelRegistry.ClearAll(); }

        public void Subscribe<T>(Action<T> handler) where T : struct
            => Channel<T>.Subscribe(handler);

        public void Unsubscribe<T>(Action<T> handler) where T : struct
            => Channel<T>.Unsubscribe(handler);

        public void Publish<T>(in T evt) where T : struct
            => Channel<T>.Invoke(evt);

        private static class Channel<T> where T : struct
        {
            private static readonly List<Action<T>> Handlers = new(4);
            private static readonly object Lock = new();

            static Channel()
            {
                ChannelRegistry.Register(ClearAll);
            }

            public static void Subscribe(Action<T> h)
            {
                lock (Lock) Handlers.Add(h);
            }

            public static void Unsubscribe(Action<T> h)
            {
                lock (Lock) Handlers.Remove(h);
            }

            public static void Invoke(T evt)
            {
                lock (Lock)
                {
                    for (int i = 0; i < Handlers.Count; i++)
                    {
                        try { Handlers[i](evt); }
                        catch (Exception e) { EngineLog.Error($"EventBus<{typeof(T).Name}>: {e}"); }
                    }
                }
            }

            public static void ClearAll() { lock (Lock) Handlers.Clear(); }
        }

        private static class ChannelRegistry
        {
            private static readonly List<Action> ClearActions = new(16);
            private static readonly object Lock = new();

            public static void Register(Action clear)
            {
                lock (Lock) ClearActions.Add(clear);
            }

            public static void ClearAll()
            {
                lock (Lock)
                {
                    for (int i = 0; i < ClearActions.Count; i++) ClearActions[i]();
                }
            }
        }
    }

    // -------- Engine-wide event payloads (lean structs, no GC). --------

    public readonly struct GpsLocationChangedEvent
    {
        public readonly double latitude;
        public readonly double longitude;
        public readonly float accuracyMeters;
        public readonly float headingDegrees;
        public readonly bool isSimulated;

        public GpsLocationChangedEvent(double lat, double lng, float acc, float hdg, bool sim)
        {
            latitude = lat; longitude = lng; accuracyMeters = acc;
            headingDegrees = hdg; isSimulated = sim;
        }
    }

    public readonly struct TileLoadedEvent
    {
        public readonly int z, x, y;
        public TileLoadedEvent(int z, int x, int y) { this.z = z; this.x = x; this.y = y; }
    }

    public readonly struct TileUnloadedEvent
    {
        public readonly int z, x, y;
        public TileUnloadedEvent(int z, int x, int y) { this.z = z; this.x = x; this.y = y; }
    }

    public readonly struct ChunkActivatedEvent
    {
        public readonly int z, x, y;
        public ChunkActivatedEvent(int z, int x, int y) { this.z = z; this.x = x; this.y = y; }
    }

    public readonly struct OriginShiftedEvent
    {
        public readonly UnityEngine.Vector3 deltaMeters;
        public OriginShiftedEvent(UnityEngine.Vector3 d) { deltaMeters = d; }
    }
}
