import Foundation

struct Room: Codable, Equatable {
    let code: String
    let gameID: GameID
    var players: [Player]
    var state: RoomState

    var hostPlayerID: String { players.first?.id ?? "" }
}

struct Player: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var isReady: Bool
    var score: Int
    var isHost: Bool
}

enum RoomState: String, Codable {
    case lobby    = "lobby"
    case playing  = "playing"
    case results  = "results"
}
