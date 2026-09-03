import SwiftUI

struct RootTVView: View {
    @StateObject private var vm = TVRootViewModel()

    var body: some View {
        ZStack {
            // Background gradient — persists across all screens
            LinearGradient(
                colors: [Color(hex: "0d0d1a"), Color(hex: "1a0d2e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch vm.screen {
            case .gameSelection:
                TVGameSelectionView(onSelect: vm.createRoom,
                                    onSelectSolo: vm.createSoloRoom)

            case .lobby(let room):
                TVLobbyView(room: room, onStart: vm.startGame)

            case .playing(let room):
                TVGameBoardView(room: room)

            case .results(let room):
                TVResultsView(room: room, onPlayAgain: vm.returnToSelection)
            }
        }
        .environmentObject(vm)
    }
}

// MARK: - View Model

enum TVScreen {
    case gameSelection
    case lobby(Room)
    case playing(Room)
    case results(Room)
}

@MainActor
final class TVRootViewModel: ObservableObject {
    @Published var screen: TVScreen = .gameSelection

    /// True while a remote-only game is running with no phones connected.
    @Published private(set) var isSolo = false

    private let socket = GameSocketManager.shared

    init() {
        socket.on(.roomUpdated) { [weak self] (response: Room) in
            guard let self else { return }
            switch response.state {
            case .lobby:
                self.screen = .lobby(response)
                if self.isSolo {
                    self.socket.emit(.startGame, payload: ["roomCode": response.code])
                }
            case .playing: self.screen = .playing(response)
            case .results: self.screen = .results(response)
            }
        }
    }

    func createRoom(game: GameID) {
        isSolo = false
        let payload = CreateRoomPayload(
            gameID: game.rawValue,
            hostName: "TV",
            hostID: AppConstants.deviceID
        )
        socket.emit(.createRoom, payload: payload)
    }

    /// Start a game with no phones at all — the TV is the only player and the
    /// Siri Remote is the controller.
    func createSoloRoom(game: GameID) {
        isSolo = true
        socket.emit(.createRoom, payload: SoloRoomPayload(
            gameID: game.rawValue,
            hostName: "Player 1",
            hostID: AppConstants.deviceID,
            solo: true
        ))
    }

    func startGame() {
        guard case .lobby(let room) = screen else { return }
        socket.emit(.startGame, payload: ["roomCode": room.code])
    }

    /// Send a game action on the TV's own behalf. Used by the remote-controlled
    /// solo games, which have no phone to send for them.
    func sendAction(_ action: String, _ data: [String: Any] = [:]) {
        let code: String
        switch screen {
        case .playing(let room), .lobby(let room), .results(let room): code = room.code
        case .gameSelection: return
        }
        socket.emit(.gameAction, payload: GameActionPayload(
            roomCode: code,
            playerID: AppConstants.deviceID,
            action: action,
            data: data.mapValues { AnyCodable($0) }
        ))
    }

    func returnToSelection() {
        isSolo = false
        screen = .gameSelection
    }
}

/// create_room with the solo flag. Kept separate from CreateRoomPayload so the
/// shared struct stays exactly what the phone sends.
private struct SoloRoomPayload: Encodable {
    let gameID: String
    let hostName: String
    let hostID: String
    let solo: Bool
}
