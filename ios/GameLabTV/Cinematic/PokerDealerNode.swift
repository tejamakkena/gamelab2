import SceneKit
import UIKit

/// A stylized, low-poly casino dealer built entirely from SceneKit primitive
/// geometry (capsules, spheres, boxes) -- there is no 3D model file, rig, or
/// motion-capture asset anywhere in this project, and no toolchain here to
/// produce one, so every limb is a primitive and every motion is a
/// procedural `SCNAction` rotating a joint *pivot* node, the same technique
/// `CinematicCameraRig` uses to animate its camera and `CinematicLighting`
/// uses to crossfade its lights -- no imported/rigged skeleton anywhere.
///
/// Node hierarchy (every `position` below is parent-local, as SceneKit
/// requires -- rotating a pivot node swings every primitive hung off it like
/// a real joint):
///
///     rootNode                              (placed in world space by the caller)
///       ├─ leftLeg / rightLeg                (static capsules -- grounding only)
///       ├─ torsoNode                         (idle "breathing" scale loop)
///       │    └─ bowtieNode
///       ├─ headPivot                         (idle side-to-side glance loop)
///       │    ├─ headNode
///       │    └─ visorNode                    ("the house", not a player)
///       ├─ leftShoulder                      (idle subtle sway loop)
///       │    ├─ leftUpperArm
///       │    └─ leftElbow
///       │         ├─ leftForearm
///       │         └─ leftHand
///       └─ rightShoulder                     (dealing motion + showdown gesture)
///            ├─ rightUpperArm
///            └─ rightElbow                   (dealing motion + showdown gesture)
///                 ├─ rightForearm
///                 └─ rightHand
///
/// The right arm is reserved exclusively for the one-shot gestures
/// (`playDeal`, `playShowdownReaction`); the left arm, head, and torso are
/// reserved exclusively for the continuous idle loop. No two `SCNAction`s
/// ever target the same node's transform, so nothing needs to pause or
/// cancel the idle loop to play a gesture -- exactly the non-interference
/// discipline `CinematicCameraRig` uses to keep its idle orbit and its shot
/// transitions from fighting over the camera node's position.
@MainActor
final class PokerDealerNode {
    let rootNode = SCNNode()

    private let torsoNode: SCNNode
    private let headPivot: SCNNode
    private let leftShoulder: SCNNode
    private let rightShoulder: SCNNode
    private let rightElbow: SCNNode

    /// Feet sit at local y = 0 (the caller places `rootNode` at floor
    /// height); everything above is built upward from there.
    init() {
        let skin = Self.material(color: UIColor(red: 0.80, green: 0.63, blue: 0.52, alpha: 1), roughness: 0.75)
        let vest = Self.material(color: UIColor(red: 0.46, green: 0.06, blue: 0.10, alpha: 1), roughness: 0.55, metalness: 0.1)
        let trousers = Self.material(color: UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1), roughness: 0.7)
        let visorColor = Self.material(color: UIColor(red: 0.10, green: 0.85, blue: 0.35, alpha: 1), roughness: 0.35, metalness: 0.05)
        let black = Self.material(color: UIColor(white: 0.03, alpha: 1), roughness: 0.4)

        // MARK: Legs (static -- purely for grounding, never animated)

        for xSign: Float in [-1, 1] {
            let leg = SCNNode(geometry: SCNCapsule(capRadius: 0.09, height: 0.9))
            leg.geometry?.materials = [trousers]
            leg.position = SCNVector3(xSign * 0.09, 0.45, 0)
            rootNode.addChildNode(leg)
        }

        // MARK: Torso (idle breathing target)

        let torso = SCNNode(geometry: SCNCapsule(capRadius: 0.17, height: 0.6))
        torso.geometry?.materials = [vest]
        torso.position = SCNVector3(0, 1.15, 0)
        rootNode.addChildNode(torso)
        torsoNode = torso

        let bowtie = SCNNode(geometry: SCNBox(width: 0.14, height: 0.05, length: 0.05, chamferRadius: 0.01))
        bowtie.geometry?.materials = [black]
        bowtie.position = SCNVector3(0, 0.27, 0.15)
        torso.addChildNode(bowtie)

        // MARK: Head + visor (idle glance target)

        let head = SCNNode()
        head.position = SCNVector3(0, 1.62, 0)
        rootNode.addChildNode(head)
        headPivot = head

        let skull = SCNNode(geometry: SCNSphere(radius: 0.115))
        skull.geometry?.materials = [skin]
        head.addChildNode(skull)

        let visor = SCNNode(geometry: SCNCylinder(radius: 0.135, height: 0.03))
        visor.geometry?.materials = [visorColor]
        visor.position = SCNVector3(0, 0.06, 0.03)
        // Bare `.pi` here is ambiguous -- SCNVector3's component type isn't
        // pinned down for the compiler until it also resolves the unary
        // minus, and it won't guess. Spelling out Float.pi is what actually
        // compiles.
        visor.eulerAngles = SCNVector3(-Float.pi / 7, 0, 0)
        head.addChildNode(visor)

        // MARK: Arms

