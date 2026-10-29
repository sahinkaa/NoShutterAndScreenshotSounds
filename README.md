# No Shutter & Screenshot Sounds

Silence camera shutter and screenshot sounds regardless of the ringer switch.

Version 1.0 by sahinkaa.

<img src="artwork/Icon-512.png" width="128" alt="White camera with a red prohibition symbol on black">

[Download version 1.0](https://github.com/sahinkaa/NoShutterAndScreenshotSounds/releases/tag/v1.0)

## Features

- Mutes photo shutter and screenshot sounds in either ringer-switch position.
- Handles the separate opening and closing sounds used during Night mode exposures.
- One Enabled switch restores normal playback when turned off.
- Settings apply immediately without a respring after initial installation.
- Uses the same camera prohibition icon in the Settings list and above the Enabled switch.

The tweak runs in Apple's Camera and SpringBoard. It does not change microphone configuration, recorded audio or stored photo settings. Video start and stop cues remain unchanged. Third-party camera apps and AirPods capture cues are outside the confirmed scope.

## Compatibility

| Setup | Status |
| --- | --- |
| iPhone 11 Pro Max, iOS 26.0.1 (23A355), Dopamine 3 RootHide | Sound behavior verified by the user |
| Standard rootless on iOS 16 | Verified by the user |
| Other devices or iOS versions | Unverified |

Targets **iOS 15-26** on standard rootless and native RootHide jailbreaks. Device testing is confirmed on iOS 16 and iOS 26. iOS 15 and the other versions in this range have not been individually device-tested.

## Install

Choose the package matching your jailbreak:

- Native RootHide: `com.sahinkaa.noshutterscreenshotsounds_1.0_iphoneos-arm64e.deb`. Install directly without RootHide Patcher.
- Standard rootless: `com.sahinkaa.noshutterscreenshotsounds_1.0_iphoneos-arm64.deb`.

Open the package in Sileo and install it with its dependencies. Fully close Camera and Settings then respring once. Reopen Settings and find **No Shutter & Screenshot Sounds**. Enabled is on by default. Later changes apply to the next capture without a respring.

The package identifier stays `com.sahinkaa.noshutterscreenshotsounds`, so installing 1.0 upgrades an earlier build. The GitHub repository is `NoShutterAndScreenshotSounds`. Package filenames retain the `com.sahinkaa` prefix.

## Remove

Turn Enabled off to restore normal playback immediately. To remove the tweak completely, uninstall it in Sileo then respring and reopen Camera. It replaces no Apple files and installs no daemon. Preferences remain after removal.

## Diagnostics

If a sound still plays, share the action, ringer position and these files from `/var/mobile/Library/Logs`:

- `NoCaptureSounds-com.apple.camera.plist`
- `NoCaptureSounds-com.apple.springboard.plist`

On RootHide, use the corresponding directory inside the current `.jbroot`. On standard rootless, use the normal `/var/mobile/Library/Logs` folder without a `/var/jb` prefix. Logs contain hook status and suppression markers without photos, recordings or photo metadata.

Settings use `com.sahinkaa.noshutterscreenshotsounds.plist` under the same environment's `/var/mobile/Library/Preferences`. Saves preserve other keys, use atomic writes and keep a backup before changing an existing file. Malformed settings are preserved and normal playback is allowed.

See [BUILD.md](BUILD.md) for compilation, [TESTING.md](TESTING.md) for a device verification checklist and [RESEARCH.md](RESEARCH.md) for implementation details.
