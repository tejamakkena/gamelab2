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

    /// `TVGameSelectionView` gives the first game card (`GameID.allCases.first`,
    /// which is `.trivia`) `.prefersDefaultFocus` in its own focus scope, so it
    /// already has focus the instant the game-selection screen appears --
    /// no D-pad navigation sequence needs to be reproduced here just to reach
    /// a card before pressing Select.
    private func launchOnTriviaCard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        let triviaCard = app.buttons["gameCard_trivia"]
        XCTAssertTrue(
            triviaCard.waitForExistence(timeout: 10),
            "gameCard_trivia never appeared -- the game-selection screen didn't load."
        )
        return app
    }

    func testSelectPressFiresPickForFocusedCard() {
        let app = launchOnTriviaCard()

        remote.press(.select)

        let debugLabel = app.staticTexts["debugLastInput"]
        XCTAssertTrue(
            debugLabel.waitForExistence(timeout: 5),
            "debugLastInput never appeared after pressing Select -- Select is not reaching pick(_:)."
        )
        XCTAssertEqual(debugLabel.label, "Select fired: trivia")
    }

    func testPlayPausePressFiresPickForFocusedCard() {
        let app = launchOnTriviaCard()

        remote.press(.playPause)

        let debugLabel = app.staticTexts["debugLastInput"]
        XCTAssertTrue(
            debugLabel.waitForExistence(timeout: 5),
            "debugLastInput never appeared after pressing Play/Pause -- Play/Pause is not reaching pick(_:)."
        )
        XCTAssertEqual(debugLabel.label, "Play/Pause fired: trivia")
    }
}
