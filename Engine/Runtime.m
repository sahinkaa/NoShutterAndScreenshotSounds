#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#include <string.h>
#ifdef NSC_HOST_TEST
#import "HostRuntime.h"
#else
#import <AudioToolbox/AudioToolbox.h>
#import <substrate.h>
#import <mach-o/dyld.h>
#include <dlfcn.h>
#endif
#import "../NSCPaths.h"
#import "../Settings/NSCSettings.h"

#ifndef NSC_SCREEN_CLASS
#define NSC_SCREEN_CLASS @"SSScreenCapturer"
#endif
#ifndef NSC_PHOTO_SETTINGS_CLASS
#define NSC_PHOTO_SETTINGS_CLASS @"AVCapturePhotoSettings"
#endif

// iOS 26's SSScreenCapturer explicitly requests 1108. The native camera path
// reaches the same sound service with options that can ignore the ringer switch.
static const SystemSoundID NSCShutterSound = 1108;
static void (*NSCOriginalOptions)(SystemSoundID,CFDictionaryRef,void (^)(void));
static void (*NSCOriginalBasic)(SystemSoundID);
static void (*NSCOriginalCompletion)(SystemSoundID,void (^)(void));
static void (*NSCOriginalAlert)(SystemSoundID);
static void (*NSCOriginalAlertCompletion)(SystemSoundID,void (^)(void));
static void (*NSCOriginalScreenshot)(id,SEL);
static uint32_t (*NSCOriginalPhotoSound)(id,SEL);
static NSMutableDictionary *NSCReport;

