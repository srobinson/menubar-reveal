import AppKit

/// An open popover on a status item makes macOS reveal the auto-hidden menu bar and keep it on screen.
@MainActor
final class MenuBarHold {
    private let popover = NSPopover()

    var isActive: Bool { popover.isShown }

    init() {
        let content = NSViewController()
        content.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        popover.contentViewController = content
        popover.animates = false
    }

    func start(on button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        guard let window = popover.contentViewController?.view.window else { return }
        window.alphaValue = 0
        window.ignoresMouseEvents = true
    }

    func stop() {
        popover.close()
    }
}
