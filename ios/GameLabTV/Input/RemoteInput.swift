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

// MARK: - D-pad

/// Directional input plus Select. Use for Neon Snake and Simon Says.
struct RemoteDPad: ViewModifier {
    let onEvent: (RemoteEvent) -> Void

    func body(content: Content) -> some View {
        content
            .focusable()
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
            .focusable()
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

/// Left/right position for paddle games such as Brick Breaker.
///
/// tvOS has no `DragGesture` to read continuous position off the remote's
/// touch surface directly in SwiftUI (that needs GameController.framework's
/// `GCMicroGamepad.dpad`, a lower-level API this file deliberately doesn't
/// take on yet). Until then, each edge click on the touch surface arrives as
/// a discrete `onMoveCommand` and nudges the paddle a fixed step — coarser
/// than a smooth drag, but a real, working control rather than a modifier
/// that doesn't compile.
struct RemoteScrub: ViewModifier {
    let onEvent: (RemoteEvent) -> Void

    @State private var position: Double = 0.5

    func body(content: Content) -> some View {
        content
            .focusable()
            .onMoveCommand { direction in
                switch direction {
                case .left:  nudge(-0.08)
                case .right: nudge(0.08)
                default: break
                }
            }
            .onPlayPauseCommand { onEvent(.playPause) }
    }

    private func nudge(_ amount: Double) {
        position = min(1, max(0, position + amount))
        onEvent(.scrub(position))
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
