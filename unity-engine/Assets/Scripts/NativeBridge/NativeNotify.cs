using System.Runtime.InteropServices;
using UnityEngine;

namespace PokemonGo.NativeBridge
{
    /// <summary>
    /// Sends typed notifications from Unity (C#) up to the iOS host (Swift)
    /// via a C extern bridge implemented in <c>iOSNativeBridge.mm</c>.
    /// Falls back to a debug log on non-iOS platforms so callers don't have
    /// to branch on <c>RuntimePlatform</c>.
    /// </summary>
    public static class NativeNotify
    {
#if UNITY_IOS && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void ReelRoyale_NativeBridge_PostMessage(string topic, string payload);
#endif

        public static void PostString(string topic, string payload)
        {
            if (string.IsNullOrEmpty(topic)) return;
            payload ??= string.Empty;

#if UNITY_IOS && !UNITY_EDITOR
            try { ReelRoyale_NativeBridge_PostMessage(topic, payload); }
            catch (System.Exception e) { Debug.LogError($"NativeNotify failed: {e.Message}"); }
#else
            Debug.Log($"[NativeNotify] {topic}: {payload}");
#endif
        }
    }
}
