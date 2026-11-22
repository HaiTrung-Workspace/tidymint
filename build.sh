#!/bin/bash
# Build "Tidymint.app" with the Xcode Command Line Tools (no Xcode needed).
# Usage: ./build.sh            -> build/Tidymint.app
#        ./build.sh --install  -> also copy it to /Applications
#        ./build.sh --release  -> universal build (Apple silicon + Intel) zipped as build/Tidymint-<version>.zip
#        ./build.sh --dev      -> "Tidymint Dev.app" (own bundle id, settings and data, DEV badge) in /Applications,
#                                 runs beside the official app
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/build"; NAME="Tidymint"
if [ "$1" = "--dev" ]; then NAME="Tidymint Dev"; BUNDLE_ID="${BUNDLE_ID:-com.haitrung.diskcleanup.dev}"; fi
# Sources/Private/ exists only in the private dev repo; public builds compile without it.
# When it is there, its build-flags.sh sets the compiler flags (PRIV) and the folders to leave out (SKIP),
# and may rename the Dev app (NAME; OLD_APP = an earlier copy to remove on install).
# PLIST_EXTRA: more Info.plist keys from that file (empty for a public build).
PRIV=(); SKIP=(); OLD_APP=""; PLIST_EXTRA=""
[ -f "$ROOT/Sources/Private/build-flags.sh" ] && . "$ROOT/Sources/Private/build-flags.sh"
# A Dev build is decided when it is compiled, never when it runs (22/11/2026): only --dev, or TIDYMINT_DEV=1 for a
# test copy, passes -D TIDYMINT_DEV. Without it `isDevBuild` is the constant false and no bundle id, launch
# argument or setting can turn the app into a Dev build. A release can never carry it.
if [ "$1" = "--release" ] && [ "${TIDYMINT_DEV:-0}" = 1 ]; then echo "STOP: --release with TIDYMINT_DEV=1. A release is never a Dev build."; exit 1; fi
if [ "$1" = "--dev" ] || [ "${TIDYMINT_DEV:-0}" = 1 ]; then PRIV+=(-D TIDYMINT_DEV); echo "Dev build: TIDYMINT_DEV compiled in"; fi
APP="$OUT/$NAME.app"
BUNDLE_ID="${BUNDLE_ID:-com.haitrung.diskcleanup}"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo 0.1.0)"

rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
sources() { find "$ROOT/Sources" -name "*.swift" "${SKIP[@]}" | sort; }
build_arch() { swiftc -swift-version 5 -parse-as-library -O "${PRIV[@]}" -target "$1-apple-macos14" \
  -o "$2" $(sources) -framework SwiftUI -framework AppKit -framework Carbon; }
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
$PLIST_EXTRA</dict></plist>
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

# Release only: strip the symbol table so the paid logic cannot be read by name (22/11/2026). Before signing, so the
# signature covers the stripped binary. A Dev build keeps its symbols for the debugger. Swift reflection metadata
# (type and field names) is NOT removed by strip; a signed build with an Apple certificate is the real tamper guard.
if [ "$1" = "--release" ]; then strip -x "$APP/Contents/MacOS/Tidymint"; fi

# Signature. Release gets a real Developer ID Application signature with the hardened runtime and a secure
# timestamp: this is the tamper guard. On Apple silicon macOS refuses to run an app whose seal is broken, so a
# changed copy must be re-signed, which stamps a different Team Identifier; the app checks that at launch.
# A single arm64 Mach-O with no nested code, so the .app is signed directly (no --deep). Override the
# identity with TIDYMINT_SIGN_ID; default is this project's Developer ID. Other builds keep an ad-hoc signature
# tied to the bundle id so macOS keeps their permissions across rebuilds.
xattr -cr "$APP"
if [ "$1" = "--release" ]; then
  # The Developer ID signing identity is read from the environment and never written in this file, which goes to the
  # public repo; the identity names a person (22/11/2026). Set TIDYMINT_SIGN_ID on the build machine, taken from
  # `security find-identity -v -p codesigning`.
  # TIDYMINT_SIGN_ID=- asks for an ad-hoc signature on purpose: the build check on GitHub and anyone compiling the
  # public code have no Developer ID. Such a build is for checking that the code compiles, not for handing out:
  # macOS blocks it on other Macs and it cannot be notarized.
  SIGN_ID="${TIDYMINT_SIGN_ID:-}"
  if [ -z "$SIGN_ID" ]; then
    echo "STOP: set TIDYMINT_SIGN_ID to the Developer ID Application identity (see: security find-identity -v -p codesigning), or to - for an ad-hoc build that is not for distribution" >&2
    exit 1
  fi
  if [ "$SIGN_ID" = "-" ]; then
    if [ -n "${TIDYMINT_NOTARIZE:-}" ]; then echo "STOP: an ad-hoc build cannot be notarized" >&2; exit 1; fi
    echo "NOTE: ad-hoc signature (TIDYMINT_SIGN_ID=-). Not a release to distribute." >&2
    codesign --force --deep -s - -r="designated => identifier \"$BUNDLE_ID\"" "$APP"
  else
    if ! security find-identity -v -p codesigning | grep -qF "$SIGN_ID"; then
      echo "STOP: the identity in TIDYMINT_SIGN_ID is not in the keychain" >&2
      exit 1
    fi
    codesign --force --options runtime --timestamp -s "$SIGN_ID" "$APP" || { echo "STOP: codesign --release failed" >&2; exit 1; }
  fi
