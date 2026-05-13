using System;
using System.Threading;
using System.Threading.Tasks;

namespace PokemonGo.Core
{
    /// <summary>
    /// Base contract for every engine subsystem. The lifecycle is deterministic:
    /// Initialize → Start → (Tick per frame) → Shutdown. Services are owned by the
    /// <see cref="ServiceLocator"/> and resolved by their declaring interface so
    /// implementations can be swapped at runtime (e.g. real vs. simulated GPS).
    /// </summary>
    public interface IService : IDisposable
    {
        /// <summary>Stable name used by diagnostics and the debug HUD.</summary>
        string ServiceName { get; }

        /// <summary>
        /// Lower is initialized first. Mirrors Unity's script execution order but
        /// is enforced by the locator so we do not depend on editor metadata.
        /// </summary>
        int InitOrder { get; }

        /// <summary>Async one-shot setup. Called once after construction.</summary>
        Task InitializeAsync(CancellationToken ct);

        /// <summary>Optional post-init hook after all services are wired up.</summary>
        void OnAllServicesReady();
    }

    /// <summary>Per-frame update hook. Implement only when needed (cache hit cost).</summary>
    public interface ITickable
    {
        void Tick(float deltaTime);
    }

    /// <summary>Fixed-step physics-like hook. Driven by the engine, not Unity's FixedUpdate.</summary>
    public interface IFixedTickable
    {
        void FixedTick(float fixedDeltaTime);
    }

    /// <summary>Late-frame hook for camera, IK, alignment, follow logic.</summary>
    public interface ILateTickable
    {
        void LateTick(float deltaTime);
    }
}
