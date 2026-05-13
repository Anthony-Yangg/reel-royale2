using System;
using System.IO;
using PokemonGo.Bootstrap;
using PokemonGo.Core;
using PokemonGo.NativeBridge;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace PokemonGo.Editor
{
    /// <summary>
    /// One-command iOS export pipeline. Produces a Unity-as-a-Library Xcode
    /// project at <c>&lt;repo&gt;/unity-build/ios</c> whose
    /// <c>UnityFramework.framework</c> is what Reel Royale embeds.
    ///
    /// Run from the Editor:
    ///   <c>Build ▸ Reel Royale ▸ Build iOS Framework</c>
    ///
    /// Or headless from the repo root:
    ///   <c>./scripts/build-unity-ios.sh</c>
    ///
    /// The pipeline is idempotent — it creates a default scene, an
    /// EngineSettings asset, and a NativeBridge GameObject if any are missing,
    /// so first-time setup requires zero manual clicks.
    /// </summary>
    public static class iOSBuildPipeline
    {
        private const string RuntimeScenePath = "Assets/Scenes/ReelRoyaleMap.unity";
        private const string SettingsPath     = "Assets/Settings/ReelRoyaleEngine.asset";
        private const string OutputDirRelative = "../unity-build/ios";

        // -----------------------------------------------------------------
        // Public entry points
        // -----------------------------------------------------------------

        [MenuItem("Build/Reel Royale/Build iOS Framework", priority = 100)]
        public static void Build_iOSFromMenu()
        {
            try
            {
                BuildForReelRoyale(development: EditorUserBuildSettings.development);
            }
            catch (Exception e)
            {
                EditorUtility.DisplayDialog(
                    "Reel Royale iOS Build Failed",
                    e.ToString(),
                    "Dismiss");
                throw;
            }
        }

        /// <summary>Static method targeted by the CLI batch build.</summary>
        public static void BuildForReelRoyale()
        {
            // CLI flags: -devBuild forces development.
            bool dev = Array.IndexOf(Environment.GetCommandLineArgs(), "-devBuild") >= 0;
            BuildForReelRoyale(development: dev);
        }

        public static void BuildForReelRoyale(bool development)
        {
            EnsureRuntimeScene();
            ConfigurePlayerSettingsForFrameworkExport();

            string outputAbs = Path.GetFullPath(Path.Combine(Application.dataPath, "..", OutputDirRelative));
            if (Directory.Exists(outputAbs))
            {
                // Clearing forces Unity to emit a clean Xcode project. The
                // alternative (replace) sometimes leaves dead References that
                // confuse downstream xcodebuild.
                Directory.Delete(outputAbs, recursive: true);
            }
            Directory.CreateDirectory(outputAbs);

            var options = new BuildPlayerOptions
            {
                scenes = new[] { RuntimeScenePath },
                locationPathName = outputAbs,
                target = BuildTarget.iOS,
                targetGroup = BuildTargetGroup.iOS,
                options = development
                    ? (BuildOptions.AcceptExternalModificationsToPlayer | BuildOptions.Development)
                    : BuildOptions.AcceptExternalModificationsToPlayer,
            };

            Debug.Log($"[ReelRoyale] Building iOS Unity-as-a-Library Xcode project at: {outputAbs}");
            BuildReport report = BuildPipeline.BuildPlayer(options);

            if (report.summary.result != BuildResult.Succeeded)
            {
                throw new BuildFailedException(
                    $"iOS build failed: {report.summary.result}. " +
                    $"Total errors: {report.summary.totalErrors}.");
            }

            Debug.Log($"[ReelRoyale] iOS framework export complete in {report.summary.totalTime}.");
        }

        // -----------------------------------------------------------------
        // Scene + settings provisioning
        // -----------------------------------------------------------------

        private static void EnsureRuntimeScene()
        {
            EnsureFolder("Assets/Scenes");
            EnsureFolder("Assets/Settings");

            EngineSettings settings = LoadOrCreateEngineSettings();

            if (File.Exists(RuntimeScenePath))
            {
                // Even when the scene exists, re-open & re-save it so any
                // new components we add later land in the build.
                var existing = EditorSceneManager.OpenScene(RuntimeScenePath, OpenSceneMode.Single);
                RepopulateScene(existing, settings);
                EditorSceneManager.SaveScene(existing, RuntimeScenePath);
                return;
            }

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RepopulateScene(scene, settings);
            EditorSceneManager.SaveScene(scene, RuntimeScenePath);
        }

        private static void RepopulateScene(Scene scene, EngineSettings settings)
        {
            // Engine root.
            var rootGo = FindOrCreate(scene, "EngineRoot");
            var bootstrap = rootGo.GetComponent<EngineSceneBootstrap>()
                ?? rootGo.AddComponent<EngineSceneBootstrap>();
            bootstrap.Settings = settings;

            // Native bridge GameObject (must be at scene root, named exactly
            // NativeBridge.GameObjectName so UnityFramework.sendMessageToGO
            // can find it).
            var bridgeGo = GameObject.Find(NativeBridge.GameObjectName);
            if (bridgeGo == null)
            {
                bridgeGo = new GameObject(NativeBridge.GameObjectName);
                SceneManager.MoveGameObjectToScene(bridgeGo, scene);
            }
            if (bridgeGo.GetComponent<NativeBridge>() == null)
            {
                bridgeGo.AddComponent<NativeBridge>();
            }

            // Directional light + camera are spawned by the EngineSceneBootstrap
            // → MapCameraService chain at runtime; nothing else needed here.
        }

        private static GameObject FindOrCreate(Scene scene, string name)
        {
            foreach (var go in scene.GetRootGameObjects())
            {
                if (go.name == name) return go;
            }
            var fresh = new GameObject(name);
            SceneManager.MoveGameObjectToScene(fresh, scene);
            return fresh;
        }

        private static EngineSettings LoadOrCreateEngineSettings()
        {
            var settings = AssetDatabase.LoadAssetAtPath<EngineSettings>(SettingsPath);
            if (settings != null) return settings;

            settings = ScriptableObject.CreateInstance<EngineSettings>();

            // Read MAPBOX_TOKEN from env so we never commit a live token.
            var token = Environment.GetEnvironmentVariable("MAPBOX_TOKEN");
            if (!string.IsNullOrEmpty(token))
            {
                settings.mapboxAccessToken = token;
                settings.useSimulatedGPS = false;
            }

            AssetDatabase.CreateAsset(settings, SettingsPath);
            AssetDatabase.SaveAssets();
            return settings;
        }

        private static void EnsureFolder(string assetPath)
        {
            if (AssetDatabase.IsValidFolder(assetPath)) return;
            var parent = Path.GetDirectoryName(assetPath)?.Replace('\\', '/');
            var leaf = Path.GetFileName(assetPath);
            if (string.IsNullOrEmpty(parent) || string.IsNullOrEmpty(leaf)) return;
            if (!AssetDatabase.IsValidFolder(parent)) EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, leaf);
        }

        // -----------------------------------------------------------------
        // Player settings: configure for Unity-as-a-Library framework export.
        // -----------------------------------------------------------------

        private static void ConfigurePlayerSettingsForFrameworkExport()
        {
            // Bundle identifier for the embedded framework. The Reel Royale
            // host app keeps its own bundle id; this one is only used to
            // sign the Unity framework binary.
            PlayerSettings.SetApplicationIdentifier(
                NamedBuildTarget.iOS, "com.reelroyale.unityframework");
            PlayerSettings.productName = "ReelRoyaleEngine";

            // Target both device & simulator so dev builds can run in the
            // iOS simulator alongside the host SwiftUI app.
            PlayerSettings.iOS.sdkVersion = iOSSdkVersion.DeviceSDK;
            PlayerSettings.iOS.targetOSVersionString = "16.0";

            // IL2CPP + ARM64 only — required for App Store and what UaaL
            // builds anyway.
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.iOS, ScriptingImplementation.IL2CPP);
            PlayerSettings.SetArchitecture(NamedBuildTarget.iOS, (int)iOSArchitecture.ARM64);

            // Location usage description so iOS doesn't kill us when the
            // engine asks for GPS. Pulled from the host app, but Unity ships
            // its own Info.plist for the framework target.
            PlayerSettings.iOS.locationUsageDescription =
                "Reel Royale uses your location to anchor the map and find nearby fishing spots.";

            // Strip what we can — the Reel Royale shell handles UI, audio,
            // etc., so we drop a few defaults to keep the framework lean.
            PlayerSettings.stripEngineCode = true;
            PlayerSettings.SetManagedStrippingLevel(NamedBuildTarget.iOS, ManagedStrippingLevel.Medium);
        }
    }
}
