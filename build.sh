#!/bin/bash
# Build "Tidymint.app" with the Xcode Command Line Tools (no Xcode needed).
# Usage: ./build.sh            -> build/Tidymint.app
#        ./build.sh --install  -> also copy it to /Applications
#        ./build.sh --release  -> universal build (Apple silicon + Intel) zipped as build/Tidymint-<version>.zip
#        ./build.sh --dev      -> "Tidymint Dev.app" (own bundle id, settings and data, DEV badge) in ~/Applications,
#                                 runs beside the official app
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/build"; NAME="Tidymint"
if [ "$1" = "--dev" ]; then NAME="Tidymint Dev"; BUNDLE_ID="${BUNDLE_ID:-com.haitrung.diskcleanup.dev}"; fi
APP="$OUT/$NAME.app"
BUNDLE_ID="${BUNDLE_ID:-com.haitrung.diskcleanup}"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo 0.1.0)"

rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
build_arch() { swiftc -swift-version 5 -parse-as-library -O -target "$1-apple-macos14" \
  -o "$2" "$ROOT"/Sources/*.swift -framework SwiftUI -framework AppKit -framework Carbon; }
if [ "$1" = "--release" ]; then
  build_arch arm64 "$OUT/Tidymint-arm64"; build_arch x86_64 "$OUT/Tidymint-x86_64"
  lipo -create "$OUT/Tidymint-arm64" "$OUT/Tidymint-x86_64" -output "$APP/Contents/MacOS/Tidymint"
  rm -f "$OUT/Tidymint-arm64" "$OUT/Tidymint-x86_64"
else
  build_arch "$(uname -m)" "$APP/Contents/MacOS/Tidymint"
fi

cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$NAME</string>
<key>CFBundleDisplayName</key><string>$NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleExecutable</key><string>Tidymint</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Tidymint asks Finder to empty the Trash when you click Empty Trash, and to move apps installed for every user to the Trash when you uninstall them. macOS asks for the password, never Tidymint.</string>
</dict></plist>
PL

T=$(mktemp -d); IS="$T/AppIcon.iconset"; mkdir "$IS"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ROOT/Resources/AppIcon.png" --out "$IS/icon_${s}x${s}.png" >/dev/null
  d=$((s*2)); sips -z $d $d "$ROOT/Resources/AppIcon.png" --out "$IS/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$IS" -o "$APP/Contents/Resources/AppIcon.icns"
if [ "$1" = "--dev" ]; then
  # Finder/Dock icon with the DEV badge, drawn by the app itself (it reads the .dev bundle id).
  "$APP/Contents/MacOS/Tidymint" --export-icon mint "$T/dev.png"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$T/dev.png" --out "$IS/icon_${s}x${s}.png" >/dev/null
    d=$((s*2)); sips -z $d $d "$T/dev.png" --out "$IS/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$IS" -o "$APP/Contents/Resources/AppIcon.icns"
fi
rm -rf "$T"

# Ad-hoc signature tied to the bundle identifier, so macOS keeps permissions across rebuilds.
xattr -cr "$APP"
codesign --force --deep -s - -r="designated => identifier \"$BUNDLE_ID\"" "$APP"
echo "Built: $APP"

if [ "$1" = "--release" ]; then
  ZIP="$OUT/Tidymint-$VERSION.zip"; rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "Release zip: $ZIP"
fi

if [ "$1" = "--install" ]; then
  rm -rf "/Applications/Tidymint.app"; cp -R "$APP" /Applications/
  echo "Installed: /Applications/Tidymint.app"
fi

if [ "$1" = "--dev" ]; then
  DEST="$HOME/Applications/$NAME.app"
  # Never replace a newer Dev build with an older branch (e.g. building an old release folder for screenshots).
  # Run the old one from build/ instead, or set FORCE_DEV_INSTALL=1 to replace on purpose.
  NEW_V="$(cat "$ROOT/VERSION")"
  OLD_V="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || true)"
  if [ -n "$OLD_V" ] && [ "${FORCE_DEV_INSTALL:-0}" != "1" ] && \
     [ "$(printf '%s\n%s\n' "$OLD_V" "$NEW_V" | sort -V | tail -1)" != "$NEW_V" ]; then
    echo "Not installed: $DEST is $OLD_V, newer than this build ($NEW_V)."
    echo "Run it from: $APP   (or FORCE_DEV_INSTALL=1 ./build.sh --dev to replace it)"
    exit 0
  fi
  mkdir -p "$HOME/Applications"; osascript -e "quit app \"$DEST\"" 2>/dev/null || true
  rm -rf "$DEST"; cp -R "$APP" "$HOME/Applications/"
  # Refresh the icon Finder and the Dock show (they cache the old one otherwise).
  touch "$DEST"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" 2>/dev/null || true
  echo "Installed: $DEST ($NEW_V)"
fi
