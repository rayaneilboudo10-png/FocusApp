#!/usr/bin/env bash
# Archives and exports a LOCALLY SIGNED FocusApp.ipa using your Apple ID in Xcode.
#
# Usage:  ./scripts/build_signed_ipa.sh <TEAM_ID> <bundle-id-prefix> [--free]
#   TEAM_ID           Your team ID (Xcode › Settings › Accounts, or the OU in your cert).
#   bundle-id-prefix  Must be unique to you, e.g. com.yourname.focus
#   --free            Free / personal team: drops the Family Controls entitlement
#                     (not allowed on personal teams). The app then runs in
#                     Strict Focus Lock mode.
#
# Prerequisite: sign in to your Apple ID in Xcode › Settings › Accounts, and plug in /
# register your iPhone once (Window › Devices and Simulators) so a profile can be made.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${1:?Usage: $0 <TEAM_ID> <bundle-id-prefix> [--free]}"
PREFIX="${2:?Usage: $0 <TEAM_ID> <bundle-id-prefix> [--free]}"
FREE="${3:-}"

EXTRA=()
if [ "$FREE" = "--free" ]; then
  EXTRA+=(CODE_SIGN_ENTITLEMENTS=Config/FreeAccount.entitlements)
  echo "▸ Free Apple ID mode: Family Controls entitlement removed"
fi

command -v xcodegen >/dev/null || { echo "XcodeGen not found. Install with: brew install xcodegen"; exit 1; }
xcodegen generate --quiet

rm -rf build/FocusApp.xcarchive dist
echo "▸ Archiving"
xcodebuild archive \
  -project FocusApp.xcodeproj \
  -scheme FocusApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/FocusApp.xcarchive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  BUNDLE_ID_PREFIX="$PREFIX" \
  CODE_SIGN_STYLE=Automatic \
  ${EXTRA[@]+"${EXTRA[@]}"}

echo "▸ Exporting IPA"
xcodebuild -exportArchive \
  -archivePath build/FocusApp.xcarchive \
  -exportPath dist \
  -exportOptionsPlist Config/ExportOptions-Development.plist \
  -allowProvisioningUpdates

echo "✓ Done: dist/FocusApp.ipa"
echo "  Install: Xcode › Window › Devices and Simulators › drag the .ipa onto your iPhone,"
echo "  or: xcrun devicectl device install app --device <UDID> dist/FocusApp.ipa"
