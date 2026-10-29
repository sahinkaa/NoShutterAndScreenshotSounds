# Implementation notes

The implementation was inspected against locally available Xcode DeviceSupport symbols for iPhone12,5, iOS 26.0.1 (23A355). No Apple framework binary or sound file is redistributed.

## Screenshot and audio hooks

`+[SSScreenCapturer playScreenshotSound]` requests sound ID 1108. The dedicated screenshot sound method is hooked only if its runtime signature has a void return and the expected argument count. Taking and saving screenshots remain native.

Five AudioServices playback functions are resolved by symbol name and hooked with their respective typed prototypes: `AudioServicesPlaySystemSoundWithOptions`, `AudioServicesPlaySystemSound`, `AudioServicesPlaySystemSoundWithCompletion`, `AudioServicesPlayAlertSound` and `AudioServicesPlayAlertSoundWithCompletion`. The options function takes a SystemSoundID, a CFDictionaryRef and a completion block with a void return.

ID 1108 is suppressed in Camera and SpringBoard. Photo opening and finish IDs 1119 and 1122 are suppressed in Camera only. Other sound IDs retain native playback. Suppressed completion blocks are delivered asynchronously exactly once on a dedicated serial queue. No capture callback or capture-state handler is skipped.

## Camera hook

`-[AVCapturePhotoSettings shutterSound]` is hooked in Camera only after verifying its `I16@0:8` signature. The hook calls the original getter once then returns the native no-sound value 0 while enabled. The native will-capture path skips sound playback for that value. Stored photo settings and audio flags are untouched, so disabling restores the original sound even for a reused settings object.

The separate still-image-complete handler can pass ID 1122 directly to shutter playback when digitalFlashMode is nonzero. This finish path bypasses the photo-settings getter. The corresponding sanitized settings use opening ID 1119. Suppressing those cues covers the Night mode opening and closing sounds verified by the user.

## Settings and lifecycle

The settings page uses PSViewController with a native UITableView. PreferenceLoader registers it with `isController = true`. The header icon is loaded from the preference bundle. No legacy PSListController offsets are used.

Preference changes use merged atomic writes with a backup, file locking and readback. Invalid files are preserved and native playback is allowed. Both injected processes and Settings read the same preference file for the next capture, so changes do not require a respring after initial installation.

Rootless preferences and logs use normal /var/mobile directories. Installed rootless payload files use /var/jb. RootHide paths use native jbroot conversion.

The class hooks retry outside dyld's loader lock after image loading. Missing symbols or incompatible signatures are recorded and left alone. No hard-coded executable address, raw assembly patch or manual stack rewriting is used.

## Compatibility evidence

Targets iOS 15-26. The user verified standard rootless on iOS 16 and native Dopamine 3 RootHide on iPhone 11 Pro Max, iOS 26.0.1. iOS 15 and other versions in the range have not been individually device-tested. Runtime checks are a fallback rather than evidence that every capture mode on every version is covered. Third-party camera apps and AirPods capture cues are outside the confirmed scope.

See BUILD.md for the host checks, compiler target and package validation.
