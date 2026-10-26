#!/bin/bash
# Build "Disk Cleanup.app" with the Xcode Command Line Tools (no Xcode needed).
# Usage: ./build.sh            -> build/Disk Cleanup.app
#        ./build.sh --install  -> also copy it to /Applications
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/build"; APP="$OUT/Disk Cleanup.app"
BUNDLE_ID="${BUNDLE_ID:-com.haitrung.diskcleanup}"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo 0.1.0)"

rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -swift-version 5 -parse-as-library -O -target "$(uname -m)-apple-macos14" \
  -o "$APP/Contents/MacOS/DiskCleanup" "$ROOT/Sources/main.swift" -framework SwiftUI -framework AppKit

cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Disk Cleanup</string>
<key>CFBundleDisplayName</key><string>Disk Cleanup</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleExecutable</key><string>DiskCleanup</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Disk Cleanup asks Finder to empty the Trash when you click Empty Trash.</string>
</dict></plist>
PL

T=$(mktemp -d); IS="$T/AppIcon.iconset"; mkdir "$IS"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ROOT/Resources/AppIcon.png" --out "$IS/icon_${s}x${s}.png" >/dev/null
  d=$((s*2)); sips -z $d $d "$ROOT/Resources/AppIcon.png" --out "$IS/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$IS" -o "$APP/Contents/Resources/AppIcon.icns"; rm -rf "$T"

# Ad-hoc signature tied to the bundle identifier, so macOS keeps permissions across rebuilds.
xattr -cr "$APP"
codesign --force --deep -s - -r="designated => identifier \"$BUNDLE_ID\"" "$APP"
echo "Built: $APP"

if [ "$1" = "--install" ]; then
  rm -rf "/Applications/Disk Cleanup.app"; cp -R "$APP" /Applications/
  echo "Installed: /Applications/Disk Cleanup.app"
fi
