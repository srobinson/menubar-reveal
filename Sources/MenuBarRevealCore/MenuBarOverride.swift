import AppKit
import os

/// Shows the auto hidden menu bar with SkyLight's private `SLSSetMenuBarVisibilityOverrideOnDisplay`, as SpaceJumper
/// and Quickbar do. The override keeps the bar on a display until it is set off, even after the process ends, and
/// macOS 14 to 26 do not report it, so `hide` sets it off on every display rather than only where it was set on.
@MainActor
package final class MenuBarOverride {
    /// Sets the override on one display, true to show the bar and false to hand it back to macOS, and returns whether
    /// SkyLight took it.
    package typealias Setter = (_ display: CGDirectDisplayID, _ shown: Bool) -> Bool

    private let set: Setter
    /// The displays `hide` sets off.
    private let displays: () -> [CGDirectDisplayID]
    /// The display the bar was shown on, which `hide` sets off even once it has gone from `displays`.
    private var shownOn: CGDirectDisplayID?

    package var isShown: Bool { shownOn != nil }

    package init(set: @escaping Setter, displays: @escaping () -> [CGDirectDisplayID]) {
        self.set = set
        self.displays = displays
    }

    /// Records nothing when SkyLight refuses, so the next press shows again.
    package func show(on display: CGDirectDisplayID) {
        if set(display, true) { shownOn = display }
    }

    /// Sets the override off on every display, which also clears one a crash left on. If the shown display refuses
    /// and is still attached, the bar stays shown so the next press retries.
    package func hide() {
        let attached = displays()
        for display in Set(attached) where display != shownOn { _ = set(display, false) }
        if let shownOn, set(shownOn, false) || !attached.contains(shownOn) { self.shownOn = nil }
    }
}

extension MenuBarOverride {
    /// SkyLight's override on the displays of `NSScreen.screens`, or nil, logged, when macOS lacks the private call.
    package static func skyLight() -> MenuBarOverride? {
        typealias MainConnectionID = @convention(c) () -> Int32
        typealias SetOverride = @convention(c) (Int32, CGDirectDisplayID, Bool) -> Int32
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let skyLight = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else {
            Logger.menuBar.error("SkyLight is missing")
            return nil
        }
        guard let mainConnectionID = dlsym(skyLight, "SLSMainConnectionID"),
            let setOverride = dlsym(skyLight, "SLSSetMenuBarVisibilityOverrideOnDisplay")
        else {
            dlclose(skyLight)
            Logger.menuBar.error("SkyLight's menu bar override is missing")
            return nil
        }
        let connection = unsafeBitCast(mainConnectionID, to: MainConnectionID.self)()
        let setOverrideOn = unsafeBitCast(setOverride, to: SetOverride.self)
        return MenuBarOverride(
            set: { display, shown in
                let status = setOverrideOn(connection, display, shown)
                if status != 0 { Logger.menuBar.error("Menu bar override failed: \(status, privacy: .public)") }
                return status == 0
            },
            displays: { NSScreen.screens.compactMap(\.displayID) })
    }
}

extension NSScreen {
    /// The Core Graphics display the screen shows on.
    package var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
