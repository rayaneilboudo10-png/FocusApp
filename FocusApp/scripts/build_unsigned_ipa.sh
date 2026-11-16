#!/usr/bin/env bash
# Builds an UNSIGNED FocusApp.ipa for sideloading tools (Sideloadly, AltStore,
# SideStore, etc.), which re-sign it with your own Apple ID on install.
#
# Usage:  ./scripts/build_unsigned_ipa.sh [bundle-id-prefix]
#   bundle-id-prefix  defaults to com.focusapp — pick something unique, e.g. com.yourname.focus
set -euo pipefail
cd "$(dirname "$0")/.."

PREFIX="${1:-com.focusapp}"
GROUP_ID="group.${PREFIX}.focus"
BUILD_DIR="build"
DIST_DIR="dist"

command -v xcodegen >/dev/null || { echo "XcodeGen not found. Install with: brew install xcodegen"; exit 1; }

echo "▸ Generating Xcode project"
xcodegen generate --quiet

echo "▸ Building (Release, iphoneos, no code signing)"
rm -rf "$BUILD_DIR" "$DIST_DIR"
xcodebuild \
  -project FocusApp.xcodeproj \
  -scheme FocusApp \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_DIR" \
  BUNDLE_ID_PREFIX="$PREFIX" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build | { command -v xcpretty >/dev/null && xcpretty || cat; }

APP="$BUILD_DIR/Build/Products/Release-iphoneos/FocusApp.app"
[ -d "$APP" ] || { echo "Build output not found at $APP"; exit 1; }

# Optional: embed entitlements with ldid (brew install ldid) so re-signers can see
# which capabilities (App Groups, Family Controls) the app and extensions request.
if command -v ldid >/dev/null; then
  echo "▸ Embedding entitlements with ldid"
  ENT="$(mktemp -t focusent).plist"
  cat > "$ENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.developer.family-controls</key><true/>
  <key>com.apple.security.application-groups</key><array><string>${GROUP_ID}</string></array>
</dict></plist>
EOF
  for appex in "$APP"/PlugIns/*.appex; do
    ldid -S"$ENT" "$appex/$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$appex/Info.plist")"
  done
  ldid -S"$ENT" "$APP/FocusApp"
  rm -f "$ENT"
fi

echo "▸ Packaging IPA"
mkdir -p "$DIST_DIR/Payload"
cp -R "$APP" "$DIST_DIR/Payload/"
( cd "$DIST_DIR" && zip -qry FocusApp.ipa Payload && rm -rf Payload )

echo "✓ Done: $DIST_DIR/FocusApp.ipa"
