import AppKit
import Carbon.HIToolbox
import MenuBarRevealCore

/// The Change Shortcut window: the next key pressed in it, with any modifiers or none, becomes the shortcut. Esc
/// cancels; Delete, Forward Delete or the clear button clears the shortcut. It reads key presses only while it is the
/// key window, with the shortcut released so it can be pressed here.
@MainActor
final class ShortcutRecorder: NSObject, NSWindowDelegate {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 110), styleMask: [.titled, .closable], backing: .buffered,
        defer: false)
    private let message = NSTextField(labelWithString: "")
    private let clearButton = NSButton(
        image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear Shortcut")!, target: nil,
        action: #selector(clear))
    private let hotKey: HotKey
    /// Gets the shortcut recorded, or nil when it is cleared.
    private let onChange: (Shortcut?) -> Void
    private var monitor: Any?

    init(hotKey: HotKey, onChange: @escaping (Shortcut?) -> Void) {
        self.hotKey = hotKey
        self.onChange = onChange
        super.init()

        let title = NSTextField(labelWithString: "Press a new shortcut")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        message.textColor = .secondaryLabelColor
        clearButton.target = self
        clearButton.isBordered = false
        clearButton.contentTintColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, NSStackView(views: [message, clearButton])])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        window.contentView = stack
        window.title = "Change Shortcut"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
    }

    func show(current: Shortcut?) {
        message.stringValue = current.map { "Current: \($0.label). Press Esc to cancel." } ?? "Press Esc to cancel."
        clearButton.isHidden = current == nil
        // An LSUIElement app opened from Finder starts in the background, and macOS 27 refuses it the cooperative
        // NSApp.activate(), leaving the window behind the frontmost app and unable to read keys.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// The shortcut is released only once this window can read key presses.
    func windowDidBecomeKey(_: Notification) {
        guard monitor == nil else { return }
        // This is the app's only window, so every key press is read here and none goes on to AppKit.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.record(event) }
            return nil
        }
        if monitor != nil { hotKey.suspend() }
    }

    func windowDidResignKey(_: Notification) {
        stopRecording()
    }

    func windowWillClose(_: Notification) {
        stopRecording()
        // Hands activation back to the app the user came from.
        NSApp.hide(nil)
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        hotKey.resume()
    }

    @objc private func clear() {
        hotKey.clear()
        onChange(nil)
        window.close()
    }

    private func record(_ event: NSEvent) {
        let candidate = Shortcut(event: event)
        // Only the bare keys cancel or clear; with modifiers they are chords like any other.
        switch candidate {
        case Shortcut(keyCode: kVK_Escape, modifiers: 0):
            window.close()
        case Shortcut(keyCode: kVK_Delete, modifiers: 0), Shortcut(keyCode: kVK_ForwardDelete, modifiers: 0):
            clear()
        default:
            do {
                try hotKey.replace(with: candidate)
                onChange(candidate)
                window.close()
            } catch .inUse {
                message.stringValue = "\(candidate.label) is already in use. Try another."
                NSAccessibility.post(
                    element: window, notification: .announcementRequested,
                    userInfo: [.announcement: message.stringValue, .priority: NSAccessibilityPriorityLevel.high.rawValue])
            } catch {
                // HotKey logged it.
                NSSound.beep()
            }
        }
    }
}
