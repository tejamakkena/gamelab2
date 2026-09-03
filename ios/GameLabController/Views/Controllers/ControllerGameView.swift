import SwiftUI

/// Routes the phone to the correct controller UI based on the game.
struct ControllerGameView: View {
    let room: Room
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    var body: some View {
        switch room.gameID {
        // Invented games
        case .heist:         HeistControllerView(privateData: privateData, onAction: onAction)
        case .stockPanic:    StockPanicControllerView(privateData: privateData, onAction: onAction)
        case .mindMeld:      MindMeldControllerView(privateData: privateData, onAction: onAction)
        case .hotGrid:       HotGridControllerView(privateData: privateData, onAction: onAction)
        case .speedSculptor: SpeedSculptorControllerView(privateData: privateData, onAction: onAction)

        // Knowledge
        case .trivia:        TriviaControllerView(privateData: privateData, onAction: onAction)
        case .digitGuess:    DigitGuessControllerView(privateData: privateData, onAction: onAction)

        // Casino
        case .poker:         PokerControllerView(privateData: privateData, onAction: onAction)
        case .tambola:       TambolaControllerView(privateData: privateData, onAction: onAction)
        case .roulette:      RouletteControllerView(privateData: privateData, onAction: onAction)

        // Social
        case .mafia:         MafiaControllerView(privateData: privateData, onAction: onAction)
        case .rajaMantri:    RajaMantriControllerView(privateData: privateData, onAction: onAction)

        // Strategy / Board
        case .chess:         ChessControllerView(privateData: privateData, onAction: onAction)
        case .connectFour:   Connect4ControllerView(privateData: privateData, onAction: onAction)
        case .memory:        MemoryControllerView(privateData: privateData, onAction: onAction)
        case .snakeLadder:   ShakeToRollControllerView(privateData: privateData, onAction: onAction)

        // Action
        case .pong:          PongControllerView(privateData: privateData, onAction: onAction)
        }
    }
}
