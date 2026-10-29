#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
nsc_temp=$(mktemp -d "${TMPDIR:-/tmp}/no-capture-sounds.XXXXXX")
trap 'rm -rf "$nsc_temp"' EXIT HUP INT TERM
xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fstack-protector-strong \
 -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter -Wno-unused-function \
 -Wno-deprecated-declarations -Itests -framework Foundation -framework CoreFoundation \
 Settings/NSCSettings.m tests/runtime.m -o "$nsc_temp/runtime"
"$nsc_temp/runtime" "$nsc_temp/files"
