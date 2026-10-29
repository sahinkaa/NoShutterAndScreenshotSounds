#import "NSCSettings.h"
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

NSString *const NSCPreferenceFile = @"/var/mobile/Library/Preferences/com.sahinkaa.noshutterscreenshotsounds.plist";
NSDictionary *NSCReadSettings(NSString *path, NSError **error) {
    if (error) *error = nil;
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) return @{};
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) return nil;
    id value = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:error];
    if (![value isKindOfClass:NSDictionary.class]) {
        if (error && !*error) *error = [NSError errorWithDomain:@"NoCaptureSounds.Settings" code:1 userInfo:@{NSLocalizedDescriptionKey:@"The existing settings could not be read. They have not been replaced."}];
        return nil;
    }
    return value;
}
BOOL NSCEnabledAtPath(NSString *path) {
    NSDictionary *settings = NSCReadSettings(path,nil);
    if (!settings) return NO; // Invalid data leaves the native sound behavior alone.
    id value = settings[@"enabled"];
    return !value || ([value isKindOfClass:NSNumber.class] && [value boolValue]);
}
BOOL NSCSaveEnabled(NSString *path, BOOL enabled, NSError **error) {
    if (error) *error = nil;
    NSFileManager *manager = NSFileManager.defaultManager;
    if (![manager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    int fd = open([path stringByAppendingString:@".lock"].fileSystemRepresentation,O_CREAT|O_RDWR|O_CLOEXEC,0600);
    if (fd < 0) { if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; return NO; }
    if (flock(fd,LOCK_EX)) { int code=errno;close(fd);if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];return NO; }
    @try {
        NSDictionary *old = NSCReadSettings(path,error);
        if (!old) return NO;
        NSMutableDictionary *updated = [old mutableCopy]; updated[@"enabled"] = @(enabled);
        if ([old isEqual:updated]) return YES;
        NSString *backup = [path stringByAppendingString:@".before-nocapturesounds"];
        if ([manager fileExistsAtPath:path] && ![manager fileExistsAtPath:backup] && ![manager copyItemAtPath:path toPath:backup error:error]) return NO;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:updated format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
        if (!data || ![data writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
        return [NSCReadSettings(path,error) isEqual:updated];
    } @finally { flock(fd,LOCK_UN);close(fd); }
}