static void NSCRecord(NSString *key,id value) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{NSCRecord(key,value);});return; }
    if (!NSCReport) NSCReport=[NSMutableDictionary new];
    NSCReport[key]=value;NSCReport[@"build"]=@"1.0";
    NSString *bundle=NSBundle.mainBundle.bundleIdentifier ?: NSProcessInfo.processInfo.processName;
    NSCReport[@"process"]=bundle;
    NSString *dir=NSCPath(@"/var/mobile/Library/Logs");
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [NSCReport writeToFile:[dir stringByAppendingPathComponent:[NSString stringWithFormat:@"NoCaptureSounds-%@.plist",bundle]] atomically:YES];
}
static BOOL NSCEnabled(void) { return NSCEnabledAtPath(NSCPath(NSCPreferenceFile)); }
static BOOL NSCIsCameraProcess(void) {
#ifdef NSC_HOST_TEST
    return NSCHostCameraProcess;
#else
    return [NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.camera"];
#endif
}
static BOOL NSCMute(SystemSoundID sound) {
    // Digital-flash/long-exposure stills use 1119 at the start and an explicit
    // 1122 finish cue. That finish path does not read photoSettings.shutterSound.
    // Keep those additional photo sounds scoped to Camera, not SpringBoard.
    unsigned bit;
    if(sound==NSCShutterSound) bit=1;
    else if((sound==1119 || sound==1122) && NSCIsCameraProcess()) bit=sound==1119 ? 2 : 4;
    else return NO;
    if(!NSCEnabled()) return NO;
    static atomic_uint recorded=0;
    if(!(atomic_fetch_or(&recorded,bit)&bit)) NSCRecord([NSString stringWithFormat:@"sound%u.suppressed",(unsigned)sound],@YES);
    return YES;
}
static void NSCComplete(void (^completion)(void)) {
    if (!completion) return;
    // Apple's public AudioServices contract specifies callbacks on a serial
    // queue for every play attempt, including failures. Never drop the callback
    // or invoke it inline while skipping playback.
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once,^{queue=dispatch_queue_create("com.sahinkaa.nocapturesounds.completion",DISPATCH_QUEUE_SERIAL);});
    dispatch_async(queue,[completion copy]);
}
static void NSCOptions(SystemSoundID sound,CFDictionaryRef options,void (^completion)(void)) {
    if(NSCMute(sound)) { NSCComplete(completion);return; }
    NSCOriginalOptions(sound,options,completion);
}
static void NSCBasic(SystemSoundID sound) {
    if(!NSCMute(sound)) NSCOriginalBasic(sound);
}
static void NSCWithCompletion(SystemSoundID sound,void (^completion)(void)) {
    if(NSCMute(sound)) { NSCComplete(completion);return; }
    NSCOriginalCompletion(sound,completion);
}
static void NSCAlert(SystemSoundID sound) {
    if(!NSCMute(sound)) NSCOriginalAlert(sound);
}
static void NSCAlertWithCompletion(SystemSoundID sound,void (^completion)(void)) {
    if(NSCMute(sound)) { NSCComplete(completion);return; }
    NSCOriginalAlertCompletion(sound,completion);
}
static void NSCScreenshot(id owner,SEL command) {
    if(NSCEnabled()) { NSCRecord(@"screenshot.suppressed",@YES);return; }
    NSCOriginalScreenshot(owner,command);
}
static BOOL NSCVoidNoArguments(Method method) {
    if(!method || method_getNumberOfArguments(method)!=2) return NO;
    char *type=method_copyReturnType(method);BOOL matches=type && !strcmp(type,"v");free(type);
    return matches;
}
static BOOL NSCUnsigned32NoArguments(Method method) {
    if(!method || method_getNumberOfArguments(method)!=2) return NO;
    char *type=method_copyReturnType(method);BOOL matches=type && !strcmp(type,"I");free(type);
    return matches;
}
static uint32_t NSCPhotoSound(id owner,SEL command) {
    uint32_t sound=NSCOriginalPhotoSound(owner,command);
    if(!NSCEnabled()) return sound;
    static atomic_bool recorded=false;
    if(!atomic_exchange(&recorded,true)) NSCRecord(@"camera.shutterSound.suppressed",@YES);
    // The native will-capture callback skips playback when shutterSound is 0.
    // Change only the read value. Do not mutate reusable photo settings, audio
    // capture flags, Live Photo audio or the microphone configuration.
    return 0;
}
static void NSCInstallCamera(void) {
    if(!NSCIsCameraProcess() || NSCOriginalPhotoSound) return;
    Class cls=NSClassFromString(NSC_PHOTO_SETTINGS_CLASS);
    if(!cls) { NSCRecord(@"hook.camera",@"waiting for AVCapturePhotoSettings");return; }
    SEL selector=NSSelectorFromString(@"shutterSound");
    Method method=class_getInstanceMethod(cls,selector);
    if(method) NSCRecord(@"camera.shutterSound.abi",@(method_getTypeEncoding(method)));
    if(!NSCUnsigned32NoArguments(method)) {
        NSCRecord(@"hook.camera",method ? @"unsupported signature" : @"missing method");return;
    }
    MSHookMessageEx(cls,selector,(IMP)NSCPhotoSound,(IMP *)&NSCOriginalPhotoSound);
    NSCRecord(@"hook.camera",NSCOriginalPhotoSound ? @"installed" : @"failed");
}
static void NSCInstallScreenshot(void) {
    if(NSCOriginalScreenshot) return;
    Class cls=NSClassFromString(NSC_SCREEN_CLASS);
    if(!cls) return;
    Class meta=object_getClass(cls);
    SEL selector=NSSelectorFromString(@"playScreenshotSound");
    Method method=class_getInstanceMethod(meta,selector);
    if(!NSCVoidNoArguments(method)) { NSCRecord(@"hook.screenshot",method ? @"unsupported signature" : @"missing method");return; }
    MSHookMessageEx(meta,selector,(IMP)NSCScreenshot,(IMP *)&NSCOriginalScreenshot);
    NSCRecord(@"hook.screenshot",NSCOriginalScreenshot ? @"installed" : @"failed");
}
static void NSCInstallFunction(const char *name,void *hook,void **original) {
    if(*original) return;
#ifdef NSC_HOST_TEST
    void *address=NSCHostSymbol(name);
#else
    void *address=dlsym(RTLD_DEFAULT,name);
#endif
    if(!address) {NSCRecord([@"hook." stringByAppendingString:@(name)],@"missing symbol");return;}
    MSHookFunction(address,hook,original);
    NSCRecord([@"hook." stringByAppendingString:@(name)],*original ? @"installed" : @"failed");
}
static void NSCInstall(void) {
    NSCInstallFunction("AudioServicesPlaySystemSoundWithOptions",(void *)NSCOptions,(void **)&NSCOriginalOptions);
    NSCInstallFunction("AudioServicesPlaySystemSound",(void *)NSCBasic,(void **)&NSCOriginalBasic);
    NSCInstallFunction("AudioServicesPlaySystemSoundWithCompletion",(void *)NSCWithCompletion,(void **)&NSCOriginalCompletion);
    NSCInstallFunction("AudioServicesPlayAlertSound",(void *)NSCAlert,(void **)&NSCOriginalAlert);
    NSCInstallFunction("AudioServicesPlayAlertSoundWithCompletion",(void *)NSCAlertWithCompletion,(void **)&NSCOriginalAlertCompletion);
    NSCInstallScreenshot();
    NSCInstallCamera();
}
#ifndef NSC_HOST_TEST
static void NSCImageLoaded(const struct mach_header *header,intptr_t slide) {
    static atomic_bool queued=false;
    if(atomic_exchange(&queued,true)) return;
    // Do not perform Objective-C work under dyld's loader lock.
    dispatch_async(dispatch_get_main_queue(),^{atomic_store(&queued,false);NSCInstallScreenshot();NSCInstallCamera();});
}
__attribute__((constructor)) static void NSCInitialize(void) {
    @autoreleasepool {
        NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
        if(![@[@"com.apple.springboard",@"com.apple.camera"] containsObject:bundle]) return;
        NSCInstall();
        NSCRecord(@"loaded",@YES);
        _dyld_register_func_for_add_image(NSCImageLoaded);
    }
}
#endif
