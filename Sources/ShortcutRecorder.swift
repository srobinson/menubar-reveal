import AppKit
import Carbon.HIToolbox

/// The plain activate() is only a request, and macOS declines it for a menu bar app.
@MainActor
func bringAppForward() {
    NSApp.activate(ignoringOtherApps: true)
}

@MainActor
final class ShortcutRecorder: NSObject, NSWindowDelegate {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 110),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    private let message = NSTextField(labelWithString: "")
    private let current: Shortcut
    private let apply: (Shortcut) -> Bool
    private let onClose: () -> Void
    private var monitor: Any?

    init(current: Shortcut, apply: @escaping (Shortcut) -> Bool, onClose: @escaping () -> Void) {
        self.current = current
        self.apply = apply
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

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { self.handle(event) }
            return nil
        }
    }

    func focus() {
        bringAppForward()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_: Notification) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        onClose()
        NSApp.hide(nil)
    }

    private func handle(_ event: NSEvent) {
        guard Int(event.keyCode) != kVK_Escape else { return window.close() }
        guard let candidate = Shortcut(event: event) else {
            message.stringValue = "Include ⌘, ⌃ or ⌥, or use a function key."
            return
        }
        if apply(candidate) {
            window.close()
        } else {
            message.stringValue = "\(candidate.label) is already in use. Try another."
        }
    }
}
