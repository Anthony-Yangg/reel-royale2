// Implementation of the C-API in UnityBridgeC.h.
//
// We deliberately avoid #importing <UnityFramework/UnityFramework.h> directly
// because the framework may not be present at build time. Instead we use
// NSBundle dynamic loading + objc_msgSend so the app links cleanly with or
// without the framework.

#import "UnityBridgeC.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

// Forward-declare the few selectors we call on the UnityFramework principal
// class. We type-cast objc_msgSend per call site so the compiler emits the
// correct ABI for each return/argument shape.

static Class _ufwClass = Nil;          // UnityFramework principal class
static id    _ufwInstance = nil;        // UnityFramework singleton
static BOOL  _started = NO;
static BOOL  _availabilityChecked = NO;
static BOOL  _availabilityCached = NO;

#pragma mark - Availability

static Class UnityFrameworkClassIfPresent(void) {
    if (_ufwClass != Nil) return _ufwClass;

    NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath]
        stringByAppendingPathComponent:@"UnityFramework.framework"];
    NSBundle *bundle = [NSBundle bundleWithPath:frameworkPath];
    if (bundle == nil) return Nil;
    if (!bundle.isLoaded) {
        NSError *err = nil;
        if (![bundle loadAndReturnError:&err]) {
            NSLog(@"[ReelUnity] Failed to load UnityFramework.framework: %@", err);
            return Nil;
        }
    }
    _ufwClass = [bundle principalClass];
    return _ufwClass;
}

BOOL ReelUnityIsAvailable(void) {
    if (_availabilityChecked) return _availabilityCached;
    _availabilityChecked = YES;
    Class c = UnityFrameworkClassIfPresent();
    _availabilityCached = (c != Nil);
    if (!_availabilityCached) {
        NSLog(@"[ReelUnity] UnityFramework.framework not present — falling "
              @"back to native map. Build it with ./scripts/build-unity-ios.sh");
    }
    return _availabilityCached;
}

#pragma mark - Lifecycle

static id UnityInstance(void) {
    if (_ufwInstance != nil) return _ufwInstance;
    Class c = UnityFrameworkClassIfPresent();
    if (c == Nil) return nil;
    SEL sel = NSSelectorFromString(@"getInstance");
    if (![c respondsToSelector:sel]) {
        NSLog(@"[ReelUnity] UnityFramework principal class lacks +getInstance.");
        return nil;
    }
    id (*getInstance)(Class, SEL) = (id (*)(Class, SEL))objc_msgSend;
    _ufwInstance = getInstance(c, sel);
    return _ufwInstance;
}

BOOL ReelUnityStart(NSDictionary *appLaunchOptions) {
    if (_started) return YES;
    id ufw = UnityInstance();
    if (ufw == nil) return NO;

    // [ufw setExecuteHeader:&_mh_execute_header];
    // _mh_execute_header is the Mach-O header of THIS executable, which
    // Unity needs in order to dlsym its own internal symbols.
    SEL setHeader = NSSelectorFromString(@"setExecuteHeader:");
    if ([ufw respondsToSelector:setHeader]) {
        const struct mach_header *header = _dyld_get_image_header(0);
        void (*invoke)(id, SEL, const void *) =
            (void (*)(id, SEL, const void *))objc_msgSend;
        invoke(ufw, setHeader, header);
    }

    // [ufw runEmbeddedWithArgc:0 argv:NULL appLaunchOpts:appLaunchOptions];
    SEL runSel = NSSelectorFromString(@"runEmbeddedWithArgc:argv:appLaunchOpts:");
    if (![ufw respondsToSelector:runSel]) {
        NSLog(@"[ReelUnity] UnityFramework missing runEmbeddedWithArgc:argv:appLaunchOpts:");
        return NO;
    }
    void (*run)(id, SEL, int, char **, NSDictionary *) =
        (void (*)(id, SEL, int, char **, NSDictionary *))objc_msgSend;
    run(ufw, runSel, 0, NULL, appLaunchOptions ?: @{});

    _started = YES;
    NSLog(@"[ReelUnity] UnityFramework runEmbedded launched.");
    return YES;
}

void ReelUnityShutdown(void) {
    if (!_started) return;
    id ufw = UnityInstance();
    SEL sel = NSSelectorFromString(@"unloadApplication");
    if (ufw != nil && [ufw respondsToSelector:sel]) {
        ((void (*)(id, SEL))objc_msgSend)(ufw, sel);
    }
    _started = NO;
    _ufwInstance = nil;
}

void ReelUnitySetPaused(BOOL paused) {
    if (!_started) return;
    id ufw = UnityInstance();
    SEL sel = NSSelectorFromString(@"pause:");
    if (ufw != nil && [ufw respondsToSelector:sel]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(ufw, sel, paused);
    }
}

#pragma mark - Root view

UIView * ReelUnityRootView(void) {
    if (!_started) return nil;
    id ufw = UnityInstance();
    if (ufw == nil) return nil;

    // [ufw appController]      → UnityAppController
    // [.appController rootView]
    SEL appControllerSel = NSSelectorFromString(@"appController");
    if (![ufw respondsToSelector:appControllerSel]) return nil;
    id appController =
        ((id (*)(id, SEL))objc_msgSend)(ufw, appControllerSel);
    if (appController == nil) return nil;

    SEL rootViewSel = NSSelectorFromString(@"rootView");
    if (![appController respondsToSelector:rootViewSel]) return nil;
    UIView *root =
        ((UIView * (*)(id, SEL))objc_msgSend)(appController, rootViewSel);
    return root;
}

#pragma mark - Messaging

void ReelUnitySendMessage(NSString *goName, NSString *method, NSString *arg) {
    if (!_started || goName == nil || method == nil) return;
    id ufw = UnityInstance();
    if (ufw == nil) return;
    SEL sel = NSSelectorFromString(@"sendMessageToGOWithName:functionName:message:");
    if (![ufw respondsToSelector:sel]) return;
    ((void (*)(id, SEL, const char *, const char *, const char *))objc_msgSend)(
        ufw, sel,
        [goName UTF8String],
        [method UTF8String],
        [(arg ?: @"") UTF8String]);
}
