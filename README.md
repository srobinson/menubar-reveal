[![A black and white print of Ply, a spiky haired waiter in a slim suit, bowing to serve a menu bar on his open palm, beside the words "An icon for your menu bar" in heavy worn type and the red Menu Bar Reveal icon.](assets/banner.png)](https://menubarreveal.com)

# Menu Bar Reveal

He waits. You don't.

## Install

Download the [latest DMG](https://github.com/srobinson/menubar-reveal/releases/latest/download/MenuBarReveal.dmg) and drag Menu Bar Reveal to Applications.

It isn't notarised, because we're skint right now. That means Apple hasn't checked it. It doesn't mean it's unsafe: the [source](Sources/) is here for you or your agent. No shenanigans. Just a free utility that waits for your shortcut.

macOS blocks the first open. One line in Terminal clears the block, for this app only:

```sh
/usr/bin/xattr -dr com.apple.quarantine "/Applications/Menu Bar Reveal.app"
```

Or use **Open Anyway**, [Apple's own way](https://support.apple.com/en-us/102445).

Then open it. A small panel asks for your shortcut. Enter one and you're good to go.

<!-- If you appreciate it: [DONATE](DONATION_URL) -->
