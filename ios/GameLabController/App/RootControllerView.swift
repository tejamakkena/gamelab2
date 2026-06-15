import SwiftUI

struct RootControllerView: View {
    @StateObject private var vm = ControllerRootViewModel()

    var body: some View {
        ZStack {
            Color(hex: "0a0a14").ignoresSafeArea()

            switch vm.screen {
            case .join:
                JoinRoomView(onJoin: vm.joinRoom)

            case .loading:
                LoadingJoinView()

            case .error(let message):
                ErrorJoinView(message: message, onRetry: vm.returnToJoin)

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
    case loading
    case error(String)
    case waiting(Room)
    case playing(Room, [String: Any])
    case results(Room)

    static func == (lhs: ControllerScreen, rhs: ControllerScreen) -> Bool {
        lhs.id == rhs.id
    }

    var id: String {
        switch self {
        case .join:              return "join"
        case .loading:           return "loading"
        case .error(let msg):    return "error-\(msg)"
        case .waiting(let r):    return "waiting-\(r.code)"
        case .playing(let r, _): return "playing-\(r.code)"
        case .results(let r):    return "results-\(r.code)"
        }
    }
}

// MARK: - Loading & Error views

struct LoadingJoinView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ProgressView().scaleEffect(2.2).tint(.cyan)
            Text("Joining room" + String(repeating: ".", count: dotCount))
                .font(.title3).foregroundColor(.white.opacity(0.7))
                .onReceive(timer) { _ in dotCount = (dotCount + 1) % 4 }
            Spacer()
        }
    }
}

struct ErrorJoinView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60)).foregroundColor(.red)
            Text(message)
                .font(.title3.bold()).foregroundColor(.white)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .font(.headline).frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.cyan))
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain).padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ControllerRootViewModel: ObservableObject {
    @Published var screen: ControllerScreen = .join

    private let socket = GameSocketManager.shared
    private let playerID = AppConstants.deviceID

    init() {
        // Server confirms the join — transition to lobby
        socket.on(.roomJoined) { [weak self] (response: RoomJoinedResponse) in
            guard let self else { return }
            self.screen = .waiting(response.room)
        }

        // Room state changes (more players join, game ends, etc.)
        socket.on(.roomUpdated) { [weak self] (room: Room) in
            guard let self else { return }
            switch room.state {
            case .lobby:
                if case .waiting = self.screen { self.screen = .waiting(room) }
            case .results:
                self.screen = .results(room)
            case .playing:
                break  // privateState event drives the playing transition
            }
        }

        // Private screen update — also drives transition from waiting → playing
        socket.on(.privateState) { [weak self] (r: PrivateStateResponse) in
            guard let self, r.playerID == self.playerID else { return }
            switch self.screen {
            case .waiting(let room), .playing(let room, _):
                self.screen = .playing(room, r.privateData.mapValues(\.value))
            default:
                break
            }
        }

        // Server-side errors (room not found, room full, invalid action, etc.)
        socket.on(.error) { [weak self] (r: ErrorResponse) in
            guard let self else { return }
            // Only show error overlay from loading state; in-game errors stay silent
            if case .loading = self.screen {
                self.screen = .error(r.message)
            }
        }
    }

    func joinRoom(code: String, name: String) {
        screen = .loading
        socket.emit(.joinRoom, payload: JoinRoomPayload(
            roomCode: code.uppercased(),
            playerName: name,
            playerID: playerID,
            isTV: false
        ))
    }

    func markReady() {
        guard case .waiting(let room) = screen else { return }
        socket.emit(.playerReady, payload: ["roomCode": room.code, "playerID": playerID])
    }

    func sendAction(action: String, data: [String: Any]) {
        guard case .playing(let room, _) = screen else { return }
        socket.emit(.gameAction, payload: GameActionPayload(
            roomCode: room.code,
            playerID: playerID,
            action: action,
            data: data.mapValues { AnyCodable($0) }
        ))
    }

    func leaveRoom() {
        switch screen {
        case .playing(let room, _), .waiting(let room):
            socket.emit(.leaveRoom, payload: ["roomCode": room.code, "playerID": playerID])
        default:
            break
        }
        screen = .join
    }

    func returnToJoin() {
        screen = .join
    }
}
