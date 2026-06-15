import SwiftUI

/// Routes to the correct game board based on the room's gameID.
struct TVGameBoardView: View {
    let room: Room

    var body: some View {
        switch room.gameID {
        // Invented games — full implementations
        case .heist:         TVHeistBoardView(room: room)
        case .stockPanic:    TVStockPanicBoardView(room: room)
        case .mindMeld:      TVMindMeldBoardView(room: room)
        case .hotGrid:       TVHotGridBoardView(room: room)
        case .speedSculptor: TVSpeedSculptorBoardView(room: room)

        // Knowledge
        case .trivia:        TVTriviaBoardView(room: room)
        case .digitGuess:    TVDigitGuessBoardView(room: room)

        // Casino
        case .poker:         TVPokerBoardView(room: room)
        case .tambola:       TVTambolaBoardView(room: room)
        case .roulette:      TVRouletteBoardView(room: room)

        // Social
        case .mafia:         TVMafiaBoardView(room: room)
        case .rajaMantri:    TVRajaMantriBoard(room: room)

        // Strategy / Board
        case .chess:         TVWebGameBoardView(room: room)   // web canvas via WKWebView
        case .connectFour:   TVConnect4BoardView(room: room)
        case .memory:        TVMemoryBoardView(room: room)
        case .snakeLadder:   TVWebGameBoardView(room: room)   // web canvas

        // Action
        case .pong:          TVPongBoardView(room: room)
        }
    }
}
