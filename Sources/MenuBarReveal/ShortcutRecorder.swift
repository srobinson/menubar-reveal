import AppKit
import Carbon.HIToolbox
import MenuBarRevealCore

/// The Change Shortcut window: the next key pressed in it, with any modifiers or none, becomes the shortcut, and Esc
/// cancels. It reads key presses only while it is the key window, with the shortcut released so it can be pressed here.
@MainActor
final class ShortcutRecorder: NSObject, NSWindowDelegate {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 110), styleMask: [.titled, .closable], backing: .buffered,
        defer: false)
    private let message = NSTextField(labelWithString: "")
    private let hotKey: HotKey
    /// Gets the recorded shortcut, or nil when the window closes without one.
    private let onClose: (Shortcut?) -> Void
    private var recorded: Shortcut?
    private var monitor: Any?

    init(current: Shortcut, hotKey: HotKey, onClose: @escaping (Shortcut?) -> Void) {
        self.hotKey = hotKey
        self.onClose = onClose
        super.init()

        let title = NSTextField(labelWithString: "Press a new shortcut")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        message.stringValue = "Current: \(current.label). Press Esc to cancel."
        message.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, message])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        window.contentView = stack
        window.title = "Change Shortcut"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
    }

    func focus() {
        NSApp.activate()
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
        // Closing also resigns key, which then needs no answer.
        window.delegate = nil
        stopRecording()
        onClose(recorded)
        // Hands activation back to the app the user came from.
        NSApp.hide(nil)
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        hotKey.resume()
    }

    private func record(_ event: NSEvent) {
        let candidate = Shortcut(event: event)
        // Only a bare Esc cancels; with modifiers it is a chord like any other.
        if candidate == Shortcut(keyCode: kVK_Escape, modifiers: 0) {
            window.close()
        } else if hotKey.replace(with: candidate) {
            recorded = candidate
            window.close()
        } else {
            message.stringValue = "\(candidate.label) is already in use. Try another."
        }
    }
}
