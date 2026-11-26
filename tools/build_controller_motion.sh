#!/usr/bin/env bash
# Build the Apple GameController motion GDExtension for macOS (universal) and iOS (arm64).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
SRC="$ROOT/native/src/controller_motion.m"
OUT_DIR="$ROOT/native/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

(cd "$TMP_DIR" && "$GODOT_BIN" --headless --dump-gdextension-interface >/dev/null 2>&1)
mkdir -p "$OUT_DIR"

MACOS_SDK="$(xcrun --sdk macosx --show-sdk-path)"
xcrun --sdk macosx clang -fobjc-arc -O2 -Wall -Wextra -dynamiclib \
	-arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
	-isysroot "$MACOS_SDK" -I"$TMP_DIR" \
	-framework Foundation -framework GameController \
	"$SRC" -o "$OUT_DIR/libcontroller_motion.macos.universal.dylib"
codesign --force --sign - "$OUT_DIR/libcontroller_motion.macos.universal.dylib"

if IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)"; then
	xcrun --sdk iphoneos clang -fobjc-arc -O2 -Wall -Wextra -dynamiclib \
		-arch arm64 -mios-version-min=14.0 \
		-isysroot "$IOS_SDK" -I"$TMP_DIR" \
		-framework Foundation -framework GameController \
		"$SRC" -o "$OUT_DIR/libcontroller_motion.ios.arm64.dylib"
	codesign --force --sign - "$OUT_DIR/libcontroller_motion.ios.arm64.dylib"
fi

echo "Built controller motion GDExtension in $OUT_DIR"
