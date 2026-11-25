#!/bin/bash
# Assembles the app bundle from the built executable, then signs it ad hoc and verifies it. Run it through make build,
# which passes the names and paths.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APP_NAME:?run through make build}" "${EXECUTABLE:?run through make build}" "${BUILT_EXECUTABLE:?run through make build}" \
    "${ICON:?run through make build}" "${MIN_MACOS:?run through make build}" "${BUNDLE:?run through make build}"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BUILT_EXECUTABLE" "$BUNDLE/Contents/MacOS/$EXECUTABLE"
plist="$BUNDLE/Contents/Info.plist"
cp Info.plist "$plist"
plutil -replace CFBundleExecutable -string "$EXECUTABLE" "$plist"
plutil -replace CFBundleName -string "$APP_NAME" "$plist"
plutil -replace CFBundleDisplayName -string "$APP_NAME" "$plist"
plutil -replace LSMinimumSystemVersion -string "$MIN_MACOS" "$plist"
cp "$ICON" "$BUNDLE/Contents/Resources/AppIcon.icns"
cp LICENSE "$BUNDLE/Contents/Resources/LICENSE"
codesign --force --options runtime --sign - "$BUNDLE"
codesign --verify --strict "$BUNDLE"
