#define NSC_HOST_TEST 1
#include "../Engine/Runtime.m"
#include <stdlib.h>

static _Atomic NSUInteger sounds,callbacks,activeCallbacks,maxCallbacks;
static NSUInteger screenshots,installedFunctions;
static SystemSoundID receivedSound;
static CFDictionaryRef receivedOptions;
static void (^receivedCompletion)(void);
static BOOL fakeRingerOn;
static void (*optionsEntry)(SystemSoundID,CFDictionaryRef,void (^)(void));
static void (*basicEntry)(SystemSoundID);
static void (*completionEntry)(SystemSoundID,void (^)(void));
static void (*alertEntry)(SystemSoundID);
static void (*alertCompletionEntry)(SystemSoundID,void (^)(void));
static void OriginalOptions(SystemSoundID sound,CFDictionaryRef options,void (^completion)(void)) {
    sounds++;receivedSound=sound;receivedOptions=options;receivedCompletion=completion;
    if(completion)dispatch_async(dispatch_get_global_queue(0,0),completion);
}
static void OriginalBasic(SystemSoundID sound) { optionsEntry(sound,NULL,nil); }
static void OriginalCompletion(SystemSoundID sound,void (^completion)(void)) { optionsEntry(sound,NULL,completion); }
static void OriginalAlert(SystemSoundID sound) { optionsEntry(sound,NULL,nil); }
static void OriginalAlertCompletion(SystemSoundID sound,void (^completion)(void)) { optionsEntry(sound,NULL,completion); }
static void *NSCHostSymbol(const char *name) {
    if(!strcmp(name,"AudioServicesPlaySystemSoundWithOptions"))return (void *)OriginalOptions;
    if(!strcmp(name,"AudioServicesPlaySystemSound"))return (void *)OriginalBasic;
    if(!strcmp(name,"AudioServicesPlaySystemSoundWithCompletion"))return (void *)OriginalCompletion;
    if(!strcmp(name,"AudioServicesPlayAlertSound"))return (void *)OriginalAlert;
    if(!strcmp(name,"AudioServicesPlayAlertSoundWithCompletion"))return (void *)OriginalAlertCompletion;
    return NULL;
}
static void MSHookFunction(void *address,void *hook,void **original) {
    *original=address;installedFunctions++;
    if(address==(void *)OriginalOptions)optionsEntry=hook;
    else if(address==(void *)OriginalBasic)basicEntry=hook;
    else if(address==(void *)OriginalCompletion)completionEntry=hook;
    else if(address==(void *)OriginalAlert)alertEntry=hook;
    else if(address==(void *)OriginalAlertCompletion)alertCompletionEntry=hook;
    else abort();
}
@interface NSCHostScreenCapturer:NSObject
+(void)playScreenshotSound;
@end
@implementation NSCHostScreenCapturer
+(void)playScreenshotSound { screenshots++;basicEntry(1108); }
@end
@interface NSCWrongScreen:NSObject
+(double)playScreenshotSound;
@end
@implementation NSCWrongScreen
+(double)playScreenshotSound { return 1; }
@end
static NSUInteger photoGetterCalls,photos,photoSounds;
@interface NSCHostPhotoSettings:NSObject
@property(nonatomic) uint32_t storedSound;
@property(nonatomic) BOOL captureAudio;
-(uint32_t)shutterSound;
-(void)takePhoto;
@end
@implementation NSCHostPhotoSettings
-(uint32_t)shutterSound { photoGetterCalls++;return self.storedSound; }
-(void)takePhoto { photos++;if([self shutterSound])photoSounds++; }
@end
static void Check(BOOL condition,NSString *message) { if(!condition){NSLog(@"FAILED: %@",message);abort();} }
static void Pump(void) { CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.01,YES); }
static void WaitCallbacks(NSUInteger count) { for(int i=0;i<300 && callbacks<count;i++)Pump();Check(callbacks==count,@"every supplied completion delivered exactly once"); }
static void Save(BOOL value) { NSError *e=nil;Check(NSCSaveEnabled(NSCPath(NSCPreferenceFile),value,&e),e.localizedDescription ?: @"preference save"); }
int main(int argc,const char **argv) { @autoreleasepool {
    NSCHostRoot=@(argv[1]);
    optionsEntry=OriginalOptions;basicEntry=OriginalBasic;completionEntry=OriginalCompletion;alertEntry=OriginalAlert;alertCompletionEntry=OriginalAlertCompletion;
    NSCInstall();Check(installedFunctions==5 && NSCOriginalScreenshot!=NULL,@"C functions and signature-checked class hook installed");
    NSCInstall();Check(installedFunctions==5,@"hook installation is idempotent");
    Check(!NSCVoidNoArguments(class_getClassMethod(NSCWrongScreen.class,@selector(playScreenshotSound))),@"wrong private return ABI rejected");
    Check(NSCEnabled(),@"fresh install enabled by default");
    NSCInstallCamera();Check(!NSCOriginalPhotoSound,@"capture class untouched outside Camera process");
    NSCHostCameraProcess=YES;NSCInstallCamera();Check(NSCOriginalPhotoSound!=NULL,@"typed Camera shutter getter hooked");
    NSCInstallCamera();
    Check(!NSCUnsigned32NoArguments(class_getClassMethod(NSCWrongScreen.class,@selector(playScreenshotSound))),@"incompatible camera getter signature rejected");
    NSCHostPhotoSettings *photo=[NSCHostPhotoSettings new];photo.storedSound=1108;photo.captureAudio=YES;
    for(int ring=0;ring<2;ring++) {
        fakeRingerOn=ring;
        basicEntry(1108);alertEntry(1108);[NSCHostScreenCapturer playScreenshotSound];
        [photo takePhoto];
        Check(sounds==0 && screenshots==0,@"camera and screenshot muted in either ringer position");
    }
    Check(photos==2 && photoSounds==0 && photoGetterCalls==2,@"camera still captures and original getter called once while separate sound path suppressed");
    Check(photo.storedSound==1108 && photo.captureAudio,@"stored shutter setting and captured audio unchanged");
    NSDictionary *forced=@{@"IgnoreRingerSwitch":@YES,@"Volume":@1,@"Behavior":@1};
    __block BOOL returned=NO;
    optionsEntry(1108,(__bridge CFDictionaryRef)forced,^{Check(returned,@"muted completion is asynchronous");Check(!NSThread.isMainThread,@"muted callback stays on serial non-UI queue");callbacks++;});
    returned=YES;WaitCallbacks(1);Check(!sounds,@"forced sound options cannot override suppression");
    completionEntry(1108,^{callbacks++;});alertCompletionEntry(1108,^{callbacks++;});WaitCallbacks(3);Check(!sounds,@"all completion routes muted without forwarding");
    for(int i=0;i<50;i++)optionsEntry(1108,NULL,^{NSUInteger current=atomic_fetch_add(&activeCallbacks,1)+1;NSUInteger old=atomic_load(&maxCallbacks);while(current>old && !atomic_compare_exchange_weak(&maxCallbacks,&old,current)){};usleep(1000);atomic_fetch_sub(&activeCallbacks,1);callbacks++;});
    WaitCallbacks(53);Check(maxCallbacks==1,@"suppressed completion callbacks are serialized");
    for(NSNumber *sound in @[@1100,@1007,@1117,@4095,@0])optionsEntry(sound.unsignedIntValue,(__bridge CFDictionaryRef)forced,nil);
    Check(sounds==5 && receivedOptions==(__bridge CFDictionaryRef)forced && receivedSound==0,@"lock, notification, video, vibration and unknown sounds unchanged");
    Save(NO);Check(!NSCEnabled(),@"disable read immediately");
    [photo takePhoto];Check(photoSounds==1 && photos==3 && photoGetterCalls==3,@"same photo settings restore native shutter immediately when disabled");
    basicEntry(1108);completionEntry(1108,^{callbacks++;});alertEntry(1108);alertCompletionEntry(1108,^{callbacks++;});[NSCHostScreenCapturer playScreenshotSound];WaitCallbacks(55);
    Check(sounds==10 && screenshots==1,@"disabled tweak restores all native routes exactly once");
    void (^originalReply)(void)=^{callbacks++;};optionsEntry(1108,(__bridge CFDictionaryRef)forced,originalReply);WaitCallbacks(56);
    Check(sounds==11 && receivedOptions==(__bridge CFDictionaryRef)forced && receivedCompletion==originalReply,@"unmuted options and original callback identity preserved");
    Save(YES);basicEntry(1108);Check(sounds==11,@"reenable effective on next capture without process restart");
    [photo takePhoto];Check(photoSounds==1 && photos==4 && photo.captureAudio && photo.storedSound==1108,@"same capture object muted again without changing audio or settings");
    photo.storedSound=1119;Check([photo shutterSound]==0,@"alternate photo shutter ID suppressed at request getter");
    NSString *path=NSCPath(NSCPreferenceFile);
    NSMutableDictionary *values=[NSCReadSettings(path,nil) mutableCopy];values[@"unrelated"]=@"keep";[values writeToFile:path atomically:YES];Save(NO);
    Check([NSCReadSettings(path,nil)[@"unrelated"] isEqual:@"keep"],@"writes merge unknown preference keys");
    Check([NSFileManager.defaultManager fileExistsAtPath:[path stringByAppendingString:@".before-nocapturesounds"]],@"existing preference backup made");
    NSData *broken=[@"malformed settings" dataUsingEncoding:NSUTF8StringEncoding];[broken writeToFile:path atomically:YES];NSError *error=nil;
    Check(!NSCSaveEnabled(path,YES,&error) && error && [[NSData dataWithContentsOfFile:path] isEqual:broken],@"corrupt preferences preserved");
    basicEntry(1108);Check(sounds==12,@"corrupt preferences conservatively preserve native playback");
    [@{@"enabled":@"invalid"} writeToFile:path atomically:YES];Check(!NSCEnabled(),@"invalid enable type rejected");
    Check([photo shutterSound]==1119,@"invalid preferences restore original Camera getter");
    [@{@"enabled":@YES} writeToFile:path atomically:YES];
    NSUInteger previousSounds=sounds,previousCallbacks=callbacks;
    for(int ring=0;ring<2;ring++) {
        fakeRingerOn=ring;
        for(NSNumber *cue in @[@1119,@1122]) {
            basicEntry(cue.unsignedIntValue);alertEntry(cue.unsignedIntValue);
            completionEntry(cue.unsignedIntValue,^{callbacks++;});
            alertCompletionEntry(cue.unsignedIntValue,^{callbacks++;});
            optionsEntry(cue.unsignedIntValue,(__bridge CFDictionaryRef)forced,^{callbacks++;});
        }
    }
    WaitCallbacks(previousCallbacks+12);Check(sounds==previousSounds,@"Camera opening and finishing cues muted on every installed audio route in either ringer state");
    Save(NO);optionsEntry(1122,(__bridge CFDictionaryRef)forced,nil);Check(sounds==previousSounds+1 && receivedSound==1122,@"disabled Camera finish cue forwarded normally");
    Save(YES);NSCHostCameraProcess=NO;basicEntry(1119);basicEntry(1122);
    Check(sounds==previousSounds+3,@"additional Camera sound IDs are not suppressed in SpringBoard");
    NSCHostCameraProcess=YES;basicEntry(1117);basicEntry(1118);
    Check(sounds==previousSounds+5 && receivedSound==1118,@"video start and stop cues are untouched");
    NSLog(@"PASS: Camera getter, photo opening/finish cues and screenshots in both ringer states, photo capture/audio preserved, reused settings restore on disable, callback preservation and serialization, Camera-only extra IDs, video cues untouched, live enable/disable, signature checks, persistence and malformed-file safety. No real audio APIs invoked.");
    return 0;
} }
