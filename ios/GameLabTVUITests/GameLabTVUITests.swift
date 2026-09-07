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
        return triviaCard
    }

    func testSelectPressFiresPickForFocusedCard() {
        let app = XCUIApplication()
        app.launch()
        _ = focusedTriviaCard(in: app)

        remote.press(.select)

        let debugLabel = app.staticTexts["debugLastInput"]
        XCTAssertTrue(
            debugLabel.waitForExistence(timeout: 5),
            "debugLastInput never appeared after pressing Select on the focused trivia card -- " +
            "Select is not reaching pick(_:)."
        )
        XCTAssertEqual(debugLabel.label, "Select fired: trivia")
    }

    func testPlayPausePressFiresPickForFocusedCard() {
        let app = XCUIApplication()
        app.launch()
        _ = focusedTriviaCard(in: app)

        remote.press(.playPause)

        let debugLabel = app.staticTexts["debugLastInput"]
        XCTAssertTrue(
            debugLabel.waitForExistence(timeout: 5),
            "debugLastInput never appeared after pressing Play/Pause on the focused trivia card -- " +
            "Play/Pause is not reaching pick(_:)."
        )
        XCTAssertEqual(debugLabel.label, "Play/Pause fired: trivia")
    }
}
