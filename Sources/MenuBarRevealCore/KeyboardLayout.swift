import Carbon.HIToolbox
import Foundation

/// A keyboard layout's key table, used to name a key position by what it prints on the user's keyboard.
/// Text Input Sources and the keyboard type must be read on the main thread.
@MainActor
struct KeyboardLayout {
    private let table: Data
    /// The physical keyboard, which can pick a different table within the layout.
    private let keyboardType: UInt32

    /// The layout in use. Input methods without a key table of their own, such as Japanese, type through the
    /// ASCII capable layout, so that one names the keys.
    static var current: KeyboardLayout? {
        KeyboardLayout(TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue())
            ?? KeyboardLayout(TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue())
    }

    /// The keyboard type defaults to the one attached; 0 picks the layout's default table.
    init?(_ source: TISInputSource?, keyboardType: UInt32 = UInt32(LMGetKbdType())) {
        guard let source, let table = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        self.table = Unmanaged<CFData>.fromOpaque(table).takeUnretainedValue() as Data
        self.keyboardType = keyboardType
    }

    /// What the key prints with no modifiers. A dead key gives its accent instead of waiting for the next key.
    /// Nil for a key code too large for `UCKeyTranslate`.
    func character(for keyCode: UInt32) -> String? {
        table.withUnsafeBytes { bytes -> String? in
            guard let keyCode = UInt16(exactly: keyCode),
                let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return nil }
            var deadKeyState: UInt32 = 0
            var characters = [UniChar](repeating: 0, count: 255)
            var length = 0
            let status = UCKeyTranslate(
                layout, keyCode, UInt16(kUCKeyActionDisplay), 0, keyboardType,
                OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, characters.count, &length, &characters)
            guard status == noErr, length > 0 else { return nil }
            let character = String(utf16CodeUnits: characters, count: length)
            // Keys without a printed character translate to control codes.
            return character.unicodeScalars.contains { $0.properties.generalCategory == .control } ? nil : character
        }
    }
}
