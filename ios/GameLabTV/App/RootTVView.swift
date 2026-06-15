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
                TVGameSelectionView(onSelect: vm.createRoom)

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

    private let socket = GameSocketManager.shared

    init() {
        socket.on(.roomUpdated) { [weak self] (response: Room) in
            guard let self else { return }
            switch response.state {
            case .lobby:   self.screen = .lobby(response)
            case .playing: self.screen = .playing(response)
            case .results: self.screen = .results(response)
            }
        }
    }

    func createRoom(game: GameID) {
        let payload = CreateRoomPayload(
            gameID: game.rawValue,
            hostName: "TV",
            hostID: AppConstants.deviceID
        )
        socket.emit(.createRoom, payload: payload)
    }

    func startGame() {
        guard case .lobby(let room) = screen else { return }
        socket.emit(.startGame, payload: ["roomCode": room.code])
    }

    func returnToSelection() {
        screen = .gameSelection
    }
}
