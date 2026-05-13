using System;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;

namespace PokemonGo.Core
{
    /// <summary>
    /// MonoBehaviour driver that owns the engine's main loop, the cancellation
    /// token shared by all async services, and the static read-only references
    /// (Settings, Locator) that other systems consume.
    ///
    /// This is the *only* MonoBehaviour at the root of the engine. Everything
    /// else hangs off services or pooled GameObjects.
    /// </summary>
    [DefaultExecutionOrder(-10000)]
    [DisallowMultipleComponent]
    public sealed class EngineRuntime : MonoBehaviour
    {
        public static EngineRuntime Active { get; private set; }
        public static EngineSettings Settings { get; private set; }
        public static ServiceLocator Locator => ServiceLocator.Instance;
        public static CancellationToken AppQuitToken => Active != null
            ? Active._cts.Token : CancellationToken.None;

        [SerializeField] private EngineSettings _settings;
        [SerializeField] private bool _autoBootstrap = true;

        private CancellationTokenSource _cts;
        private float _fixedAccum;
        private const float FixedDelta = 1f / 50f;
        private Action<EngineBootContext> _bootCallback;
        private bool _bootCompleted;

        public bool IsBooted => _bootCompleted;

        public event Action BootCompleted;

        /// <summary>
        /// Globally-registered service composer. The Bootstrap assembly sets
        /// this to its <c>EngineBootstrap.RegisterServices</c> method during
        /// <see cref="RuntimeInitializeOnLoadMethodAttribute"/>. We keep this
        /// indirection so the Core assembly does not have to reference every
        /// subsystem assembly — avoiding circular dependencies.
        /// </summary>
        public static Action<EngineBootContext> ServiceRegistrar { get; set; }

        private void Awake()
        {
            if (Active != null)
            {
                EngineLog.Warn("Duplicate EngineRuntime detected; destroying.");
                Destroy(this);
                return;
            }

            Active = this;
            Settings = _settings;
            _cts = new CancellationTokenSource();

            if (_settings == null)
            {
                EngineLog.Error("EngineRuntime has no EngineSettings assigned. " +
                    "Create one via Assets > Create > PokemonGo > Engine Settings.");
                enabled = false;
                return;
            }

            Application.targetFrameRate = _settings.targetFrameRate;
            QualitySettings.vSyncCount = 0;
            DontDestroyOnLoad(gameObject);
        }

        private async void Start()
        {
            if (!enabled || !_autoBootstrap) return;
            await BootAsync();
        }

        public async Task BootAsync()
        {
            try
            {
                var ctx = new EngineBootContext(_settings, gameObject);
                if (ServiceRegistrar == null)
                {
                    EngineLog.Error("No ServiceRegistrar set. The Bootstrap " +
                        "assembly must call EngineRuntime.ServiceRegistrar = " +
                        "EngineBootstrap.RegisterServices during init.");
                    return;
                }
                ServiceRegistrar(ctx);
                _bootCallback?.Invoke(ctx);
                await Locator.InitializeAllAsync(_cts.Token).ConfigureAwait(true);
                _bootCompleted = true;
                BootCompleted?.Invoke();
                EngineLog.Info("Engine boot complete.");
            }
            catch (OperationCanceledException)
            {
                EngineLog.Warn("Engine boot cancelled.");
            }
            catch (Exception e)
            {
                EngineLog.Error($"Engine boot failed: {e}");
            }
        }

        /// <summary>Inject additional services before boot.</summary>
        public void AddBootHook(Action<EngineBootContext> callback) => _bootCallback += callback;

        private void Update()
        {
            if (!_bootCompleted) return;
            float dt = Time.deltaTime;

            // Fixed-step pass driven from main update to avoid Unity's FixedUpdate
            // jitter when frame times are irregular (mobile thermals).
            _fixedAccum += dt;
            int safetyIter = 0;
            while (_fixedAccum >= FixedDelta && safetyIter++ < 4)
            {
                Locator.FixedTick(FixedDelta);
                _fixedAccum -= FixedDelta;
            }

            Locator.Tick(dt);
        }

        private void LateUpdate()
        {
            if (!_bootCompleted) return;
            Locator.LateTick(Time.deltaTime);
        }

        private void OnDestroy()
        {
            if (Active != this) return;

            try { _cts?.Cancel(); }
            catch { /* shutdown best-effort */ }
            Locator.Dispose();
            _cts?.Dispose();
            Active = null;
            Settings = null;
        }
    }

    /// <summary>Hand-off bag used during the bootstrap phase only.</summary>
    public sealed class EngineBootContext
    {
        public EngineSettings Settings { get; }
        public GameObject Root { get; }
        public EngineBootContext(EngineSettings s, GameObject root)
        {
            Settings = s; Root = root;
        }
    }
}
