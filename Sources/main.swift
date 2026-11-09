import AppKit
import Carbon.HIToolbox
import ServiceManagement

private let hotKeySignature: OSType = 0x4D42_5256 // "MBRV"
private let loginConfiguredKey = "loginItemConfigured"

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let shortcutItem = NSMenuItem(title: "", action: #selector(changeShortcut), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
    private var shortcut = Shortcut.load()
    private var recorder: ShortcutRecorder?
    private let hold = MenuBarHold()
    private var hotKey: EventHotKeyRef?
    private var dismissKey: EventHotKeyRef?
    private var clickMonitor: Any?
    private var terminationSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_: Notification) {
        configureStatusItem()
        configureLoginOnFirstLaunch()
        configureTerminationSignal()
        installHotKeyHandler()
        if !registerShortcut(shortcut) { showConflictAlert() }
    }

    func applicationWillTerminate(_: Notification) {
        hideBar()
    }

    func menuWillOpen(_: NSMenu) {
        // The open menu keeps the bar on screen, and Esc must reach the menu.
        hideBar()
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    fileprivate func toggleBar() {
        if hold.isActive {
            hideBar()
        } else {
            showBar()
        }
    }

    private func showBar() {
        guard let button = statusItem.button else { return }
        hold.start(on: button)
        dismissKey = registerHotKey(code: UInt32(kVK_Escape), modifiers: 0)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated { self.hideBar() }
        }
    }

    private func hideBar() {
        guard hold.isActive else { return }
        hold.stop()
        if let dismissKey { UnregisterEventHotKey(dismissKey) }
        dismissKey = nil
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }

    /// Routes SIGTERM through normal termination so the hold is released before the process exits.
    private func configureTerminationSignal() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        source.resume()
        terminationSignal = source
    }

    private func configureStatusItem() {
        statusItem.button?.image = makeIcon()

        shortcutItem.target = self
        loginItem.target = self
        menu.delegate = self
        menu.addItem(shortcutItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "")
        statusItem.menu = menu
        refreshShortcutLabels()
    }

    private func refreshShortcutLabels() {
        statusItem.button?.toolTip = "Menubar Reveal (\(shortcut.label))"
        shortcutItem.title = "Change Shortcut (\(shortcut.label))…"
    }

    private func makeIcon() -> NSImage {
        let icon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 12, width: 14, height: 3.5), xRadius: 1.75, yRadius: 1.75).fill()

            let chevron = NSBezierPath()
            chevron.move(to: NSPoint(x: 5, y: 9))
            chevron.line(to: NSPoint(x: 9, y: 5))
            chevron.line(to: NSPoint(x: 13, y: 9))
            chevron.lineWidth = 1.8
            chevron.lineCapStyle = .round
            chevron.lineJoinStyle = .round
            chevron.stroke()
            return true
        }
        icon.isTemplate = true
        return icon
    }

    private func configureLoginOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: loginConfiguredKey) else { return }
        UserDefaults.standard.set(true, forKey: loginConfiguredKey)
        setStartsAtLogin(true)
    }

    private func setStartsAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Menubar Reveal: could not update login item: \(error)")
        }
    }

    @objc private func toggleLogin() {
        setStartsAtLogin(SMAppService.mainApp.status != .enabled)
    }

    @objc private func changeShortcut() {
        if recorder == nil {
            // Released while recording so the current shortcut can be captured as a key press.
            unregisterHotKey()
            recorder = ShortcutRecorder(current: shortcut, apply: applyShortcut) { [unowned self] in
                recorder = nil
                if hotKey == nil { _ = registerShortcut(shortcut) }
            }
        }
        recorder?.focus()
    }

    private func applyShortcut(_ candidate: Shortcut) -> Bool {
        guard registerShortcut(candidate) else { return false }
        shortcut = candidate
        shortcut.save()
        refreshShortcutLabels()
        return true
    }

    private func installHotKeyHandler() {
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // The shortcut and the temporary Esc key both land here, and both toggle.
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            MainActor.assumeIsolated { delegate.toggleBar() }
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    private func registerShortcut(_ candidate: Shortcut) -> Bool {
        guard let ref = registerHotKey(code: candidate.keyCode, modifiers: candidate.modifiers) else { return false }
        hotKey = ref
        return true
    }

    private func registerHotKey(code: UInt32, modifiers: UInt32) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: hotKeySignature, id: 1)
        let status = RegisterEventHotKey(code, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else {
            NSLog("Menubar Reveal: hot key registration failed: \(status)")
            return nil
        }
        return ref
    }

    private func unregisterHotKey() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    private func showConflictAlert() {
        let alert = NSAlert()
        alert.messageText = "\(shortcut.label) is already in use"
        alert.informativeText = "Choose a different shortcut from the Menubar Reveal menu bar icon."
        bringAppForward()
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
