import Carbon.HIToolbox
import Testing

@testable import MenuBarRevealCore

/// Sends hot key events to the handler directly. The registration tests take ⌃⌥⇧⌘F18 and ⌃⌥⇧⌘F19 from the system, chords
/// few Macs have, for the length of each test, one at a time.
@MainActor
@Suite(.serialized)
struct HotKeyTests {
    private final class Presses {
        var count = 0
    }

    private let f18 = Shortcut(keyCode: kVK_F18, modifiers: controlKey | optionKey | shiftKey | cmdKey)
    private let f19 = Shortcut(keyCode: kVK_F19, modifiers: controlKey | optionKey | shiftKey | cmdKey)

    /// Gives back the hot key's chord and handler.
    private func release(_ hotKey: HotKey) {
        hotKey.suspend()
        hotKey.removeHandler()
    }

    /// Whether this process holds `chord`: Carbon refuses to register it a second time. Any other refusal fails the test.
    private func isHeld(_ chord: Shortcut) -> Bool {
        var probe: EventHotKeyRef?
        let status = RegisterEventHotKey(
            chord.keyCode, chord.modifiers, hotKeyID, GetApplicationEventTarget(), UInt32(kEventHotKeyExclusive), &probe)
        switch status {
        case noErr:
            UnregisterEventHotKey(probe)
            return false
        case OSStatus(eventHotKeyExistsErr):
            return true
        default:
            Issue.record("RegisterEventHotKey returned \(status)")
            return false
        }
    }

    /// A hot key press event carrying `id`, or no hot key ID at all when it is nil.
    private func sendPress(of id: EventHotKeyID?) throws -> OSStatus {
        var event: EventRef?
        try #require(
            CreateEvent(
                nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), GetCurrentEventTime(),
                EventAttributes(kEventAttributeNone), &event) == noErr)
        defer { ReleaseEvent(event) }
        if var id {
            try #require(
                SetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    MemoryLayout<EventHotKeyID>.size, &id) == noErr)
        }
        return SendEventToEventTarget(event, GetApplicationEventTarget())
    }

    @Test func pressOfItsOwnKeyRunsTheAction() throws {
        let presses = Presses()
        let hotKey = HotKey { presses.count += 1 }
        #expect(hotKey.installHandler())
        defer { hotKey.removeHandler() }
        #expect(try sendPress(of: hotKeyID) == noErr)
        #expect(presses.count == 1)
    }

    /// Another ID, another signature with the same ID, and a press without an ID all pass through untouched.
    @Test func otherHotKeysPassThrough() throws {
        let presses = Presses()
        let hotKey = HotKey { presses.count += 1 }
        #expect(hotKey.installHandler())
        defer { hotKey.removeHandler() }
        let others: [EventHotKeyID?] = [
            EventHotKeyID(signature: hotKeyID.signature, id: hotKeyID.id + 1),
            EventHotKeyID(signature: hotKeyID.signature + 1, id: hotKeyID.id),
            nil,
        ]
        for other in others {
            #expect(try sendPress(of: other) == OSStatus(eventNotHandledErr))
        }
        #expect(presses.count == 0)
    }

    /// After removal no handler answers the press, and nothing else keeps the hot key alive.
    @Test func removingTheHandlerReleasesTheHotKey() throws {
        weak var released: HotKey?
        do {
            let presses = Presses()
            let hotKey = HotKey { presses.count += 1 }
            #expect(hotKey.installHandler())
            hotKey.removeHandler()
            released = hotKey
            #expect(try sendPress(of: hotKeyID) == OSStatus(eventNotHandledErr))
            #expect(presses.count == 0)
        }
        #expect(released == nil)
    }

    @Test func withoutAChordSuspendAndResumeDoNothing() {
        let hotKey = HotKey {}
        defer { release(hotKey) }
        hotKey.suspend()
        hotKey.resume()
        #expect(!hotKey.isRegistered)
    }

    @Test func suspendReleasesTheChordUntilResume() throws {
        let hotKey = HotKey {}
        defer { release(hotKey) }
        try hotKey.register(f19)
        #expect(isHeld(f19))
        hotKey.suspend()
        #expect(!hotKey.isRegistered && !isHeld(f19))
        hotKey.resume()
        #expect(hotKey.isRegistered && isHeld(f19))
    }

    /// The new chord replaces the old only once the old is released. Still registered, as a failed release leaves it,
    /// the old chord stays, and the refusal is no conflict.
    @Test(arguments: [false, true])
    func replaceTakesTheNewChordOnlyOnceTheOldIsReleased(suspended: Bool) throws {
        let hotKey = HotKey {}
        defer { release(hotKey) }
        try hotKey.register(f19)
        if suspended {
            hotKey.suspend()
            try hotKey.replace(with: f18)
        } else {
            #expect(throws: HotKeyError.failed) { try hotKey.replace(with: f18) }
        }
        hotKey.resume()
        #expect(isHeld(f18) == suspended && isHeld(f19) == !suspended)
    }

    /// A chord another holds is refused as in use, and the current chord comes back on resume.
    @Test func aChordInUseKeepsTheCurrentOne() throws {
        let other = HotKey {}
        let hotKey = HotKey {}
        defer { [other, hotKey].forEach(release) }
        try other.register(f18)
        try hotKey.register(f19)
        hotKey.suspend()
        #expect(throws: HotKeyError.inUse) { try hotKey.replace(with: f18) }
        hotKey.resume()
        #expect(hotKey.isRegistered && isHeld(f19))
    }

    /// A chord refused at launch is tried again on resume, as Change Shortcut closes.
    @Test func resumeRetriesARefusedRegistration() throws {
        let other = HotKey {}
        let hotKey = HotKey {}
        defer { [other, hotKey].forEach(release) }
        try other.register(f19)
        #expect(throws: HotKeyError.inUse) { try hotKey.register(f19) }
        release(other)
        hotKey.resume()
        #expect(hotKey.isRegistered)
    }

    /// A cleared chord is released and stays so, as Change Shortcut closes after clearing.
    @Test func clearReleasesTheChordForGood() throws {
        let hotKey = HotKey {}
        defer { release(hotKey) }
        try hotKey.register(f19)
        hotKey.clear()
        hotKey.resume()
        #expect(!hotKey.isRegistered && !isHeld(f19))
    }
}
