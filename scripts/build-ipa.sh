#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos/CarPlayW.app"
ENTITLEMENTS="$ROOT_DIR/CarPlayW/Resources/CarPlayW.entitlements"

command -v xcodegen >/dev/null || {
  echo "error: xcodegen is required (brew install xcodegen)" >&2
  exit 1
}

cd "$ROOT_DIR"
xcodegen generate
rm -rf "$BUILD_DIR" "$ROOT_DIR/Payload"

xcodebuild \
  -project CarPlayW.xcodeproj \
  -scheme CarPlayW \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

# Fail the build if the configured home-screen icon was not compiled into the app.
test -s "$APP_PATH/Assets.car"
ICON_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName' "$APP_PATH/Info.plist")
test "$ICON_NAME" = "AppIcon"
echo "Bundled app icon: $ICON_NAME"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Info.plist"
codesign --force --sign - --entitlements "$ENTITLEMENTS" --generate-entitlement-der "$APP_PATH"
mkdir -p "$ROOT_DIR/Payload"
cp -R "$APP_PATH" "$ROOT_DIR/Payload/"
(
  cd "$ROOT_DIR"
  ditto -c -k --sequesterRsrc --keepParent Payload "$BUILD_DIR/CarPlayW.ipa"
)
rm -rf "$ROOT_DIR/Payload"

codesign -d --entitlements :- "$APP_PATH"
echo "IPA: $BUILD_DIR/CarPlayW.ipa"
