using System.Diagnostics;
using UnityEngine;

namespace PokemonGo.Core
{
    /// <summary>
    /// Thin logging facade. Strips entirely in non-DEVELOPMENT_BUILD ship builds
    /// via <see cref="ConditionalAttribute"/> so log call sites cost nothing in
    /// release. Adds a uniform prefix and supports category filters.
    /// </summary>
    public static class EngineLog
    {
        public const string Prefix = "<color=#7ec8ff>[PoGoEngine]</color>";

        [Conditional("DEVELOPMENT_BUILD"), Conditional("UNITY_EDITOR")]
        public static void Verbose(string msg)
        {
            if (!EngineRuntime.Settings || !EngineRuntime.Settings.verboseLogging) return;
            UnityEngine.Debug.Log($"{Prefix} {msg}");
        }

        [Conditional("DEVELOPMENT_BUILD"), Conditional("UNITY_EDITOR")]
        public static void Info(string msg) => UnityEngine.Debug.Log($"{Prefix} {msg}");

        public static void Warn(string msg) => UnityEngine.Debug.LogWarning($"{Prefix} {msg}");

        public static void Error(string msg) => UnityEngine.Debug.LogError($"{Prefix} {msg}");
    }
}
