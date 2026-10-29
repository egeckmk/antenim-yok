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

# A local "Apple Distribution" identity (certificate WITH its private key in the keychain) is picked by SHA-1, never by name:
# with Xcode's cloud-managed certificate the signature's code requirement gets the name "Ege Çakmak" in decomposed Unicode
# (C + U+0327), which no longer matches the certificate -> App Store Connect: "Invalid Signature". See AppStore/README.md.
DIST_SHA1=$(security find-identity -v -p codesigning | sed -n 's/^ *[0-9]*) \([0-9A-F]\{40\}\) "Apple Distribution:.*/\1/p' | head -1)
if [[ -n $DIST_SHA1 ]]; then
  echo "Signing with the local Apple Distribution identity $DIST_SHA1"
  /usr/libexec/PlistBuddy -c "Add :signingCertificate string $DIST_SHA1" build/ExportOptions.plist
else
  echo "WARNING: no local Apple Distribution identity; Xcode will use the cloud-managed certificate and the result may be rejected (Invalid Signature) if the name has non-ASCII letters."
fi
xcodegen generate >/dev/null

archive() { # <name> <destination>
  xcodebuild archive -project AntenimYok.xcodeproj -scheme AntenimYok -configuration Release \
    -destination "$2" -archivePath "build/archives/AntenimYok-$1.xcarchive" \
    CURRENT_PROJECT_VERSION=$BUILD -allowProvisioningUpdates
  xcodebuild -exportArchive -archivePath "build/archives/AntenimYok-$1.xcarchive" \
    -exportOptionsPlist build/ExportOptions.plist -exportPath "build/export/$1" -allowProvisioningUpdates
}

FAILED=0
# The exported app must satisfy its own designated requirement, or App Store Connect rejects it.
verify() { # <app path>
  local out
  if ! out=$(codesign --verify --deep --strict -vv "$1" 2>&1); then
    echo "$out"
    echo "ERROR: $1 is not properly signed (App Store Connect would say 'Invalid Signature')."
    echo "       See apple/AppStore/README.md, section 'Invalid Signature'."
    return 1
  fi
  echo "OK: $1 satisfies its designated requirement"
}

if [[ $WHAT == ios || $WHAT == all ]]; then
  archive ios 'generic/platform=iOS'
  rm -rf build/verify/ios && mkdir -p build/verify/ios && unzip -q build/export/ios/AntenimYok.ipa -d build/verify/ios
  verify build/verify/ios/Payload/AntenimYok.app || FAILED=1
fi
if [[ $WHAT == mac || $WHAT == all ]]; then
  archive mac 'generic/platform=macOS'
  rm -rf build/verify/mac && mkdir -p build/verify && pkgutil --expand-full build/export/mac/AntenimYok.pkg build/verify/mac
  verify "$(echo build/verify/mac/*.pkg/Payload/AntenimYok.app)" || FAILED=1
fi
[[ $FAILED == 0 ]] || { echo "Signature check FAILED: do not upload these files."; exit 1; }
echo "Done. Upload from apple/build/export/ with Xcode Organizer or Transporter (not done by this script)."
