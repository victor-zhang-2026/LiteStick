#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
build_args=(-c release)
if [[ -n "${LITESTICK_MACOS_SDK:-}" ]]; then
    build_args+=(--sdk "$LITESTICK_MACOS_SDK")
elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    build_args+=(--sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk)
fi
swift build "${build_args[@]}"
mkdir -p build/LiteStick.app/Contents/MacOS build/LiteStick.app/Contents/Resources
cp .build/release/LiteStick build/LiteStick.app/Contents/MacOS/LiteStick
cp Support/Info.plist build/LiteStick.app/Contents/Info.plist
cp Support/LiteStick.icns build/LiteStick.app/Contents/Resources/LiteStick.icns
codesign --force --sign - build/LiteStick.app
codesign --verify --strict build/LiteStick.app
printf '%s\n' "$PWD/build/LiteStick.app"
