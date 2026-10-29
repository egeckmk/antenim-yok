#!/bin/zsh
# Archives + exports the iOS and macOS apps for App Store Connect. Does NOT upload anything.
#   apple/scripts/archive.sh [ios|mac|all]
# Output: apple/build/archives/*.xcarchive and apple/build/export/{ios,mac}/ (an .ipa / a .pkg to upload with
# Xcode Organizer or Transporter). Team ID comes from Config/Local.xcconfig (git-ignored).
# Every run uses a new build number (CURRENT_PROJECT_VERSION = yymmddHHMM), which App Store Connect requires.
set -e
cd "$(dirname "$0")/.."
WHAT=${1:-all}

TEAM=$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*\([A-Z0-9]*\).*/\1/p' Config/Local.xcconfig 2>/dev/null | head -1)
[[ -n $TEAM ]] || { echo "DEVELOPMENT_TEAM missing: copy Config/Local.xcconfig.example to Config/Local.xcconfig and fill it in."; exit 1; }

BUILD=$(date +%y%m%d%H%M)
VERSION=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml | head -1)
echo "AntenimYok $VERSION ($BUILD), team $TEAM"

mkdir -p build/archives build/export
sed "s/__TEAM_ID__/$TEAM/" scripts/ExportOptions.plist > build/ExportOptions.plist
xcodegen generate >/dev/null

archive() { # <name> <destination>
  xcodebuild archive -project AntenimYok.xcodeproj -scheme AntenimYok -configuration Release \
    -destination "$2" -archivePath "build/archives/AntenimYok-$1.xcarchive" \
    CURRENT_PROJECT_VERSION=$BUILD -allowProvisioningUpdates
  xcodebuild -exportArchive -archivePath "build/archives/AntenimYok-$1.xcarchive" \
    -exportOptionsPlist build/ExportOptions.plist -exportPath "build/export/$1" -allowProvisioningUpdates
}

[[ $WHAT == ios || $WHAT == all ]] && archive ios 'generic/platform=iOS'
[[ $WHAT == mac || $WHAT == all ]] && archive mac 'generic/platform=macOS'
echo "Done. Upload from apple/build/export/ with Xcode Organizer or Transporter (not done by this script)."
