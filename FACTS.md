# How it works

- **The shortcut** is a Carbon hot key (`RegisterEventHotKey`, `Sources/MenuBarRevealCore/HotKey.swift`), which needs no Accessibility or Input Monitoring permission.
- **The reveal** calls `SLSSetMenuBarVisibilityOverrideOnDisplay`, a private SkyLight function that SpaceJumper and Quickbar also use (`MenuBarOverride.swift`). Apple does not document it, so a macOS update could change or remove it. The app looks it up at launch with `dlopen` and `dlsym`; if it is missing, the app logs that once and the shortcut does nothing.
- **On** shows the bar on the display under the pointer, or on the first display when displays share Spaces. **Off** hands the bar back to macOS. The override outlives the process, and macOS 14 to 26 do not report it, so the app sets it off on every display when it hides the bar, when it quits (SIGTERM goes through Quit) and when it launches, which clears one left by a crash.
