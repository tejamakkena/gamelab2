import SwiftUI

struct RootTVView: View {
    @StateObject private var vm = TVRootViewModel()

    // Menu on the Siri Remote had no handler anywhere in this app, so tvOS
    // fell back to its own default: exit straight to the system Home
    // Screen, mid-game, with no warning -- reported directly. .onExitCommand
    // below intercepts it instead. Gated to "not already on the selection
    // screen": at the top level, Menu exiting the app to the real tvOS Home
    // Screen is normal, expected platform behavior worth leaving alone.
    @State private var showQuitConfirm = false

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
                TVLobbyView(room: room, isSolo: vm.isSolo, onStart: vm.startGame)

            case .playing(let room):
                TVGameBoardView(room: room)

            case .results(let room):
                TVResultsView(room: room, onPlayAgain: vm.returnToSelection)
            }
        }
        .environmentObject(vm)
        // onExitCommand only fires "while the view has focus" (Apple's own
        // docs) -- routed through the focus responder chain like every
        // other remote command. Confirmed directly on real hardware: Menu
        // still exited the whole app on Atlas, which (like Trivia, Poker,
        // and every other display-only, non-remote-controlled TV board) has
        // zero focusable elements of its own, so there was nothing for the
        // focus engine to route Menu through -- it fell back to tvOS's own
        // default (exit to the system Home Screen) every time. Making the
        // whole screen itself focusable gives it a guaranteed fallback focus
        // target on exactly those screens, without taking focus away from a
        // screen's own real controls (the selection grid's cards, the
        // lobby's Start button, a solo game's remote input) -- SwiftUI still
        // prefers a more specific descendant's focusable content when one
        // exists. .focusEffectDisabled() only suppresses this fallback's own
        // default focus chrome (a full-screen halo would be worse than the
        // bug); it does not affect any other view's focus effect.
        .focusable(true)
        .focusEffectDisabled()
        .onExitCommand {
            switch vm.screen {
            case .gameSelection:
                break   // Let Menu do its normal, expected thing here.
            case .results:
                // Nothing left to lose by leaving -- same as tapping "Play
                // Again" on TVResultsView, just via the remote's Menu button.
                vm.quitToSelection()
            case .lobby, .playing:
                showQuitConfirm = true
            }
        }
        .confirmationDialog(
            "Quit to Home Screen?",
            isPresented: $showQuitConfirm,
            titleVisibility: .visible
        ) {
            Button("Yes, Quit to Home Screen", role: .destructive) {
                vm.quitToSelection()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll leave this game and return to the game list. Anyone else playing will be disconnected.")
        }
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

    /// Menu-button quit, after the user confirms. Tells the server the TV is
    /// leaving (so the room doesn't linger forever waiting for a board that's
    /// gone -- see room_manager.detach_sid) before dropping back to the
    /// selection screen locally.
    func quitToSelection() {
        let code: String?
        switch screen {
        case .lobby(let room), .playing(let room), .results(let room): code = room.code
        case .gameSelection: code = nil
        }
        if let code {
            socket.emit(.leaveRoom, payload: ["roomCode": code])
        }
        returnToSelection()
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
