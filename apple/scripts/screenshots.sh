#!/bin/zsh
# App Store screenshots from the DEBUG demo mode (real Radio Browser stations, throw-away favorites).
#   apple/scripts/screenshots.sh [iphone|mac|mac-manual|all]
#   mac-manual: opens the demo app for each theme/section and waits; you take the picture yourself (see AppStore/README.md)
# Output: apple/AppStore/screenshots/ (git-ignored). Needs network. Mac: run on a Retina screen with Screen Recording allowed.
set -e
cd "$(dirname "$0")/.."
WHAT=${1:-all}
OUT=AppStore/screenshots
IPHONE="iPhone 18 Pro Max"      # 6.9" (1320 x 2868)
SECTIONS=(favorites discover)
THEMES=(light dark)
mkdir -p $OUT/iphone-6.9 $OUT/mac
xcodegen generate >/dev/null

if [[ $WHAT == iphone || $WHAT == all ]]; then
  xcodebuild -project AntenimYok.xcodeproj -scheme AntenimYok -configuration Debug \
    -destination "platform=iOS Simulator,name=$IPHONE" -derivedDataPath build/dd-shots CODE_SIGNING_ALLOWED=NO build >/dev/null
  APP=build/dd-shots/Build/Products/Debug-iphonesimulator/AntenimYok.app
  xcrun simctl boot "$IPHONE" 2>/dev/null || true
  xcrun simctl bootstatus "$IPHONE" -b >/dev/null
  xcrun simctl status_bar "$IPHONE" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  xcrun simctl install "$IPHONE" $APP
  n=0
  for theme in $THEMES; do for section in $SECTIONS; do
    n=$((n+1))
    xcrun simctl terminate "$IPHONE" InessSoftware.AntenimYok 2>/dev/null || true
    xcrun simctl launch "$IPHONE" InessSoftware.AntenimYok -demoMode -demoSection $section -demoTheme $theme -demoPlay >/dev/null
    sleep 18
    xcrun simctl io "$IPHONE" screenshot "$OUT/iphone-6.9/$n-$section-$theme.png" >/dev/null
  done; done
  xcrun simctl terminate "$IPHONE" InessSoftware.AntenimYok 2>/dev/null || true
  xcrun simctl status_bar "$IPHONE" clear
fi

if [[ $WHAT == mac-manual ]]; then
  xcodebuild -project AntenimYok.xcodeproj -scheme AntenimYok -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath build/dd-shots CODE_SIGNING_ALLOWED=NO build >/dev/null
  BIN=build/dd-shots/Build/Products/Debug/AntenimYok.app/Contents/MacOS/AntenimYok
  for theme in $THEMES; do for section in $SECTIONS; do
    $BIN -demoMode -demoSection $section -demoTheme $theme -demoPlay &
    PID=$!
    echo "\n>>> $section / $theme: wait ~15 s, press Shift-Command-4, then Space, click the window (Option-click = no shadow)."
    echo "    Save as $OUT/mac/$section-$theme.png, then press Return here for the next one."
    read
    kill $PID 2>/dev/null || true
    sleep 1
  done; done
fi

if [[ $WHAT == mac || $WHAT == all ]]; then
  xcodebuild -project AntenimYok.xcodeproj -scheme AntenimYok -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath build/dd-shots CODE_SIGNING_ALLOWED=NO build >/dev/null
  BIN=build/dd-shots/Build/Products/Debug/AntenimYok.app/Contents/MacOS/AntenimYok
  n=0
  for theme in $THEMES; do for section in $SECTIONS; do
    n=$((n+1))
    $BIN -demoMode -demoSection $section -demoTheme $theme -demoPlay &
    PID=$!
    sleep 18
    ID=$(swift scripts/windowid.swift AntenimYok)
    screencapture -o -x -l $ID "$OUT/mac/$n-$section-$theme.png"
    kill $PID 2>/dev/null || true
    sleep 1
  done; done
fi
for f in $OUT/*/*.png; do echo "$f $(sips -g pixelWidth -g pixelHeight $f | awk '/pixel/{printf $2"x"}')"; done
