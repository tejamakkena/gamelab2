import XCTest

/// Automates the exact question that took 15 rounds of manual on-device
/// testing to even diagnose: does pressing Select (or Play/Pause) on the
/// Siri Remote actually invoke a game card's action on the game-selection
/// screen at all?
///
/// This deliberately tests nothing else. It needs no server connection and
/// no real navigation past the selection screen to pass -- it only checks
/// "does pressing this remote button invoke the button's/command's closure",
/// via the `debugLastInput` diagnostic in TVGameSelectionView (compiled in
/// only for `#if DEBUG` builds, which is what this test target -- and every
/// other Simulator build in this repo -- runs as). Room creation and the
/// server round-trip are out of scope here; no backend runs in CI.
final class GameLabTVUITests: XCTestCase {

    private let remote = XCUIRemote.shared

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches fresh and returns the trivia game card with focus actually
    /// on it, so a remote-button press below can be attributed to that card.
    ///
    /// TVGameSelectionView originally tried `.prefersDefaultFocus` for this,
    /// but this test's own first real CI run showed Select/Play-Pause never
    /// reaching `pick(_:)` at all -- consistent with a known tvOS gotcha
    /// where that modifier can silently lose against a `LazyVGrid`'s own
    /// child-layout timing (see the "ScrollView and prefersDefaultFocus
    /// currently incompatible?" report on Apple's developer forums). The
    /// view now assigns `$focusedGame` imperatively on `.onAppear` instead,
    /// which doesn't have the same race. This helper keeps a real `hasFocus`
    /// check (and a single Right-press nudge if it's somehow still false)
    /// as a defensive fallback regardless -- so a future focus-assignment
    /// regression fails loudly here with a clear message, rather than this
    /// test silently pressing Select/Play-Pause against the wrong element.
    private func focusedTriviaCard(in app: XCUIApplication) -> XCUIElement {
        let triviaCard = app.buttons["gameCard_trivia"]
        XCTAssertTrue(
            triviaCard.waitForExistence(timeout: 10),
            "gameCard_trivia never appeared -- the game-selection screen didn't load."
        )

        if !triviaCard.hasFocus {
            remote.press(.right)
        }

        let gainedFocus = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasFocus == true"),
            object: triviaCard
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [gainedFocus], timeout: 3),
            .completed,
            "gameCard_trivia never gained focus, even after pressing Right -- can't attribute a " +
            "remote-button press to it without that."
        )

        // A remote press sent the instant focus lands can race the focus
        // engine's own settle/animation -- observed directly on a PR that
        // touched nothing in this view or its test: identical code that had
        // passed cleanly on the previous run (hasFocus confirmed true, then
        // immediately "Pressing Select/Play-Pause button", then nothing)
        // failed both tests the very next run. Giving the UI a brief beat to
        // settle before the first press removes that race without weakening
        // what's actually being asserted below.
        Thread.sleep(forTimeInterval: 2.0)
        return triviaCard
    }

    /// Presses `button` on the remote and waits for `debugLastInput` to show
    /// `expectedLabel`, retrying the press itself (not just the wait) a
    /// few times, with a growing gap between attempts, before failing.
    ///
    /// This is deliberately about tolerating a dropped/raced Simulator
    /// remote-input delivery, not about tolerating a real regression: a
    /// genuine break in the Select/Play-Pause -> pick(_:) path (the exact
    /// class of bug this whole test exists to catch) fails identically on
    /// every attempt, so retrying costs nothing when the app is actually
    /// broken and only helps when the Simulator dropped one input event.
    ///
    /// A first version of this retried 3 times with a flat 0.5s gap and
    /// still failed identically on every attempt, in both test methods,
    /// across two independent app launches in the same job -- evidence
    /// against a single dropped event and consistent with something
    /// systemic to that job's Simulator instance taking longer than 0.5s
    /// bursts to recover from (background indexing, scene-graph setup
    /// finishing late, etc.). The re-focus check before each retry guards
    /// against a still-unexplored possibility: something knocking focus
    /// off the card between attempts, which a bare re-press could never
    /// recover from on its own.
    private func pressAndExpectDebugLabel(
        _ button: XCUIRemote.Button,
        expectedLabel: String,
        in app: XCUIApplication,
        attempts: Int = 3
    ) {
        let debugLabel = app.staticTexts["debugLastInput"]
        let triviaCard = app.buttons["gameCard_trivia"]
        for attempt in 1...attempts {
            if !triviaCard.hasFocus {
                remote.press(.right)
                Thread.sleep(forTimeInterval: 1.0)
            }
            remote.press(button)
            if debugLabel.waitForExistence(timeout: 5) {
                XCTAssertEqual(debugLabel.label, expectedLabel)
                return
            }
            if attempt < attempts {
                Thread.sleep(forTimeInterval: Double(attempt) * 2.0)
            }
        }
        XCTFail(
            "debugLastInput never appeared after \(attempts) attempts pressing " +
            "\(button) on the focused trivia card -- \(button) is not reaching pick(_:)."
        )
    }

    func testSelectPressFiresPickForFocusedCard() {
        let app = XCUIApplication()
        app.launch()
        _ = focusedTriviaCard(in: app)

        pressAndExpectDebugLabel(.select, expectedLabel: "Select fired: trivia", in: app)
    }

    func testPlayPausePressFiresPickForFocusedCard() {
        let app = XCUIApplication()
        app.launch()
        _ = focusedTriviaCard(in: app)

        pressAndExpectDebugLabel(.playPause, expectedLabel: "Play/Pause fired: trivia", in: app)
    }
}
