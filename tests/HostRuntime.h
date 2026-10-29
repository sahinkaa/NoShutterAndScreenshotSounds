#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
typedef uint32_t SystemSoundID;
#define NSC_SCREEN_CLASS @"NSCHostScreenCapturer"
#define NSC_PHOTO_SETTINGS_CLASS @"NSCHostPhotoSettings"
static BOOL NSCHostCameraProcess;
static NSString *NSCHostRoot;
static NSString *jbroot(NSString *path) { return [NSCHostRoot stringByAppendingPathComponent:path]; }
static void *NSCHostSymbol(const char *name);
static void MSHookFunction(void *address,void *hook,void **original);
static void MSHookMessageEx(Class cls,SEL selector,IMP hook,IMP *original) {
    Method method=class_getInstanceMethod(cls,selector);
    *original=method_setImplementation(method,hook);
}
