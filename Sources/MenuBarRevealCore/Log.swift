import os

/// The app's unified log, under its bundle identifier: `log stream --predicate 'subsystem == "com.srobinson.menubar-reveal"'`.
/// Messages carry status codes and error domains and codes, never descriptions or user data, so their values are public.
extension Logger {
    package static let shortcut = Logger(subsystem: subsystem, category: "shortcut")
    package static let loginItem = Logger(subsystem: subsystem, category: "login-item")
    package static let menuBar = Logger(subsystem: subsystem, category: "menu-bar")
}

/// CFBundleIdentifier in Info.plist.
private let subsystem = "com.srobinson.menubar-reveal"