        func buildArm(xSign: Float) -> (shoulder: SCNNode, elbow: SCNNode) {
            let shoulder = SCNNode()
            shoulder.position = SCNVector3(xSign * 0.22, 1.42, 0)
            rootNode.addChildNode(shoulder)

            let upperArm = SCNNode(geometry: SCNCapsule(capRadius: 0.06, height: 0.35))
            upperArm.geometry?.materials = [vest]
            upperArm.position = SCNVector3(0, -0.175, 0)
            shoulder.addChildNode(upperArm)

            let elbow = SCNNode()
            elbow.position = SCNVector3(0, -0.35, 0)
            shoulder.addChildNode(elbow)

            let forearm = SCNNode(geometry: SCNCapsule(capRadius: 0.05, height: 0.3))
            forearm.geometry?.materials = [skin]
            forearm.position = SCNVector3(0, -0.15, 0)
            elbow.addChildNode(forearm)

            let hand = SCNNode(geometry: SCNSphere(radius: 0.06))
            hand.geometry?.materials = [skin]
            hand.position = SCNVector3(0, -0.30, 0)
            elbow.addChildNode(hand)

            return (shoulder, elbow)
        }

        leftShoulder = buildArm(xSign: -1).shoulder
        let right = buildArm(xSign: 1)
        rightShoulder = right.shoulder
        rightElbow = right.elbow

        startIdle()
    }

    private static func material(color: UIColor, roughness: CGFloat, metalness: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        return m
    }

    // MARK: - Idle loop (always running, never interrupted)

    /// Subtle breathing, weight-shifting sway, and a slow scanning glance --
    /// three independently-timed loops (different durations, like
    /// `CinematicCameraRig`'s non-integer-ratio orbit frequencies) so the
    /// dealer never looks frozen between hands but also never looks like a
    /// looping animation cycle.
    private func startIdle() {
        let breatheIn = SCNAction.scale(by: 1.035, duration: 1.7)
        breatheIn.timingMode = .easeInEaseOut
        let breathe = SCNAction.sequence([breatheIn, breatheIn.reversed()])
        torsoNode.runAction(.repeatForever(breathe), forKey: "idleBreathe")

        let swayOut = SCNAction.rotate(by: 0.10, around: SCNVector3(1, 0, 0), duration: 2.1)
        swayOut.timingMode = .easeInEaseOut
        let sway = SCNAction.sequence([swayOut, swayOut.reversed()])
        leftShoulder.runAction(.repeatForever(sway), forKey: "idleSway")

        let glanceOut = SCNAction.rotate(by: 0.22, around: SCNVector3(0, 1, 0), duration: 2.6)
        glanceOut.timingMode = .easeInEaseOut
        let glance = SCNAction.sequence([glanceOut, .wait(duration: 0.4), glanceOut.reversed(), .wait(duration: 0.6)])
        headPivot.runAction(.repeatForever(glance), forKey: "idleGlance")
    }

    // MARK: - One-shot gestures (right arm only -- never fights the idle loop)

    /// A dealing flick of the right arm toward the table, repeated once per
    /// newly-revealed community card so a 3-card flop reads as three quick
    /// motions and a single turn/river card reads as one.
    func playDeal(cardCount: Int) {
        let reps = max(1, cardCount)

        let reach = SCNAction.rotate(by: -0.9, around: SCNVector3(1, 0, 0), duration: 0.22)
        reach.timingMode = .easeOut
        let bend = SCNAction.rotate(by: -0.55, around: SCNVector3(1, 0, 0), duration: 0.18)
        bend.timingMode = .easeOut

        let shoulderFlick = SCNAction.sequence([reach, .wait(duration: 0.05), reach.reversed(), .wait(duration: 0.14)])
        let elbowFlick = SCNAction.sequence([bend, .wait(duration: 0.05), bend.reversed(), .wait(duration: 0.14)])

        rightShoulder.removeAction(forKey: "gesture")
        rightElbow.removeAction(forKey: "gesture")
        rightShoulder.runAction(.repeat(shoulderFlick, count: reps), forKey: "gesture")
        rightElbow.runAction(.repeat(elbowFlick, count: reps), forKey: "gesture")
    }

    /// A raised-hand flourish at showdown -- optionally leaning the whole
    /// body toward the winner's side of the table when one can be
    /// determined from `public_state()`; otherwise just the flourish.
    func playShowdownReaction(leanRight: Bool?) {
        let raiseShoulder = SCNAction.rotate(by: -1.7, around: SCNVector3(1, 0, 0), duration: 0.5)
        raiseShoulder.timingMode = .easeOut
        let raiseElbow = SCNAction.rotate(by: 0.5, around: SCNVector3(1, 0, 0), duration: 0.5)
        raiseElbow.timingMode = .easeOut
        let hold = SCNAction.wait(duration: 1.1)

        rightShoulder.removeAction(forKey: "gesture")
        rightElbow.removeAction(forKey: "gesture")
        rightShoulder.runAction(.sequence([raiseShoulder, hold, raiseShoulder.reversed()]), forKey: "gesture")
        rightElbow.runAction(.sequence([raiseElbow, hold, raiseElbow.reversed()]), forKey: "gesture")

        guard let leanRight else { return }
        let angle: CGFloat = leanRight ? -0.3 : 0.3
        let lean = SCNAction.rotate(by: angle, around: SCNVector3(0, 1, 0), duration: 0.6)
        lean.timingMode = .easeInEaseOut
        rootNode.removeAction(forKey: "lean")
        rootNode.runAction(.sequence([lean, hold, lean.reversed()]), forKey: "lean")
    }
}
