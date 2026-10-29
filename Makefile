THEOS_PACKAGE_SCHEME ?= roothide
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
ARCHS = arm64e
NSC_PATH_LIBRARY = roothide
else ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
ARCHS = arm64 arm64e
NSC_PATH_LIBRARY =
else
$(error Choose THEOS_PACKAGE_SCHEME=rootless or THEOS_PACKAGE_SCHEME=roothide)
endif
TARGET = iphone:clang:latest:15.0
FINALPACKAGE = 1
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NoCaptureSounds
NoCaptureSounds_FILES = Engine/Runtime.m Settings/NSCSettings.m
NoCaptureSounds_CFLAGS = -fobjc-arc -fstack-protector-strong -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations
NoCaptureSounds_FRAMEWORKS = Foundation CoreFoundation AudioToolbox
NoCaptureSounds_LIBRARIES = $(NSC_PATH_LIBRARY)
include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = NoCaptureSoundsPrefs
NoCaptureSoundsPrefs_FILES = Settings/NSCController.m Settings/NSCSettings.m
NoCaptureSoundsPrefs_CFLAGS = -fobjc-arc -fstack-protector-strong -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations
NoCaptureSoundsPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
NoCaptureSoundsPrefs_PRIVATE_FRAMEWORKS = Preferences
NoCaptureSoundsPrefs_LIBRARIES = $(NSC_PATH_LIBRARY)
NoCaptureSoundsPrefs_LDFLAGS = -F$(THEOS_PROJECT_DIR)/Settings/vendor
NoCaptureSoundsPrefs_INSTALL_PATH = /Library/PreferenceBundles
NoCaptureSoundsPrefs_RESOURCE_DIRS = Settings/Resources
include $(THEOS_MAKE_PATH)/bundle.mk
