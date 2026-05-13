using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace PokemonGo.Core
{
    /// <summary>
    /// Minimal dependency-injection container tailored to a Unity engine root.
    /// We avoid reflective DI frameworks like Zenject/VContainer to keep the
    /// boot path allocation-free and IL2CPP-friendly. Services register
    /// concrete types against one or more interface keys.
    ///
    /// Thread-safety: registration is single-threaded (boot phase). Resolution
    /// is lock-free after initialization (read-mostly dictionary).
    /// </summary>
    public sealed class ServiceLocator : IDisposable
    {
        private static ServiceLocator s_instance;
        public static ServiceLocator Instance => s_instance ??= new ServiceLocator();

        private readonly Dictionary<Type, IService> _services = new(64);
        private readonly List<IService> _ordered = new(64);
        private readonly List<ITickable> _tickables = new(64);
        private readonly List<IFixedTickable> _fixedTickables = new(32);
        private readonly List<ILateTickable> _lateTickables = new(32);

        private bool _initialized;
        private bool _disposed;

        public IReadOnlyList<IService> AllServices => _ordered;

        /// <summary>Register a service against its concrete and interface types.</summary>
        public void Register<TInterface>(TInterface service)
            where TInterface : class, IService
        {
            if (_initialized)
            {
                throw new InvalidOperationException(
                    $"Cannot register {typeof(TInterface).Name} after initialization. " +
                    "Register all services during bootstrap.");
            }

            if (service == null) throw new ArgumentNullException(nameof(service));

            var iface = typeof(TInterface);
            if (_services.ContainsKey(iface))
            {
                throw new InvalidOperationException(
                    $"Service for {iface.Name} already registered.");
            }

            _services[iface] = service;

            if (!_ordered.Contains(service))
            {
                _ordered.Add(service);
            }
        }

        /// <summary>Resolve a service. Throws if missing — never returns null.</summary>
        public T Resolve<T>() where T : class, IService
        {
            if (_services.TryGetValue(typeof(T), out var s)) return (T)s;
            throw new InvalidOperationException(
                $"Service {typeof(T).Name} not registered. " +
                "Did you forget to add it to EngineBootstrap?");
        }

        /// <summary>Try-resolve variant for optional services.</summary>
        public bool TryResolve<T>(out T service) where T : class, IService
        {
            if (_services.TryGetValue(typeof(T), out var s))
            {
                service = (T)s;
                return true;
            }
            service = null;
            return false;
        }

        /// <summary>Initialize all registered services in InitOrder.</summary>
        public async Task InitializeAllAsync(CancellationToken ct)
        {
            if (_initialized) return;

            _ordered.Sort((a, b) => a.InitOrder.CompareTo(b.InitOrder));

            foreach (var service in _ordered)
            {
                ct.ThrowIfCancellationRequested();
                EngineLog.Info($"[ServiceLocator] Init {service.ServiceName} (order={service.InitOrder})");
                await service.InitializeAsync(ct).ConfigureAwait(false);
            }

            // Cache per-frame hook lists once after init for jitter-free dispatch.
            foreach (var s in _ordered)
            {
                if (s is ITickable t) _tickables.Add(t);
                if (s is IFixedTickable ft) _fixedTickables.Add(ft);
                if (s is ILateTickable lt) _lateTickables.Add(lt);
            }

            foreach (var service in _ordered) service.OnAllServicesReady();

            _initialized = true;
            EngineLog.Info($"[ServiceLocator] All {_ordered.Count} services initialized.");
        }

        internal void Tick(float dt)
        {
            for (int i = 0, n = _tickables.Count; i < n; i++)
            {
                try { _tickables[i].Tick(dt); }
                catch (Exception e) { EngineLog.Error($"Tick {_tickables[i]}: {e}"); }
            }
        }

        internal void FixedTick(float dt)
        {
            for (int i = 0, n = _fixedTickables.Count; i < n; i++)
            {
                try { _fixedTickables[i].FixedTick(dt); }
                catch (Exception e) { EngineLog.Error($"FixedTick: {e}"); }
            }
        }

        internal void LateTick(float dt)
        {
            for (int i = 0, n = _lateTickables.Count; i < n; i++)
            {
                try { _lateTickables[i].LateTick(dt); }
                catch (Exception e) { EngineLog.Error($"LateTick: {e}"); }
            }
        }

        public void Dispose()
        {
            if (_disposed) return;

            for (int i = _ordered.Count - 1; i >= 0; i--)
            {
                try { _ordered[i].Dispose(); }
                catch (Exception e) { EngineLog.Error($"Dispose: {e}"); }
            }

            _services.Clear();
            _ordered.Clear();
            _tickables.Clear();
            _fixedTickables.Clear();
            _lateTickables.Clear();
            _disposed = true;
            s_instance = null;
        }
    }
}
