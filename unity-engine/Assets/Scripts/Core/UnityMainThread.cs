using System;
using System.Collections.Concurrent;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;

namespace PokemonGo.Core
{
    /// <summary>
    /// Lightweight main-thread dispatcher. Worker tasks that need Unity API
    /// access post a delegate via <see cref="Post"/>; the pump drains the
    /// queue during the regular Update loop so dispatch is deterministic
    /// relative to engine ticks. Lives in Core so every assembly can target
    /// it without needing a circular reference back to Streaming.
    /// </summary>
    [DefaultExecutionOrder(-9999)]
    public sealed class UnityMainThread : MonoBehaviour
    {
        private static UnityMainThread s_instance;
        private static readonly ConcurrentQueue<Action> s_queue = new();
        private static int s_mainThreadId;

        public static bool IsMainThread =>
            s_mainThreadId != 0 && Thread.CurrentThread.ManagedThreadId == s_mainThreadId;

        public static void Post(Action action)
        {
            if (action == null) return;
            EnsureInstance();
            s_queue.Enqueue(action);
        }

        public static Task SwitchAsync(CancellationToken ct = default)
        {
            if (IsMainThread) return Task.CompletedTask;
            if (ct.IsCancellationRequested) return Task.FromCanceled(ct);

            var tcs = new TaskCompletionSource<bool>();
            Post(() =>
            {
                if (ct.IsCancellationRequested) tcs.TrySetCanceled(ct);
                else tcs.TrySetResult(true);
            });
            return tcs.Task;
        }

        private static void EnsureInstance()
        {
            if (s_instance != null) return;
            if (!Application.isPlaying)
            {
                // In edit mode, just drop the delegate; pump won't run anyway.
                return;
            }
            var go = new GameObject("[UnityMainThread]");
            s_instance = go.AddComponent<UnityMainThread>();
            DontDestroyOnLoad(go);
        }

        private void Awake()
        {
            s_mainThreadId = Thread.CurrentThread.ManagedThreadId;
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void Bootstrap() => EnsureInstance();

        private void Update()
        {
            while (s_queue.TryDequeue(out var a))
            {
                try { a(); }
                catch (Exception e) { Debug.LogError($"UnityMainThread: {e}"); }
            }
        }
    }
}
