// Obj-C C-API the Swift side calls to drive UnityFramework. We keep all
// direct UnityFramework symbol references behind this wall so the Swift
// side never imports UnityFramework headers and the project compiles even
// when UnityFramework.framework has not been built yet (e.g. fresh clone
// before someone runs ./scripts/build-unity-ios.sh).
//
// Notifications posted by UnityFramework -> iOS (via NSNotificationCenter):
//   "ReelRoyaleUnityBridgeMessage"  userInfo: {"topic": String, "payload": String}
//   (posted by the Unity-side iOSNativeBridge.mm on the main queue.)

#ifndef REEL_UNITY_BRIDGE_C_H
#define REEL_UNITY_BRIDGE_C_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// Returns YES iff UnityFramework.framework is present in the running app's
/// /Frameworks directory AND its principal class loads cleanly. Cheap to
/// call repeatedly — the lookup is cached.
BOOL ReelUnityIsAvailable(void);

/// Starts UnityFramework if it's available and not yet running. Idempotent;
/// Unity can only be instantiated once per process for the entire process
/// lifetime, so subsequent calls are no-ops.
///
/// `appLaunchOptions` should be the launch options dictionary the host app
/// received in didFinishLaunchingWithOptions, or nil for runs outside the
/// normal launch lifecycle (e.g. SwiftUI scene-based apps).
///
/// Returns YES if Unity is now running, NO otherwise.
BOOL ReelUnityStart(NSDictionary * _Nullable appLaunchOptions);

/// Stops Unity (unloads the runtime). Use at app shutdown only; once
/// unloaded Unity cannot be restarted in the same process.
void ReelUnityShutdown(void);

/// Returns Unity's root UIView once Unity has started, otherwise nil.
/// Caller should add this as a subview of a SwiftUI host view.
UIView * _Nullable ReelUnityRootView(void);

/// Pauses/resumes the Unity main loop. Useful when the map screen is
/// off-screen — Unity at 60 FPS otherwise burns battery.
void ReelUnitySetPaused(BOOL paused);

/// Sends a message to a Unity GameObject (UnityFramework.sendMessageToGO).
/// `goName` is the GameObject name, `method` the public C# method, and
/// `arg` the single string argument (typically JSON).
void ReelUnitySendMessage(NSString *goName, NSString *method, NSString *arg);

#ifdef __cplusplus
} // extern "C"
#endif

NS_ASSUME_NONNULL_END

#endif // REEL_UNITY_BRIDGE_C_H
