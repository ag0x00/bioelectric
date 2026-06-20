#!/bin/bash
# Builds BioElectric.saver from the Swift sources — no Xcode project.
# Native CoreGraphics renderer (no WebView). Universal binary (arm64 + x86_64).
# Output: screensaver/macos/BioElectric.saver
set -euo pipefail

MODULE="BioElectric"                       # must match NSPrincipalClass module in Info.plist
HERE="$(cd "$(dirname "$0")" && pwd)"
SAVER="$HERE/$MODULE.saver"
BUILD="$HERE/.build"
SOURCES=("$HERE/Geometry.swift" "$HERE/BioElectricView.swift")

rm -rf "$SAVER" "$BUILD"
mkdir -p "$BUILD" "$SAVER/Contents/MacOS"

# --- compile universal binary (compile objects per arch, link as Mach-O bundle, lipo together) ---
for ARCH in arm64 x86_64; do
  swiftc -c "${SOURCES[@]}" \
    -module-name "$MODULE" \
    -target "${ARCH}-apple-macos11" \
    -O -wmo \
    -o "$BUILD/$MODULE-$ARCH.o"
  swiftc "$BUILD/$MODULE-$ARCH.o" \
    -module-name "$MODULE" \
    -target "${ARCH}-apple-macos11" \
    -framework ScreenSaver \
    -Xlinker -bundle \
    -o "$BUILD/$MODULE-$ARCH"
done
lipo -create "$BUILD/$MODULE-arm64" "$BUILD/$MODULE-x86_64" -output "$SAVER/Contents/MacOS/$MODULE"

cp "$HERE/Info.plist" "$SAVER/Contents/Info.plist"

# Ad-hoc sign the whole bundle — macOS won't load an unsigned .saver in the sandboxed engine.
codesign --force --deep --sign - "$SAVER"

rm -rf "$BUILD"
echo "Built + signed: $SAVER"
echo "Install: cp -R '$SAVER' ~/Library/Screen\ Savers/  (then open System Settings > Screen Saver)"
