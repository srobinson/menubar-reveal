import CoreGraphics
import Testing

@testable import MenuBarRevealCore

/// Records each call in place of SkyLight, so no display's menu bar changes.
@MainActor
struct MenuBarOverrideTests {
    private final class Calls {
        var made: [(display: CGDirectDisplayID, shown: Bool)] = []
        var displays: [CGDirectDisplayID] = [1, 2]
        /// Displays SkyLight refuses.
        var failing: Set<CGDirectDisplayID> = []
    }

    private let calls = Calls()

    private func makeOverride() -> MenuBarOverride {
        MenuBarOverride(
            set: { [calls] display, shown in
                calls.made.append((display, shown))
                return !calls.failing.contains(display)
            }, displays: { [calls] in calls.displays })
    }

    private var offDisplays: Set<CGDirectDisplayID> { Set(calls.made.filter { !$0.shown }.map(\.display)) }

    @Test func showSetsTheOverrideOnOnItsDisplayOnly() {
        let menuBar = makeOverride()
        #expect(menuBar.show(on: 2))
        #expect(menuBar.isShown)
        #expect(calls.made.map(\.display) == [2])
        #expect(calls.made.map(\.shown) == [true])
    }

    /// The next press shows again rather than hiding a bar that never came down.
    @Test func aRefusedShowRecordsNothing() {
        let menuBar = makeOverride()
        calls.failing = [2]
        #expect(!menuBar.show(on: 2))
        #expect(!menuBar.isShown)
    }

    /// As at launch: nothing shown, yet every display is set off, which clears an override a crash left on.
    @Test func hideSetsEveryDisplayOffEvenWhenNothingIsShown() {
        let menuBar = makeOverride()
        menuBar.hide()
        #expect(!menuBar.isShown)
        #expect(calls.made.count == 2)
        #expect(offDisplays == [1, 2])
    }

    @Test func hideSetsEachDisplayOffOnce() {
        let menuBar = makeOverride()
        #expect(menuBar.show(on: 1))
        calls.made.removeAll()
        menuBar.hide()
        #expect(!menuBar.isShown)
        #expect(calls.made.count == 2)
        #expect(offDisplays == [1, 2])
    }

    /// A display unplugged while the bar shows on it is still set off.
    @Test func hideSetsTheShownDisplayOffAfterItIsGone() {
        let menuBar = makeOverride()
        #expect(menuBar.show(on: 3))
        menuBar.hide()
        #expect(offDisplays == [1, 2, 3])
    }

    /// An attached display SkyLight will not clear stays shown, so the next press retries the hide.
    @Test func aFailedClearIsRetried() {
        let menuBar = makeOverride()
        #expect(menuBar.show(on: 2))
        calls.failing = [2]
        menuBar.hide()
        #expect(menuBar.isShown)
        calls.failing = []
        calls.made.removeAll()
        menuBar.hide()
        #expect(!menuBar.isShown)
        #expect(offDisplays == [1, 2])
    }

    /// A detached display SkyLight will not clear is forgotten, so the next press shows the bar on another display.
    @Test func aFailedClearOfADetachedDisplayStillHides() {
        let menuBar = makeOverride()
        #expect(menuBar.show(on: 3))
        calls.failing = [3]
        menuBar.hide()
        #expect(!menuBar.isShown)
        #expect(menuBar.show(on: 1))
        #expect(menuBar.isShown)
    }
}
