<!-- The body of the GitHub release for the version below, the page the site's Download button opens; RELEASING.md says when to edit it. -->
# Menu Bar Reveal 1.0.0

Press your shortcut and the hidden macOS menu bar comes down at once. Press again, or click anywhere, to hide it.

We put this together because people have been asking for it for years. Here it is.

Ad hoc signed, not notarized by Apple. macOS blocks the first open; where your Mac's security settings allow it, you open it anyway once in Privacy & Security (steps below). The [source](https://github.com/srobinson/menubar-reveal) is right next to you: read it, or build the app yourself.

## Install

macOS 14 or later, Apple silicon or Intel, with **Automatically hide and show the menu bar** turned on in System Settings.

1. Download **MenuBarReveal.dmg** below, open it and drag **Menu Bar Reveal** to Applications.
2. Open Menu Bar Reveal. macOS says it could not verify the app; close that message.
3. In System Settings > Privacy & Security, click **Open Anyway** next to Menu Bar Reveal, and confirm.

Choose your shortcut when the app first opens; change or clear it from the menu bar icon. Start at Login is on from the first launch.

`SHA256SUMS` lists each file's checksum: `grep ' MenuBarReveal.dmg$' SHA256SUMS | shasum -a 256 -c`. Source: tag [v1.0.0](https://github.com/srobinson/menubar-reveal/tree/v1.0.0), MIT licensed.
