import SwiftUI
import UIKit

/// Intercepts the Siri Remote's Menu button without depending on SwiftUI focus.
///
/// Two earlier attempts used SwiftUI's own `.onExitCommand`, and both failed on
/// real hardware for the same reason: per Apple's documentation that modifier
/// fires only "while the view has focus", so it is routed through the focus
/// responder chain like every other remote command. Most TV boards here
/// (Trivia, Poker, Roulette, Atlas -- anything the phone drives) have no
/// focusable elements at all, so there was nothing for Menu to route through
/// and tvOS fell back to its own default: quit the whole app. The follow-up
/// attempt -- making a container focusable so there was always *something* to
/// route through -- broke the game-selection grid's own focus outright
/// (caught by GameLabTVUITests), and a narrower version of it risked
/// interfering with the solo games' own remote input for the same reason.
///
/// A `UITapGestureRecognizer` restricted to `.menu` presses, installed on the
/// window, sidesteps the focus system entirely: press events bubble to the
/// window regardless of what is (or isn't) focused. This is the pre-SwiftUI
/// UIKit approach and it does not care about focus at all.
///
/// `isActive` matters for more than tidiness: a Menu recognizer on the window
/// swallows the press, and tvOS requires Menu to exit the app from its
/// top-level screen. The recognizer is therefore installed only while a game
/// is actually in progress, and removed on the game-selection screen so Menu
/// keeps doing the platform-standard thing there.
struct MenuPressInterceptor: UIViewRepresentable {
    var isActive: Bool
    var onMenu: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = InterceptorView()
        view.onMenu = onMenu
        view.desiredActive = isActive
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? InterceptorView else { return }
        view.onMenu = onMenu
        view.desiredActive = isActive
    }

    final class InterceptorView: UIView {
        var onMenu: (() -> Void)?

        var desiredActive: Bool = false {
            didSet { syncRecognizer() }
        }

        private weak var installedOn: UIWindow?
        private var recognizer: UITapGestureRecognizer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            // Purely a hook for the window-level recognizer; it must never
            // take part in layout, hit-testing or the focus system itself.
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            syncRecognizer()
        }

        private func syncRecognizer() {
            if desiredActive, window != nil {
                install()
            } else {
                uninstall()
            }
        }

        private func install() {
            guard recognizer == nil, let window else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(menuPressed))
            tap.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
            window.addGestureRecognizer(tap)
            recognizer = tap
            installedOn = window
        }

        private func uninstall() {
            guard let recognizer else { return }
            installedOn?.removeGestureRecognizer(recognizer)
            self.recognizer = nil
            installedOn = nil
        }

        @objc private func menuPressed() {
            onMenu?()
        }

        deinit {
            // deinit can land off the main actor; the capture is a plain
            // UIKit pair with no SwiftUI state involved.
            if let recognizer, let installedOn {
                installedOn.removeGestureRecognizer(recognizer)
            }
        }
    }
}
