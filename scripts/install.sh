#!/bin/bash
# Builds the app, replaces the copy in INSTALL_DIR and opens it. Run it through make install, which passes the names.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APP_NAME:?run through make install}" "${EXECUTABLE:?run through make install}" "${INSTALL_DIR:?run through make install}"
dest="$INSTALL_DIR/$APP_NAME.app"
# The new copy is staged and verified beside the installed one, so a failed copy leaves that in place, and the swap is
# a rename on one volume. The installed copy is kept aside until the new one is in its place.
new="$INSTALL_DIR/.$APP_NAME.app.new"
old="$INSTALL_DIR/.$APP_NAME.app.old"
trap 'rm -rf "$new"' EXIT

make build
mkdir -p "$INSTALL_DIR"
rm -rf "$new" "$old"
ditto "build/$APP_NAME.app" "$new"
codesign --verify --strict "$new"
# The app quits on SIGTERM the way Quit does, which takes a moment. Opening it before it has gone would reach the old
# process instead of starting the new copy.
pkill -u "$UID" -x "$EXECUTABLE" || true
waits=0
while pgrep -u "$UID" -x "$EXECUTABLE" >/dev/null; do
    if ((++waits > 50)); then
        echo "error: $EXECUTABLE did not quit within 5 seconds; quit it, then run make install again" >&2
        exit 1
    fi
    sleep 0.1
done
[[ ! -e "$dest" ]] || mv "$dest" "$old"
mv "$new" "$dest" || { mv "$old" "$dest"; exit 1; }
rm -rf "$old"
open "$dest"
