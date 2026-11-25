#!/bin/zsh
set -e

ROOT="${0:A:h}"
APP_NAME="NoSleepBar"
APP_BUNDLE="$ROOT/$APP_NAME.app"
BUILD_DIR="$ROOT/.build/release"

echo "==> 编译 $APP_NAME"
swift build --package-path "$ROOT" -c release --disable-sandbox

echo "==> 组装 App Bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "==> ad-hoc 签名"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> 完成: $APP_BUNDLE"
