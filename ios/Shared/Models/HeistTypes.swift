import SwiftUI

// MARK: - Heist — types shared by the TV board and the phone controllers
//
// GameLabTV and GameLabController are separate Xcode targets that only see
// their own folder plus Shared/ (see project.yml). HeistControllerView reads
// role, phase, and position live from the server's privateData, so those
// three types have to live here rather than alongside the TV board.

struct GridPos: Hashable, Codable {
    let col: Int
    let row: Int
}

enum HeistPhase: String {
    case guardSets  = "guard_sets"
    case thievesMove = "thieves_move"
    case reveal     = "reveal"

    var label: String {
        switch self {
        case .guardSets:   return "Guard Setting Cameras"
        case .thievesMove: return "Thieves Moving"
        case .reveal:      return "Reveal"
        }
    }
    var color: Color {
        switch self {
        case .guardSets:   return .red
        case .thievesMove: return .cyan
        case .reveal:      return .yellow
        }
    }
}

enum HeistRole { case `guard`, thief }
