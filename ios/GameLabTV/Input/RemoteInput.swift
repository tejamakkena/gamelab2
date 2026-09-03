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
/// `onMoveCommand` already fires for a flick on the touch surface, so the
/// gesture below only adds recognition for slower drags that tvOS would
/// otherwise treat as focus movement.
struct RemoteSwipe: ViewModifier {
    let onEvent: (RemoteEvent) -> Void

    @State private var handled = false

    private var threshold: CGFloat { 40 }

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
            .gesture(
                DragGesture(minimumDistance: threshold)
                    .onChanged { value in
                        guard !handled else { return }
                        handled = true
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if abs(dx) > abs(dy) {
                            onEvent(dx > 0 ? .right : .left)
                        } else {
                            onEvent(dy > 0 ? .down : .up)
                        }
                    }
                    .onEnded { _ in handled = false }
            )
    }
}

// MARK: - Analog scrub

/// Continuous left/right position for paddle games such as Brick Breaker.
///
/// Reports a normalised 0...1 value so the caller does not have to know the
/// width of the touch surface.
struct RemoteScrub: ViewModifier {
    let onEvent: (RemoteEvent) -> Void

    /// How far a full-width drag travels, in points. tvOS reports touch-surface
    /// drags in a small range, so this is deliberately modest.
    private var span: CGFloat { 600 }

    @State private var anchor: Double = 0.5

    func body(content: Content) -> some View {
        content
            .focusable()
            .onMoveCommand { direction in
                // Step the paddle when someone clicks the edges instead of dragging.
                switch direction {
                case .left:  nudge(-0.08)
                case .right: nudge(0.08)
                default: break
                }
            }
            .onPlayPauseCommand { onEvent(.playPause) }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let delta = Double(value.translation.width / span)
                        onEvent(.scrub(min(1, max(0, anchor + delta))))
                    }
                    .onEnded { value in
                        anchor = min(1, max(0, anchor + Double(value.translation.width / span)))
                    }
            )
    }

    private func nudge(_ amount: Double) {
        anchor = min(1, max(0, anchor + amount))
        onEvent(.scrub(anchor))
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
