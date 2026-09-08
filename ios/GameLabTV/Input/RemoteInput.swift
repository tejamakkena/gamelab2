import GameController
import SwiftUI

/// Siri Remote input for games that run on the TV alone.
///
/// Before this, the tvOS app handled the remote only for menu focus — one
/// `@FocusState`, one `.onPlayPauseCommand`, and an `.onMoveCommand { _ in }`
/// that did nothing. All gameplay input arrived from phones over the socket.
/// These modifiers let a game read the remote directly so it can be played with
/// nothing else in the room.
enum RemoteEvent: Equatable {
    case up, down, left, right
    case select
    case playPause
    /// Continuous horizontal position across the touch surface, 0...1.
    case scrub(Double)
}

// MARK: - Focus

/// Every modifier below reads the remote through the *focus engine*
/// (`onMoveCommand`, `onPlayPauseCommand`, the Select tap), and the focus
/// engine only ever delivers those to the view that currently holds focus.
/// `.focusable()` alone just makes a view *eligible*; it does not claim focus,
/// and a container that appears part-way through a navigation (a game board
/// pushed in response to a socket message, which is exactly how every board
/// here appears) is not reliably given it. Claiming it explicitly on appear is
/// what makes remote input arrive at all.
private struct ClaimsRemoteFocus: ViewModifier {
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($focused)
            // Deferred by one runloop turn: assigning @FocusState during the
            // same update that first installs the view is dropped by the
            // focus engine.
            .onAppear { DispatchQueue.main.async { focused = true } }
    }
}

private extension View {
    func claimsRemoteFocus() -> some View { modifier(ClaimsRemoteFocus()) }
}

// MARK: - D-pad

/// Directional input plus Select. Use for Neon Snake and Simon Says.
struct RemoteDPad: ViewModifier {
    let onEvent: (RemoteEvent) -> Void

    func body(content: Content) -> some View {
        content
            .claimsRemoteFocus()
            .onMoveCommand { direction in
                switch direction {
                case .up:    onEvent(.up)
                case .down:  onEvent(.down)
                case .left:  onEvent(.left)
                case .right: onEvent(.right)
                @unknown default: break
                }
            }
            .onPlayPauseCommand { onEvent(.playPause) }
            // The remote's Select button arrives as a tap on a focusable view.
            .onTapGesture { onEvent(.select) }
    }
}

// MARK: - Swipe

/// Discrete swipes for tile games such as 2048.
///
/// `DragGesture` is unavailable on tvOS entirely (no touch screen — the
/// remote's surface is exposed only through the focus-engine commands
/// below), so `onMoveCommand` is the only source of swipe direction here,
/// not a supplement to a gesture recognizer.
struct RemoteSwipe: ViewModifier {
    let onEvent: (RemoteEvent) -> Void

    func body(content: Content) -> some View {
        content
            .claimsRemoteFocus()
            .onMoveCommand { direction in
                switch direction {
                case .up:    onEvent(.up)
                case .down:  onEvent(.down)
                case .left:  onEvent(.left)
                case .right: onEvent(.right)
                @unknown default: break
                }
            }
            .onPlayPauseCommand { onEvent(.playPause) }
    }
}

// MARK: - Analog scrub

/// Continuous horizontal position off the Siri Remote's touch surface.
///
/// `onMoveCommand` is a *focus-navigation* event, not a pointer: on the Siri
/// Remote it fires only on a deliberate directional swipe or an edge click,
/// and all it ever reports is "left" or "right" — never where the thumb
/// actually is. Driving a paddle from it meant a fixed 0.08-wide jump per
/// flick, and resting a thumb on the surface and sliding it (the motion the
/// on-screen hint asks for, and the only one that feels like a paddle)
/// produced no events whatsoever.
///
/// GameController.framework does expose the real thing. A Siri Remote shows up
/// as a `GCMicroGamepad`, and with `reportsAbsoluteDpadValues = true` its dpad
/// reports the **absolute** finger position on the touch surface in -1...1
/// instead of relative navigation deltas. This object owns that subscription,
/// handles controllers that connect after the view appears, and falls back to
/// the old step behaviour when no analog source is available (the Simulator,
/// which delivers no GameController events at all).
final class RemoteAnalogTracker: ObservableObject {

    /// Latest horizontal position across the surface: 0 = left, 1 = right.
    @Published private(set) var position: Double = 0.5

    /// True once a controller that can report continuous position is attached.
    /// Until then the `onMoveCommand` step fallback is the only input.
    @Published private(set) var hasAnalogSource = false

    /// Called on the main queue for every change, including nudges.
    var onChange: ((Double) -> Void)?

    /// How fast a thumbstick sweeps the full range, in fractions per second.
    private let stickSpeed: Double = 1.6
    private let stickDeadZone: Double = 0.12

    private var observers: [NSObjectProtocol] = []
    private var attached = Set<ObjectIdentifier>()
    private var stickX: Double = 0
    private var stickTimer: Timer?
    private var running = false

