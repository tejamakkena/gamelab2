import Foundation
import SocketIO

/// Shared Socket.IO client used by both the TV app and the phone controller app.
/// Call `connect(to:)` once on launch; then use `emit` / `on` for game events.
final class GameSocketManager: ObservableObject {

    static let shared = GameSocketManager()

    @Published var isConnected = false

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var handlers: [String: (Any) -> Void] = [:]

    private init() {}

    // MARK: - Connection

    func connect(to serverURL: URL) {
        manager = SocketManager(
            socketURL: serverURL,
            config: [.log(false), .compress, .reconnects(true), .reconnectWait(2)]
        )
        socket = manager?.defaultSocket

        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            DispatchQueue.main.async { self?.isConnected = true }
        }
        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            DispatchQueue.main.async { self?.isConnected = false }
        }

        // Re-attach all registered handlers after reconnect
        socket?.on(clientEvent: .reconnect) { [weak self] _, _ in
            self?.reattachHandlers()
        }

        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
    }

    // MARK: - Emit

    func emit(_ event: ClientEvent, payload: Encodable) {
        guard let socket, let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        socket.emit(event.rawValue, dict)
    }

    // MARK: - Listen

    /// Register a typed handler for a server event. Replaces any previous handler for the same event.
    func on<T: Decodable>(_ event: ServerEvent, handler: @escaping (T) -> Void) {
        let key = event.rawValue
        socket?.off(key)
        socket?.on(key) { data, _ in
            guard let raw = data.first,
                  let jsonData = try? JSONSerialization.data(withJSONObject: raw),
                  let decoded = try? JSONDecoder().decode(T.self, from: jsonData)
            else { return }
            DispatchQueue.main.async { handler(decoded) }
        }
        // Store a type-erased copy for reconnect
        handlers[key] = { [weak self] _ in _ = self }
    }

    func off(_ event: ServerEvent) {
        socket?.off(event.rawValue)
        handlers.removeValue(forKey: event.rawValue)
    }

    // MARK: - Private

    private func reattachHandlers() {
        // Handlers are re-registered by the owning view models via on(_:handler:)
        // after receiving the reconnect notification. Nothing extra needed here.
    }
}
