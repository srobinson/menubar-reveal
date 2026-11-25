# Releasing

`make release` builds the universal app, signed ad hoc, and replaces `dist/` with `MenuBarReveal-<version>.zip` and `.dmg`, the same two without the version (so `releases/latest/download/MenuBarReveal.dmg` always serves the newest), and `SHA256SUMS`. It checks that the app unpacked from the ZIP and the DMG passes `codesign --verify --strict`. It refuses a tree with changes or untracked files, and a version tag on the commit other than `v` plus the version in `Info.plist`.

It needs Xcode 26 or later, Python 3.11 or later as `python3` and network access: each run installs the pinned, hash checked dmgbuild wheels in `dmg/requirements.txt` into a fresh venv. The DMG window is `dmg/settings.py` and `dmg/background.svg`.

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`, and the version and tag in `RELEASE_NOTES.md`. Commit on `main`.
2. Tag, check, build and push the tag:

   ```sh
   git tag -a v1.0.0 -m "Menu Bar Reveal 1.0.0"
   make check && make release
   git push origin v1.0.0
   ```

3. Publish with the [GitHub CLI](https://cli.github.com):

   ```sh
   gh release create v1.0.0 --verify-tag --title "Menu Bar Reveal 1.0.0" --notes-file RELEASE_NOTES.md \
       dist/MenuBarReveal-1.0.0.dmg dist/MenuBarReveal-1.0.0.zip dist/MenuBarReveal.dmg dist/MenuBarReveal.zip dist/SHA256SUMS
   ```

4. Download `releases/latest/download/MenuBarReveal.dmg` and the published `SHA256SUMS` into one folder, and check them there:

   ```sh
   grep ' MenuBarReveal.dmg$' SHA256SUMS | shasum -a 256 -c
   ```
