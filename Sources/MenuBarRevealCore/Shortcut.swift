import AppKit
import Carbon.HIToolbox

private let defaultsKey = "shortcut"

/// In menu order, as macOS writes shortcuts: ⌃⌥⇧⌘.
private let modifierKeys: [(flag: NSEvent.ModifierFlags, carbon: Int, symbol: String)] = [
    (.control, controlKey, "⌃"),
    (.option, optionKey, "⌥"),
    (.shift, shiftKey, "⇧"),
    (.command, cmdKey, "⌘"),
]

/// F1 to F20, in order.
private let functionKeys = Dictionary(
    uniqueKeysWithValues: [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14,
        kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ].enumerated().map { number, keyCode in (keyCode, "F\(number + 1)") })

/// Keys that print no character, named the way macOS menus show them.
private let namedKeys: [Int: String] = [
    kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
    kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
    kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_Help: "Help", kVK_ANSI_KeypadEnter: "⌤", kVK_ANSI_KeypadClear: "⌧",
    kVK_JIS_Eisu: "英数", kVK_JIS_Kana: "かな",
]

/// A global shortcut as Carbon registers it: a key position and modifier keys. Its label is derived from the
/// current keyboard layout, so it shows what the key prints on the user's keyboard. Saved as its key code and
/// modifiers; the label 0.1.0 also saved is ignored.
package struct Shortcut: Codable, Hashable, Sendable {
    /// The virtual key code: a position on the keyboard, whatever character the layout puts there.
    package let keyCode: UInt32
    /// Carbon modifier bits: `controlKey`, `optionKey`, `shiftKey` and `cmdKey`.
    package let modifiers: UInt32

    /// Takes Carbon's key code and modifier constants, which Swift imports as Int.
    package init(keyCode: Int, modifiers: Int) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = UInt32(modifiers)
    }

    /// The key and the modifiers held with it, any or none.
    package init(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        self.init(
            keyCode: Int(event.keyCode),
            modifiers: modifierKeys.filter { flags.contains($0.flag) }.reduce(0) { $0 | $1.carbon })
    }

    /// The saved shortcut as it is, or nil when none was saved or the saved value does not decode.
    package static func load(from defaults: UserDefaults = .standard) -> Shortcut? {
        defaults.data(forKey: defaultsKey).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
    }

    /// Saves `shortcut`, or removes the saved one when it is nil.
    package static func save(_ shortcut: Shortcut?, to defaults: UserDefaults = .standard) {
        defaults.set(shortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: defaultsKey)
    }
}

// MARK: - Label

extension Shortcut {
    /// The modifiers and the key as the current keyboard layout prints it, such as ⌥⌘B.
    @MainActor package var label: String { label(using: .current) }

    @MainActor func label(using layout: KeyboardLayout?) -> String {
        let held = modifierKeys.filter { modifiers & UInt32($0.carbon) != 0 }.map(\.symbol).joined()
        let key = Int(keyCode)
        let name = functionKeys[key] ?? namedKeys[key] ?? layout?.character(for: keyCode).map(Self.keyCap) ?? "Key \(keyCode)"
        return held + name
    }

    /// Letters read as capitals, as on the key caps and in menus. "ß" stays as it is rather than becoming "SS".
    private static func keyCap(_ character: String) -> String {
        let upper = character.uppercased()
        return upper.count == character.count ? upper : character
    }
}