    func start() {
        guard !running else { return }
        running = true

        let center = NotificationCenter.default
        // Controllers connect and disconnect asynchronously and can appear
        // well after this view does — a remote that woke up late, or an MFi
        // controller paired mid-game — so watching for them is not optional.
        observers.append(center.addObserver(forName: .GCControllerDidConnect,
                                            object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.attach(controller)
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect,
                                            object: nil, queue: .main) { [weak self] note in
            guard let self, let controller = note.object as? GCController else { return }
            self.attached.remove(ObjectIdentifier(controller))
            self.hasAnalogSource = !self.attached.isEmpty
            if self.attached.isEmpty { self.stopStickTimer() }
        })

        for controller in GCController.controllers() { attach(controller) }
    }

    func stop() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        stopStickTimer()
        for controller in GCController.controllers() {
            controller.microGamepad?.dpad.valueChangedHandler = nil
            controller.extendedGamepad?.leftThumbstick.valueChangedHandler = nil
        }
        attached.removeAll()
        hasAnalogSource = false
        running = false
    }

    /// Move by a fixed step — the `onMoveCommand` fallback path.
    func nudge(_ amount: Double) {
        publish(position + amount)
    }

    // MARK: Private

    private func attach(_ controller: GCController) {
        let key = ObjectIdentifier(controller)
        guard !attached.contains(key) else { return }

        // Deliver on the main queue so `@Published` mutation and the SwiftUI
        // callback below never hop threads.
        controller.handlerQueue = .main

        if let pad = controller.extendedGamepad {
            // A real game controller: its stick is spring-centred, so it is a
            // velocity, not a position. Integrate it on a timer instead.
            pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, _ in
                guard let self else { return }
                self.stickX = Double(x)
                if abs(self.stickX) > self.stickDeadZone {
                    self.startStickTimer()
                } else {
                    self.stopStickTimer()
                }
            }
            attached.insert(key)
            hasAnalogSource = true
            return
        }

        guard let micro = controller.microGamepad else { return }
        // The whole point: absolute finger position, rather than the relative
        // "which way did they flick" deltas the focus engine works from.
        micro.reportsAbsoluteDpadValues = true
        micro.allowsRotation = false
        micro.dpad.valueChangedHandler = { [weak self] _, x, y in
            // A finger lift reports an exact (0, 0). A real touch landing on
            // the mathematical centre of the pad to full Float precision is
            // not a thing, so treating that as "thumb gone, hold position" is
            // safe — and it stops the paddle snapping to the middle every
            // time the thumb comes off the surface.
            guard x != 0 || y != 0 else { return }
            self?.publish(Double((x + 1) / 2))
        }
        attached.insert(key)
        hasAnalogSource = true
    }

    private func startStickTimer() {
        guard stickTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.publish(self.position + self.stickX * self.stickSpeed / 60.0)
        }
        RunLoop.main.add(timer, forMode: .common)
        stickTimer = timer
    }

    private func stopStickTimer() {
        stickTimer?.invalidate()
        stickTimer = nil
    }

    private func publish(_ raw: Double) {
        let clamped = min(1, max(0, raw))
        guard abs(clamped - position) > 0.0005 else { return }
        position = clamped
        onChange?(clamped)
    }
}

/// Left/right position for paddle games such as Brick Breaker.
struct RemoteScrub: ViewModifier {
    let onEvent: (RemoteEvent) -> Void

    @StateObject private var tracker = RemoteAnalogTracker()

    func body(content: Content) -> some View {
        content
            .claimsRemoteFocus()
            .onMoveCommand { direction in
                // Kept only as a fallback: GameController delivers nothing in
                // the tvOS Simulator, and a hardware keyboard's arrow keys
                // arrive here too. Both routes end up in the same `publish`,
                // so the two never fight over the position.
                switch direction {
                case .left:  tracker.nudge(-0.05)
                case .right: tracker.nudge(0.05)
                default: break
                }
            }
            .onPlayPauseCommand { onEvent(.playPause) }
            .onAppear {
                tracker.onChange = { onEvent(.scrub($0)) }
                tracker.start()
            }
            .onDisappear {
                tracker.onChange = nil
                tracker.stop()
            }
    }
}

// MARK: - Sugar

extension View {
    func remoteDPad(_ onEvent: @escaping (RemoteEvent) -> Void) -> some View {
        modifier(RemoteDPad(onEvent: onEvent))
    }

    func remoteSwipe(_ onEvent: @escaping (RemoteEvent) -> Void) -> some View {
        modifier(RemoteSwipe(onEvent: onEvent))
    }

    func remoteScrub(_ onEvent: @escaping (RemoteEvent) -> Void) -> some View {
        modifier(RemoteScrub(onEvent: onEvent))
    }
}

extension RemoteEvent {
    /// The direction name the server engines expect in a `game_action` payload.
    var directionName: String? {
        switch self {
        case .up:    return "up"
        case .down:  return "down"
        case .left:  return "left"
        case .right: return "right"
        default:     return nil
        }
    }
}
