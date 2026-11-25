#!/bin/bash
# Builds the app, signed ad hoc, and packages it into dist/: a ZIP and a DMG, each with and without the version, and
# SHA256SUMS. Run it through make release, which passes APP_NAME and EXECUTABLE. See RELEASING.md.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APP_NAME:?run through make release}" "${EXECUTABLE:?run through make release}"
APP="build/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
BASE="$EXECUTABLE-$VERSION"

# Everything the run needs is checked before anything is built.
die() {
    echo "error: $1" >&2
    exit 1
}
python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' || die "dmgbuild needs Python 3.11 or later as python3"
# The release must be its commit: a change or an untracked file would go into the build without being in the source.
changes=$(git status --porcelain --untracked-files=all) || die "make release runs in a git checkout"
[[ -z "$changes" ]] || die "the working tree has changes; commit or remove them first"
# The version tags on this commit must be none, as in CI, or v$VERSION alone, which must tag no other commit.
tags=$(git tag --points-at HEAD --list 'v*')
[[ -z "$tags" || "$tags" == "v$VERSION" ]] || die "this commit is tagged ${tags//$'\n'/ }, but Info.plist says $VERSION"
if [[ -z "$tags" ]] && git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
    die "v$VERSION tags another commit; bump the version in Info.plist"
fi

# Work files go in a private staging folder, removed on exit once a DMG a failed check left mounted there is detached.
# dist/ is replaced only after every check has passed, by a rename from the staging folder beside it, which holds the
# previous dist/ until the new one is in place.
stage=$(mktemp -d "$PWD/.release.XXXXXX")
cleanup() {
    hdiutil detach "$stage/mount" -force -quiet 2>/dev/null || true
    rm -rf "$stage"
}
trap cleanup EXIT
out="$stage/dist"
mkdir "$out"
ZIP="$out/$BASE.zip"
DMG="$out/$BASE.dmg"

# The icon is rendered into the staging folder, so a release never reuses an older build/AppIcon.icns.
icon="$stage/AppIcon.icns"
make build ICON="$icon"
ditto -c -k --keepParent "$APP" "$ZIP"

# dmgbuild writes the window layout into .DS_Store directly; no Finder scripting, so no permission prompts. It runs
# from a fresh venv holding only the hash checked wheels. render-svg.swift also writes dmg-background@2x.png, which
# dmgbuild picks up for Retina displays.
swift scripts/render-svg.swift dmg/background.svg "$stage/dmg-background.png"
python3 -m venv "$stage/venv"
"$stage/venv/bin/pip" install --quiet --disable-pip-version-check --require-hashes --only-binary :all: \
    -r dmg/requirements.txt
"$stage/venv/bin/dmgbuild" -s dmg/settings.py -D app="$APP" -D icon="$icon" \
    -D background="$stage/dmg-background.png" "$APP_NAME" "$DMG"

# The app as users install it, unpacked from the ZIP or copied out of the mounted DMG, must still pass a strict
# signature check.
mkdir "$stage/from-zip" "$stage/from-dmg" "$stage/mount"
ditto -x -k "$ZIP" "$stage/from-zip"
codesign --verify --strict --verbose=2 "$stage/from-zip/$APP_NAME.app"
hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$stage/mount" "$DMG" >/dev/null
cp -R "$stage/mount/$APP_NAME.app" "$stage/from-dmg/"
hdiutil detach "$stage/mount" -quiet
codesign --verify --strict --verbose=2 "$stage/from-dmg/$APP_NAME.app"

# Copies without the version keep releases/latest/download/<name> links stable across releases.
cp "$ZIP" "$out/$EXECUTABLE.zip"
cp "$DMG" "$out/$EXECUTABLE.dmg"
(cd "$out" && shasum -a 256 "$BASE.zip" "$BASE.dmg" "$EXECUTABLE.zip" "$EXECUTABLE.dmg" >SHA256SUMS)

[[ ! -e dist ]] || mv dist "$stage/previous"
mv "$out" dist || { mv "$stage/previous" dist; exit 1; }
echo
ls -l dist
cat dist/SHA256SUMS
echo "Signed ad hoc and not notarized: Gatekeeper blocks the first open after download (RELEASE_NOTES.md, Install)."
