import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import MenuBarRevealCore

/// A defaults domain of its own, removed when the test ends, so the user's saved shortcut is never read or written.
private final class ScratchDefaults {
    let name = "MenuBarRevealCoreTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() { defaults = UserDefaults(suiteName: name)! }
    deinit { defaults.removePersistentDomain(forName: name) }
}

struct ShortcutLoadingTests {
    private let scratch = ScratchDefaults()

    @Test func nothingSavedGivesNoShortcut() {
        #expect(Shortcut.load(from: scratch.defaults) == nil)
    }

    @Test func savingNoShortcutRemovesTheSavedOne() {
        Shortcut.save(Shortcut(keyCode: kVK_ANSI_B, modifiers: cmdKey), to: scratch.defaults)
        Shortcut.save(nil, to: scratch.defaults)
        #expect(scratch.defaults.object(forKey: "shortcut") == nil)
    }

    /// Any chord saves and loads as it is, with modifiers or none, including values no key press makes.
    @Test(arguments: [
        Shortcut(keyCode: kVK_ANSI_M, modifiers: controlKey | cmdKey),
        Shortcut(keyCode: kVK_ANSI_B, modifiers: cmdKey),
        Shortcut(keyCode: kVK_F5, modifiers: 0),
        Shortcut(keyCode: kVK_ANSI_B, modifiers: 0),
        Shortcut(keyCode: kVK_ANSI_B, modifiers: shiftKey),
        Shortcut(keyCode: 200, modifiers: controlKey | alphaLock),
    ])
    func aSavedShortcutLoads(shortcut: Shortcut) {
        Shortcut.save(shortcut, to: scratch.defaults)
        #expect(Shortcut.load(from: scratch.defaults) == shortcut)
    }

    /// 0.1.0 saved the label beside the key, so its users keep their shortcut.
    @Test func loadsWhat010Saved() {
        scratch.defaults.set(Data(#"{"keyCode":11,"modifiers":2304,"label":"⌥⌘B"}"#.utf8), forKey: "shortcut")
        #expect(Shortcut.load(from: scratch.defaults) == Shortcut(keyCode: kVK_ANSI_B, modifiers: optionKey | cmdKey))
    }

    @Test(arguments: ["not json", #"{"keyCode":48}"#, #"{"keyCode":-1,"modifiers":0}"#])
    func undecodableSavedValueGivesNoShortcut(saved: String) {
        scratch.defaults.set(Data(saved.utf8), forKey: "shortcut")
        #expect(Shortcut.load(from: scratch.defaults) == nil)
    }
}

struct ShortcutEventTests {
    private func keyDown(_ keyCode: Int, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                characters: "b", charactersIgnoringModifiers: "b", isARepeat: false, keyCode: UInt16(keyCode)))
    }

    /// Caps Lock and the keypad flag are not modifiers a shortcut holds.
    @Test func readsKeyAndModifiersFromAKeyPress() throws {
        let event = try keyDown(kVK_ANSI_B, [.control, .option, .capsLock, .numericPad])
        #expect(Shortcut(event: event) == Shortcut(keyCode: kVK_ANSI_B, modifiers: controlKey | optionKey))
    }

    @Test func aKeyWithoutModifiersIsAShortcut() throws {
        #expect(Shortcut(event: try keyDown(kVK_ANSI_B, [])) == Shortcut(keyCode: kVK_ANSI_B, modifiers: 0))
    }
}

@MainActor
struct ShortcutLabelTests {
    /// An installed layout, enabled or not, read with its default table whatever keyboard this Mac has.
    private func layout(_ id: String) throws -> KeyboardLayout {
        let filter = [kTISPropertyInputSourceID as String: "com.apple.keylayout.\(id)"] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]
        return try #require(KeyboardLayout(sources?.first, keyboardType: 0))
    }

    @Test func modifiersReadInMenuOrder() throws {
        let shortcut = Shortcut(keyCode: kVK_ANSI_B, modifiers: cmdKey | shiftKey | optionKey | controlKey)
        #expect(shortcut.label(using: try layout("US")) == "⌃⌥⇧⌘B")
    }

    @Test(arguments: [
        (kVK_ANSI_Grave, optionKey, "⌥`"),
        (kVK_Tab, controlKey | cmdKey, "⌃⌘⇥"),
        (kVK_Space, controlKey, "⌃Space"),
        (kVK_F5, 0, "F5"),
        (kVK_ANSI_B, 0, "B"),
    ])
    func namesKeysThatPrintNothingOrDifferently(keyCode: Int, modifiers: Int, label: String) throws {
        #expect(Shortcut(keyCode: keyCode, modifiers: modifiers).label(using: try layout("US")) == label)
    }

    /// The saved key is a position; its label follows the layout, as QWERTZ and AZERTY move letters.
    @Test(arguments: [
        ("US", kVK_ANSI_Y, "⌃⌥Y"),
        ("German", kVK_ANSI_Y, "⌃⌥Z"),
        ("French", kVK_ANSI_Q, "⌃⌥A"),
        ("German", kVK_ANSI_Minus, "⌃⌥ß"),
    ])
    func keyFollowsTheLayout(layoutID: String, keyCode: Int, label: String) throws {
        let shortcut = Shortcut(keyCode: keyCode, modifiers: controlKey | optionKey)
        #expect(shortcut.label(using: try layout(layoutID)) == label)
    }

    /// German puts no ` on the key US prints it on, so a fixed "⌥`", as 0.1.0 showed, would name a key it lacks.
    @Test func theGraveKeyFollowsTheLayout() throws {
        let label = Shortcut(keyCode: kVK_ANSI_Grave, modifiers: optionKey).label(using: try layout("German"))
        #expect(label.hasPrefix("⌥") && label != "⌥`")
    }

    /// With no layout to read, keys that print nothing keep their names and others fall back to the key code.
    @Test func labelsWithoutALayout() {
        #expect(Shortcut(keyCode: kVK_Tab, modifiers: controlKey | cmdKey).label(using: nil) == "⌃⌘⇥")
        #expect(Shortcut(keyCode: kVK_ANSI_B, modifiers: controlKey).label(using: nil) == "⌃Key 11")
    }

    /// A saved key code no key press makes, too large for the layout, labels by its code rather than crashing.
    @Test func anOutOfRangeKeyCodeLabelsByItsCode() throws {
        #expect(Shortcut(keyCode: 65_536, modifiers: controlKey).label(using: try layout("US")) == "⌃Key 65536")
    }
}
