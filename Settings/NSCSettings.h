#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSString *const NSCPreferenceFile;
FOUNDATION_EXPORT NSDictionary *NSCReadSettings(NSString *path, NSError **error);
FOUNDATION_EXPORT BOOL NSCSaveEnabled(NSString *path, BOOL enabled, NSError **error);
FOUNDATION_EXPORT BOOL NSCEnabledAtPath(NSString *path);
