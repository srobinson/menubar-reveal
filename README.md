# Menu Bar Reveal

When macOS hides the menu bar, it waits for your pointer before showing it. Press <kbd>⌥</kbd> <kbd>`</kbd> and the bar comes down at once; press again, or click anywhere, to hide it.

## Install

**[Download MenuBarReveal.dmg](https://github.com/srobinson/menubar-reveal/releases/latest/download/MenuBarReveal.dmg)**, open it and drag Menu Bar Reveal to Applications. It needs macOS 14 or later, with **Automatically hide and show the menu bar** turned on in System Settings.

The app is not notarized by Apple, so macOS blocks the first open: open it once, close the message, then click **Open Anyway** next to Menu Bar Reveal in System Settings > Privacy & Security.

To build it yourself with Xcode 26 or later, run `make install`.

## Set your shortcut

Click the Menu Bar Reveal icon in the menu bar, choose **Change Shortcut**, and press the keys you want. Esc cancels.

Start at Login is on from the first launch; turn it off in the same menu.

---

MIT licensed. Made by Stuart Robinson.
