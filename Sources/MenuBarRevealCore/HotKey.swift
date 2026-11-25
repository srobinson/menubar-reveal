import Carbon.HIToolbox
import Foundation
import os

let hotKeyID = EventHotKeyID(signature: 0x4D42_5256, id: 1)  // "MBRV"

/// The app's global shortcut, registered with Carbon, which needs no Accessibility or Input Monitoring permission.
@MainActor
package final class HotKey {
    private let action: @MainActor () -> Void
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    /// The chord `resume` registers again.
    private var shortcut: Shortcut?

    package var isRegistered: Bool { ref != nil }

    package init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    /// Makes `shortcut` the chord and registers it. False, logged, when Carbon refuses it; `resume` tries again.
    /// False, with nothing changed, while a chord is registered.
    package func register(_ shortcut: Shortcut) -> Bool {
        guard ref == nil else { return false }
        self.shortcut = shortcut
        return replace(with: shortcut)
    }

    /// Registers `shortcut` in place of the released chord. False, and the current chord stays, while that chord is
    /// still registered, as when Carbon would not release it, or when Carbon refuses `shortcut`, logged.
    package func replace(with shortcut: Shortcut) -> Bool {
        guard ref == nil, installHandler() else { return false }
        var new: EventHotKeyRef?
        // Exclusive, so Carbon refuses a chord another app holds, and no other app can take this one.
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(),
            UInt32(kEventHotKeyExclusive), &new)
        guard status == noErr, let new else {
            Logger.shortcut.error("Hot key registration failed: \(status, privacy: .public)")
            return false
        }
        ref = new
        self.shortcut = shortcut
        return true
    }

    /// Releases the chord, so Change Shortcut can read it as a key press, until `resume`.
    package func suspend() {
        guard let ref else { return }
        let status = UnregisterEventHotKey(ref)
        guard status == noErr else { return Logger.shortcut.error("Hot key release failed: \(status, privacy: .public)") }
        self.ref = nil
    }

    package func resume() {
        guard ref == nil, let shortcut else { return }
        _ = replace(with: shortcut)
    }

    /// A registered hot key without this handler never fires, so each registration retries a failed install.
    func installHandler() -> Bool {
        guard handler == nil else { return true }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // The handler stays installed for the life of the process, so it keeps this object alive.
        let context = Unmanaged.passRetained(self)
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            // Sendable keeps the callback nonisolated, so an off main call returns here instead of trapping.
            { @Sendable _, event, userData in
                guard Thread.isMainThread else { return OSStatus(eventNotHandledErr) }
                var pressedID = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &pressedID)
                // Other hot keys in this process pass through untouched.
                guard status == noErr, pressedID.signature == hotKeyID.signature, pressedID.id == hotKeyID.id,
                    let userData
                else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.action() }
                return noErr
            }, 1, &pressed, context.toOpaque(), &handler)
        guard status == noErr else {
            context.release()
            Logger.shortcut.error("Hot key handler installation failed: \(status, privacy: .public)")
            return false
        }
        return true
    }

    /// Removes the handler and releases the reference it held, so each test leaves the application target as it found
    /// it. The app keeps its handler until it quits.
    func removeHandler() {
        guard let handler, RemoveEventHandler(handler) == noErr else { return }
        self.handler = nil
        Unmanaged.passUnretained(self).release()
    }
}
