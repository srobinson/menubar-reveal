import AppKit
import Carbon.HIToolbox
import MenuBarRevealCore
import ServiceManagement
import os

private let loginConfiguredKey = "loginItemConfigured"
private let shortcutPromptedKey = "shortcutPrompted"
/// The display name, set once in the Makefile's APP_NAME and read from the bundle.
private let appName =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ProcessInfo.processInfo.processName

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// The app has no main nib, so it makes its delegate here and keeps it alive, as the application holds it weakly.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let shortcutItem = NSMenuItem(title: "", action: #selector(changeShortcut), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
    /// Nil until the user sets one, and after they clear it.
    private var shortcut = Shortcut.load()
    private lazy var hotKey = HotKey { [unowned self] in toggleBar() }
    private lazy var recorder = ShortcutRecorder(hotKey: hotKey) { [unowned self] changed in
        shortcut = changed
        Shortcut.save(changed)
        refreshStatusItem()
    }
    /// Nil when macOS lacks the private call; the shortcut then does nothing.
    private let menuBar = MenuBarOverride.skyLight()
    /// Hide the shown bar on a click in another app or in this one.
    private var clickMonitors: [Any] = []
    private var terminationSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_: Notification) {
        // Clears an override left on by a crash or a kill.
        hideBar()
        configureTerminationSignal()
        configureStatusItem()
        configureLoginOnFirstLaunch()
        registerShortcut()
    }

    func applicationWillTerminate(_: Notification) {
        hideBar()
    }

    func menuNeedsUpdate(_: NSMenu) {
        loginItem.state = startsAtLogin ? .on : .off
    }

    func menuWillOpen(_: NSMenu) {
        // The open menu keeps the bar on screen, so the override is set off.
        if menuBar?.isShown == true { hideBar() }
    }

    private func toggleBar() {
        guard let menuBar else { return }
        if menuBar.isShown {
            hideBar()
        } else {
            showBar(menuBar)
        }
    }

    /// Shows the bar on the display under the pointer, as SpaceJumper and Quickbar do. When displays share Spaces, only
    /// the first has a menu bar.
    private func showBar(_ menuBar: MenuBarOverride) {
        let pointer = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let underPointer =
            NSScreen.screensHaveSeparateSpaces ? screens.first { NSMouseInRect(pointer, $0.frame, false) } : nil
        guard let display = (underPointer ?? screens.first)?.displayID, menuBar.show(on: display) else { return }
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        clickMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: clicks) { _ in MainActor.assumeIsolated { self.hideBar() } },
            NSEvent.addLocalMonitorForEvents(matching: clicks) { event in
                MainActor.assumeIsolated { self.hideBar() }
                return event
            },
        ].compactMap { $0 }
    }

    private func hideBar() {
        menuBar?.hide()
        // After a refused hide, the next click retries it.
        guard menuBar?.isShown != true else { return }
        clickMonitors.forEach(NSEvent.removeMonitor)
        clickMonitors = []
    }

    /// SIGTERM, as pkill sends, would end the process on the spot. Routed through terminate, it quits the way Quit
    /// does, and applicationWillTerminate sets the override off first.
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
        statusItem.button?.setAccessibilityLabel(appName)

        shortcutItem.target = self
        loginItem.target = self
        menu.delegate = self
        menu.addItem(shortcutItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "")
        statusItem.menu = menu
        refreshStatusItem()
        // The labels show the key as the keyboard layout prints it, so they follow a change of input source.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil,
            suspensionBehavior: .deliverImmediately)
    }

    @objc private func inputSourceChanged(_: Notification) {
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        let label = shortcut.map { " (\($0.label))" } ?? ""
        statusItem.button?.image = .statusIcon(needsShortcut: shortcut == nil)
        statusItem.button?.toolTip = appName + label
        shortcutItem.title = "Change Shortcut\(label)…"
    }

    /// Start at Login counts as on once registered, allowed or waiting for approval in Login Items, so choosing it then
    /// withdraws the request.
    private var startsAtLogin: Bool { [.enabled, .requiresApproval].contains(SMAppService.mainApp.status) }

    /// Done once macOS has the login item, so a first try that fails is tried again at the next launch.
    private func configureLoginOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: loginConfiguredKey), setStartsAtLogin(true) else { return }
        UserDefaults.standard.set(true, forKey: loginConfiguredKey)
    }

    /// Whether Start at Login is now as asked. The status decides, since a register can throw yet still be pending.
    @discardableResult
    private func setStartsAtLogin(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // The domain and code only: a description can carry file paths and other details from the framework.
            let nsError = error as NSError
            Logger.loginItem.error("Login item update failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
        }
        return startsAtLogin == enabled
    }

    /// The user's own choice also ends the first launch setup, so a later launch never turns it back on.
    @objc private func toggleLogin() {
        UserDefaults.standard.set(true, forKey: loginConfiguredKey)
        setStartsAtLogin(!startsAtLogin)
    }

    @objc private func changeShortcut() {
        recorder.show(current: shortcut)
    }

    /// Change Shortcut opens at the first launch only; after that, the marked icon alone shows a missing shortcut. A
    /// saved shortcut also counts as prompted, so installs from before the marker do not see it again.
    private func registerShortcut() {
        let prompted = UserDefaults.standard.bool(forKey: shortcutPromptedKey)
        UserDefaults.standard.set(true, forKey: shortcutPromptedKey)
        guard let shortcut else {
            if !prompted { changeShortcut() }
            return
        }
        do {
            try hotKey.register(shortcut)
        } catch .inUse {
            showConflictAlert(for: shortcut)
        } catch {
            // HotKey logged it, and closing Change Shortcut tries it again.
        }
    }

    private func showConflictAlert(for shortcut: Shortcut) {
        let alert = NSAlert()
        alert.messageText = "\(shortcut.label) is already in use"
        alert.informativeText = "Choose a different shortcut from the \(appName) menu bar icon."
        NSApp.activate()
        alert.runModal()
    }
}
