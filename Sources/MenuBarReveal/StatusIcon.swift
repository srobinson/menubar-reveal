import AppKit

extension NSImage {
    /// The menu bar icon: a bar with a chevron under it, and a dot while no shortcut is set. A template image, so it
    /// follows light, dark and tinted menu bars.
    static func statusIcon(needsShortcut: Bool) -> NSImage {
        // AppKit may draw the image on any thread, so the drawing block is Sendable rather than main actor isolated.
        let icon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { @Sendable _ in
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

            if needsShortcut { NSBezierPath(ovalIn: NSRect(x: 13, y: 1, width: 4, height: 4)).fill() }
            return true
        }
        icon.isTemplate = true
        return icon
    }
}
