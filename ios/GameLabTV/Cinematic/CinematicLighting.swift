import SceneKit
import UIKit

/// A warm/cool color-temperature pair a game phase can request. `.temperature`
/// on `SCNLight` is a physically-based Kelvin value: lower is warmer (candle,
/// ~2000K), higher is cooler (overcast sky, ~9000K+). Neutral daylight is
/// roughly 6500K.
struct PhaseLightingMood {
    var keyTemperature: CGFloat
    var fillTemperature: CGFloat
    var keyIntensity: CGFloat
    var fillIntensity: CGFloat

    static let neutral = PhaseLightingMood(
        keyTemperature: 5600, fillTemperature: 6500, keyIntensity: 1200, fillIntensity: 220
    )
    /// A tenser, cooler wash -- e.g. Mafia's "night" phase or a Poker
    /// all-in showdown.
    static let tense = PhaseLightingMood(
        keyTemperature: 8200, fillTemperature: 9500, keyIntensity: 1000, fillIntensity: 140
    )
    /// A warmer, more intimate wash -- e.g. a casual "dealing" phase.
    static let warm = PhaseLightingMood(
        keyTemperature: 3200, fillTemperature: 4200, keyIntensity: 1400, fillIntensity: 260
    )
}

/// Key spotlight + ambient fill for a cinematic table scene. The key light
/// casts real, soft shadows (cards and chips read as physically sitting on
/// the table); the fill exists only to keep shadowed areas from going
/// fully black, and its color temperature is what actually shifts per
/// game phase -- a subtle, continuous mood change rather than a hard cut.
@MainActor
final class CinematicLighting {
    let keyNode: SCNNode
    let fillNode: SCNNode

    init(tableRadius: Float = 2.2) {
        let key = SCNLight()
        key.type = .spot
        key.spotInnerAngle = 35
        key.spotOuterAngle = 70
        key.castsShadow = true
        key.shadowMode = .deferred
        key.shadowRadius = 12          // higher = softer shadow penumbra
        key.shadowSampleCount = 16
        key.shadowColor = UIColor(white: 0, alpha: 0.55)
        key.automaticallyAdjustsShadowProjection = true
        key.temperature = PhaseLightingMood.neutral.keyTemperature
        key.intensity = PhaseLightingMood.neutral.keyIntensity

        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(0, tableRadius * 2.4, tableRadius * 0.6)
        keyNode.look(at: SCNVector3(0, 0, 0))
        self.keyNode = keyNode

        let fill = SCNLight()
        fill.type = .ambient
        fill.temperature = PhaseLightingMood.neutral.fillTemperature
        fill.intensity = PhaseLightingMood.neutral.fillIntensity

        let fillNode = SCNNode()
        fillNode.light = fill
        self.fillNode = fillNode
    }

    func addToScene(_ scene: SCNScene) {
        scene.rootNode.addChildNode(keyNode)
        scene.rootNode.addChildNode(fillNode)
    }

    /// Crossfades to a new mood over `duration` seconds. Wrapped in its own
    /// `SCNTransaction` so lighting can shift independently of (and
    /// concurrently with) a `CinematicCameraRig` transition -- a phase
    /// change often wants both at once, on their own timings.
    func apply(_ mood: PhaseLightingMood, duration: TimeInterval = 1.8) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        keyNode.light?.temperature = mood.keyTemperature
        keyNode.light?.intensity = mood.keyIntensity
        fillNode.light?.temperature = mood.fillTemperature
        fillNode.light?.intensity = mood.fillIntensity
        SCNTransaction.commit()
    }
}
