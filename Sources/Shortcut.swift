import AppKit
import Carbon.HIToolbox

private let defaultsKey = "shortcut"

private let modifierSymbols: [(flag: NSEvent.ModifierFlags, carbon: Int, symbol: String)] = [
    (.control, controlKey, "⌃"),
    (.option, optionKey, "⌥"),
    (.shift, shiftKey, "⇧"),
    (.command, cmdKey, "⌘"),
]

private let functionKeyNames: [Int: String] = [
    kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
    kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
]

private let specialKeyNames: [Int: String] = [
    kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
    kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
]

struct Shortcut: Codable {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String

    static let standard = Shortcut(keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(optionKey), label: "⌥`")

    static func load() -> Shortcut {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode(Shortcut.self, from: data) else { return .standard }
        return saved
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: defaultsKey)
    }
}

extension Shortcut {
    /// Fails unless the key is a function key or is held with Command, Control or Option.
    init?(event: NSEvent) {
        let code = Int(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard functionKeyNames[code] != nil || !flags.isDisjoint(with: [.command, .control, .option]),
              let key = functionKeyNames[code] ?? specialKeyNames[code] ?? event.characters(byApplyingModifiers: [])?.uppercased(),
              !key.isEmpty else { return nil }

        let held = modifierSymbols.filter { flags.contains($0.flag) }
        self.init(
            keyCode: UInt32(code),
            modifiers: UInt32(held.reduce(0) { $0 | $1.carbon }),
            label: held.map(\.symbol).joined() + key
        )
    }
}
