# Menubar Reveal

Shows the auto-hidden macOS menu bar on a hotkey, without waiting for the hover delay.

Press Option+\` and the bar slides in. Press the shortcut again, press Esc, or click elsewhere to hide it. The app holds an invisible popover on its own menu bar item, which makes macOS keep the bar on screen. Your auto-hide setting never changes.

## Install

Requires macOS 14 or later on Apple silicon and the Xcode Command Line Tools (`xcode-select --install`).

```sh
make
```

This builds the app, installs it to `~/Applications`, and launches it. It starts at login by default. Use the menu bar icon to turn that off or quit.

To use a different hotkey, choose Change Shortcut from the menu bar icon.
