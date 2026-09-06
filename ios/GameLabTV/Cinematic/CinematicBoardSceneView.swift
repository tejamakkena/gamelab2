import SwiftUI
import SceneKit

/// A generic vocabulary of table-game phases. A specific game maps its own
/// phase strings onto this rather than the cinematic layer knowing anything
/// about Poker or Mafia by name -- e.g. Poker's server-driven "preflop" /
/// "flop" / "turn" / "river" / "showdown" all collapse to `.betting` /
/// `.reveal` here, and Mafia's "day" / "night" / "vote" collapse to
/// `.dealing` (day discussion) / `.betting` (voting tension) / `.reveal`
/// (elimination reveal).
enum TablePhase: String, CaseIterable {
    case dealing
    case betting
    case reveal
    case results
}

/// A complete cinematic `SCNView` for a table-style board game (Poker,
/// Mafia, and similar "players seated around a shared surface" games): a
/// continuously-floating orbit camera, HDR + SSAO + depth of field +
/// vignette post-processing, a phase-driven key/fill lighting rig, and
/// smooth cubic-bezier camera transitions between named phases.
///
/// This view owns only the *cinematic* presentation layer -- the table,
/// seats, and a center marker are placeholder geometry standing in for
/// real card/chip/avatar art. A specific game plugs its own content in by
/// adding child nodes to `Coordinator.scene.rootNode` (see
/// `contentRootNode`) and drives phase changes by setting `phase`.
struct CinematicBoardSceneView: UIViewRepresentable {
    var phase: TablePhase
    var seatCount: Int

    init(phase: TablePhase, seatCount: Int = 6) {
        self.phase = phase
        self.seatCount = seatCount
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(seatCount: seatCount)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.cameraRig.cameraNode
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .black
        // Real-time playback -- this is a live, always-animating scene
        // (the idle orbit alone), not a static render.
        view.isPlaying = true
        view.rendersContinuously = true
        context.coordinator.applyPhase(phase, animated: false)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.applyPhase(phase, animated: true)
    }

    @MainActor
    final class Coordinator {
        let scene = SCNScene()
        let cameraRig: CinematicCameraRig
        let lighting: CinematicLighting
        /// Where a specific game adds its own card/chip/avatar content.
        /// Kept separate from the table/seat placeholder geometry so a real
        /// game can freely add and remove nodes here per game-state update
        /// without touching anything the cinematic layer owns.
        let contentRootNode = SCNNode()

        private var currentPhase: TablePhase?
        private let tableRadius: Float = 2.2

        init(seatCount: Int) {
            let initialShot = Coordinator.shot(for: .dealing, tableRadius: tableRadius)
            cameraRig = CinematicCameraRig(initialShot: initialShot)
            lighting = CinematicLighting(tableRadius: tableRadius)

            scene.rootNode.addChildNode(cameraRig.cameraNode)
            lighting.addToScene(scene)
            scene.rootNode.addChildNode(contentRootNode)

            buildTable(seatCount: seatCount)
        }

        func applyPhase(_ phase: TablePhase, animated: Bool) {
            guard phase != currentPhase else { return }
            currentPhase = phase

            let shot = Coordinator.shot(for: phase, tableRadius: tableRadius)
            let mood = Coordinator.mood(for: phase)

            if animated {
                cameraRig.transition(to: shot)
                lighting.apply(mood)
            } else {
                cameraRig.transition(to: shot, duration: 0)
                lighting.apply(mood, duration: 0)
            }
        }

        // MARK: - Placeholder table geometry

        private func buildTable(seatCount: Int) {
            let tableGeometry = SCNCylinder(radius: CGFloat(tableRadius), height: 0.08)
            let felt = SCNMaterial()
            felt.lightingModel = .physicallyBased
            felt.diffuse.contents = UIColor(red: 0.09, green: 0.32, blue: 0.20, alpha: 1)
            felt.roughness.contents = 0.85
            felt.metalness.contents = 0.0
            tableGeometry.materials = [felt]

            let tableNode = SCNNode(geometry: tableGeometry)
            tableNode.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(tableNode)

            let potMarker = SCNNode(geometry: SCNCylinder(radius: 0.22, height: 0.02))
            potMarker.position = SCNVector3(0, 0.05, 0)
            let potMaterial = SCNMaterial()
            potMaterial.lightingModel = .physicallyBased
            potMaterial.diffuse.contents = UIColor(white: 0.85, alpha: 1)
            potMaterial.metalness.contents = 0.6
            potMaterial.roughness.contents = 0.3
            potMarker.geometry?.materials = [potMaterial]
            contentRootNode.addChildNode(potMarker)

            for i in 0..<seatCount {
                let angle = (Float(i) / Float(seatCount)) * 2 * .pi
                let seatMaterial = SCNMaterial()
                seatMaterial.lightingModel = .physicallyBased
                seatMaterial.diffuse.contents = UIColor(white: 0.15, alpha: 1)
                seatMaterial.metalness.contents = 0.1
                seatMaterial.roughness.contents = 0.7

                let seat = SCNNode(geometry: SCNBox(width: 0.3, height: 0.05, length: 0.3, chamferRadius: 0.02))
                seat.geometry?.materials = [seatMaterial]
                seat.position = SCNVector3(
                    tableRadius * 0.82 * cos(angle),
                    0.05,
                    tableRadius * 0.82 * sin(angle)
                )
                contentRootNode.addChildNode(seat)
            }
        }

        // MARK: - Per-phase camera shots and lighting moods

        private static func shot(for phase: TablePhase, tableRadius: Float) -> CameraShot {
            switch phase {
            case .dealing:
                // Wide establishing shot from above and behind.
                return CameraShot(
                    position: SCNVector3(0, tableRadius * 1.6, tableRadius * 1.9),
                    lookAt: SCNVector3(0, 0, 0),
                    fieldOfView: 55,
                    focusDistance: CGFloat(tableRadius * 1.9)
                )
            case .betting:
                // Closer, slightly lower -- more intimate, tension-building.
                return CameraShot(
                    position: SCNVector3(tableRadius * 0.4, tableRadius * 0.9, tableRadius * 1.3),
                    lookAt: SCNVector3(0, 0, 0),
                    fieldOfView: 42,
                    focusDistance: CGFloat(tableRadius * 1.3)
                )
            case .reveal:
                // Dramatic low, tight shot toward the pot -- narrow FOV
                // reads as a telephoto "push in" for the reveal moment.
                return CameraShot(
                    position: SCNVector3(0, tableRadius * 0.55, tableRadius * 0.75),
                    lookAt: SCNVector3(0, 0.05, 0),
                    fieldOfView: 28,
                    focusDistance: CGFloat(tableRadius * 0.75)
                )
            case .results:
                // Pull back out, mirroring dealing but from the other side.
                return CameraShot(
                    position: SCNVector3(0, tableRadius * 1.7, -tableRadius * 1.8),
                    lookAt: SCNVector3(0, 0, 0),
                    fieldOfView: 58,
                    focusDistance: CGFloat(tableRadius * 1.8)
                )
            }
        }

        private static func mood(for phase: TablePhase) -> PhaseLightingMood {
            switch phase {
            case .dealing: return .warm
            case .betting: return .neutral
            case .reveal: return .tense
            case .results: return .neutral
            }
        }
    }
}
