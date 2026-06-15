import SwiftUI

/// Routes the phone to the correct controller UI based on the game.
struct ControllerGameView: View {
    let room: Room
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    var body: some View {
        switch room.gameID {
        case .heist:
            HeistControllerView(privateData: privateData, onAction: onAction)
        case .trivia:
            TriviaControllerView(privateData: privateData, onAction: onAction)
        case .poker:
            PokerControllerView(privateData: privateData, onAction: onAction)
        case .tambola:
            TambolaControllerView(privateData: privateData, onAction: onAction)
        case .stockPanic:
            StockPanicControllerView(privateData: privateData, onAction: onAction)
        case .mindMeld:
            MindMeldControllerView(privateData: privateData, onAction: onAction)
        case .hotGrid:
            HotGridControllerView(privateData: privateData, onAction: onAction)
        case .speedSculptor:
            SpeedSculptorControllerView(privateData: privateData, onAction: onAction)
        case .snakeLadder:
            ShakeToRollControllerView(privateData: privateData, onAction: onAction)
        case .pong:
            PongControllerView(privateData: privateData, onAction: onAction)
        default:
            GenericTapControllerView(room: room, privateData: privateData, onAction: onAction)
        }
    }
}
