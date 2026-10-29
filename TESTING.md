# Verification checklist

Use `com.sahinkaa.noshutterscreenshotsounds_1.0_iphoneos-arm64.deb` directly on the standard rootless jailbreak. The arm64e package is for native RootHide.

Record the phone model, exact iOS version and jailbreak name/version with the results below. An iOS 15 build target and runtime method checks make an iOS 16 test reasonable but do not prove compatibility.

1. Install through Sileo, close Camera and Settings then respring once.
2. Open the Settings page. Check that its icon appears above the Enabled switch.
3. With Enabled on, take screenshots and regular photos with Night mode and Live Photos off. Repeat with the ringer switch on and off. Confirm the photos and screenshots are saved.
4. If the phone supports Night mode, test a long exposure in each ringer position. Check both its opening and closing sounds.
5. Turn Enabled off without respringing. Compare the same captures with normal playback. Return to the settings page to check that the switch value persists.
6. Re-enable without respringing and confirm suppression returns.
7. Check Live Photos and a short video. Confirm video audio is still recorded. Video start and stop sounds should retain native behavior.

If a sound still plays or a hook is unavailable, share the Camera and SpringBoard logs from `/var/mobile/Library/Logs`. If the Settings page fails to save, include the displayed error. Do not use `/var/jb/var/mobile` for standard rootless data.

To roll back, disable the tweak or uninstall it through Sileo then respring and reopen Camera.

Device results: the user verified standard rootless on iOS 16 and native Dopamine 3 RootHide on iPhone 11 Pro Max running iOS 26.0.1. iOS 15 and the other versions in the target range have not been individually tested.