else
  codesign --force --deep -s - -r="designated => identifier \"$BUNDLE_ID\"" "$APP"
fi
echo "Built: $APP"
# Private builds only: a check that build-flags.sh may define (runs on the finished app, stops the build when it fails).
if type private_check >/dev/null 2>&1; then private_check "$APP" "$1"; fi

if [ "$1" = "--release" ]; then
  ZIP="$OUT/Tidymint-$VERSION.zip"; rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "Release zip: $ZIP"
  # Notarization (opt-in: set TIDYMINT_NOTARIZE=1). Apple checks the signed, hardened-runtime app and issues a
  # ticket; stapling the ticket into the .app lets any Mac open it offline without a Gatekeeper warning. Needs a
  # stored notarytool profile (TIDYMINT_NOTARY_PROFILE, default "tidymint-notary"; see notarytool store-credentials).
  if [ -n "${TIDYMINT_NOTARIZE:-}" ]; then
    PROFILE="${TIDYMINT_NOTARY_PROFILE:-tidymint-notary}"
    echo "Notarizing (profile: $PROFILE); this waits on Apple and can take a few minutes..."
    if xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait; then
      xcrun stapler staple "$APP" || { echo "STOP: stapling failed" >&2; exit 1; }
      rm -f "$ZIP"; ditto -c -k --keepParent "$APP" "$ZIP"   # re-zip so the distributed copy carries the stapled ticket
      echo "Notarized + stapled; re-zipped: $ZIP"
    else
      echo "STOP: notarization failed (see the notarytool log line above; 'notarytool log <id> --keychain-profile $PROFILE' for detail)" >&2
      exit 1
    fi
  fi
fi

if [ "$1" = "--install" ]; then
  rm -rf "/Applications/Tidymint.app"; cp -R "$APP" /Applications/
  echo "Installed: /Applications/Tidymint.app"
fi

if [ "$1" = "--dev" ]; then
  # In /Applications, like the official app: macOS 27 keeps an app's own menu bar icons in view (Mintbar) only for a copy there.
  DEST="/Applications/$NAME.app"
  # Never replace a newer Dev build with an older branch (e.g. building an old release folder for screenshots).
  # Run the old one from build/ instead, or set FORCE_DEV_INSTALL=1 to replace on purpose.
  NEW_V="$(cat "$ROOT/VERSION")"
  OLD_V=""   # PlistBuddy prints a message on stdout for a missing file, so only ask when the copy is there
  [ -f "$DEST/Contents/Info.plist" ] && OLD_V="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || true)"
  if [ -n "$OLD_V" ] && [ "${FORCE_DEV_INSTALL:-0}" != "1" ] && \
     [ "$(printf '%s\n%s\n' "$OLD_V" "$NEW_V" | sort -V | tail -1)" != "$NEW_V" ]; then
    echo "Not installed: $DEST is $OLD_V, newer than this build ($NEW_V)."
    echo "Run it from: $APP   (or FORCE_DEV_INSTALL=1 ./build.sh --dev to replace it)"
    exit 0
  fi
  # Quit only the Dev copy (by bundle id; both copies are named Tidymint) and reopen it after, so it keeps running in the background.
  WAS_RUNNING=0; pgrep -f "$NAME.app/Contents/MacOS" >/dev/null && WAS_RUNNING=1
  if [ -n "$OLD_APP" ] && pgrep -f "$OLD_APP/Contents/MacOS" >/dev/null; then WAS_RUNNING=1; fi
  osascript -e 'tell application id "com.haitrung.diskcleanup.dev" to quit' 2>/dev/null || true
  # A copy under an earlier name has the same bundle id: two of them would fight over settings and permissions.
  if [ -n "$OLD_APP" ] && [ "$OLD_APP" != "$DEST" ] && [ -d "$OLD_APP" ]; then sleep 1; rm -rf "$OLD_APP"; echo "Removed: $OLD_APP"; fi
  rm -rf "$DEST"; cp -R "$APP" /Applications/
  # Refresh the icon Finder and the Dock show (they cache the old one otherwise).
  touch "$DEST"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" 2>/dev/null || true
  [ "$WAS_RUNNING" = 1 ] && { sleep 1; open -g "$DEST"; echo "Reopened: $DEST"; }
  echo "Installed: $DEST ($NEW_V)"
fi
