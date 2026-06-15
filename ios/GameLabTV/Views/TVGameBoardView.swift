import SwiftUI

/// Routes to the correct game board based on the room's gameID.
struct TVGameBoardView: View {
    let room: Room

    var body: some View {
        switch room.gameID {
        case .heist:       TVHeistBoardView(room: room)
        case .trivia:      TVTriviaBoardView(room: room)
        case .poker:       TVPokerBoardView(room: room)
        case .tambola:     TVTambolaBoardView(room: room)
        case .stockPanic:  TVStockPanicBoardView(room: room)
        case .mindMeld:    TVMindMeldBoardView(room: room)
        case .hotGrid:     TVHotGridBoardView(room: room)
        case .speedSculptor: TVSpeedSculptorBoardView(room: room)
        default:
            // Fallback web view for games not yet ported natively
            TVWebGameBoardView(room: room)
        }
    }
}
