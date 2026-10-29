#pragma once
#import <Foundation/Foundation.h>

#if defined(NSC_HOST_TEST)
// The host fixture supplies an isolated filesystem root.
static inline NSString *NSCPath(NSString *path) { return jbroot(path); }
#elif defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#import <roothide.h>
static inline NSString *NSCPath(NSString *path) { return jbroot(path); }
#elif defined(THEOS_PACKAGE_SCHEME_ROOTLESS)
// Only preferences and logs use this helper. Standard rootless shares the
// system's /var/mobile; its /var/jb prefix is for installed jailbreak files.
static inline NSString *NSCPath(NSString *path) { return path; }
#else
#error Choose the rootless or roothide package scheme.
#endif
