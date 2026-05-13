// iOS-only native side of the ReelRoyale ↔ Unity bridge.
//
// Unity calls C extern functions via DllImport("__Internal"). This file
// implements those externs and forwards their payloads to the host iOS app
// via NSNotificationCenter, so the Swift side never has to know about
// Unity-runtime internals beyond observing notifications it owns.
//
// File extension is .mm so the compiler treats this as Objective-C++; that
// lets us use Foundation classes while still being callable from Unity's
// IL2CPP-generated C++ glue.

#if defined(UNITY_IOS) || defined(__APPLE__)

#import <Foundation/Foundation.h>

extern "C" {

/// Sends a (topic, payload) pair from Unity to the iOS host. The notification
/// is posted on the main queue so SwiftUI observers can mutate @State without
/// dispatch hops.
void ReelRoyale_NativeBridge_PostMessage(const char* topic, const char* payload)
{
    if (topic == NULL) return;
    NSString *t = [NSString stringWithUTF8String:topic];
    NSString *p = payload != NULL
        ? [NSString stringWithUTF8String:payload]
        : @"";

    NSDictionary *userInfo = @{ @"topic": t, @"payload": p };

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"ReelRoyaleUnityBridgeMessage"
                          object:nil
                        userInfo:userInfo];
    });
}

} // extern "C"

#endif
