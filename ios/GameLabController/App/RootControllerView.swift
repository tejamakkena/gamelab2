import SwiftUI

struct RootControllerView: View {
    @StateObject private var vm = ControllerRootViewModel()

    var body: some View {
        ZStack {
            Color(hex: "0a0a14").ignoresSafeArea()

            switch vm.screen {
            case .join:
                JoinRoomView(onJoin: vm.joinRoom)

            case .waiting(let room):
                WaitingView(room: room, onReady: vm.markReady)

            case .playing(let room, let privateData):
                ControllerGameView(
                    room: room,
                    privateData: privateData,
                    onAction: vm.sendAction
                )

            case .results(let room):
                ResultsControllerView(room: room, onLeave: vm.leaveRoom)
            }
        }
        .environmentObject(vm)
        .animation(.easeInOut(duration: 0.3), value: vm.screen.id)
    }
}

// MARK: - Screen enum

enum ControllerScreen: Equatable {
    case join
    case waiting(Room)
    case playing(Room, [String: Any])
    case results(Room)

    static func == (lhs: ControllerScreen, rhs: ControllerScreen) -> Bool {
        lhs.id == rhs.id
    }

    var id: String {
        switch self {
        case .join:            return "join"
        case .waiting(let r): return "waiting-\(r.code)"
        case .playing(let r, _): return "playing-\(r.code)"
        case .results(let r): return "results-\(r.code)"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ControllerRootViewModel: ObservableObject {
    @Published var screen: ControllerScreen = .join

    private let socket = GameSocketManager.shared
    private var playerID = AppConstants.deviceID

    init() {
        socket.on(.roomUpdated) { [weak self] (room: Room) in
            guard let self else { return }
            switch room.state {
            case .lobby:   self.screen = .waiting(room)
            case .results: self.screen = .results(room)
            case .playing: break  // wait for privateState before switching
            }
        }

        socket.on(.privateState) { [weak self] (r: PrivateStateResponse) in
            guard let self, r.playerID == self.playerID else { return }
            if case .waiting(let room) = self.screen {
                self.screen = .playing(room, r.privateData.mapValues(\.value))
            } else if case .playing(let room, _) = self.screen {
                self.screen = .playing(room, r.privateData.mapValues(\.value))
            }
        }
    }

    func joinRoom(code: String, name: String) {
        let payload = JoinRoomPayload(
            roomCode: code.uppercased(),
            playerName: name,
            playerID: playerID,
            isTV: false
        )
        socket.emit(.joinRoom, payload: payload)
    }

    func markReady() {
        guard case .waiting(let room) = screen else { return }
        socket.emit(.playerReady, payload: ["roomCode": room.code, "playerID": playerID])
    }

    func sendAction(action: String, data: [String: Any]) {
        guard case .playing(let room, _) = screen else { return }
        let payload = GameActionPayload(
            roomCode: room.code,
            playerID: playerID,
            action: action,
            data: data.mapValues { AnyCodable($0) }
        )
        socket.emit(.gameAction, payload: payload)
    }

    func leaveRoom() {
        screen = .join
    }
}
