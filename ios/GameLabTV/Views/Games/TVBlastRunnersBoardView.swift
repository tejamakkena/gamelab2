import SwiftUI
import SceneKit

// MARK: - Blast Runners — TV Board
//
// GAME RULES:
//   • 1-4 players, co-op. 25 escalating levels, each a top-down grid dungeon
//     of open floor and breakable rock behind a permanent outer wall.
//   • Move with the D-pad; BLAST clears the rock tile you're facing or
//     destroys an enemy standing on it.
//   • One shared team life pool for the whole room -- a hit costs the pool
//     one life and briefly benches that player (they respawn at the level's
//     start tile), it never ejects anyone or sends the group back past the
//     level they're currently on.
//   • Collect every gem to unlock the exit; everyone connected has to stand
//     on it together to clear the level and move on.
//
// PRESENTATION: a real top-down 3D SceneKit scene (`BlastRunnersCinematicBoardSceneView`
// below), built directly on `CinematicCameraRig`/`CinematicLighting` exactly the
// way `HeistCinematicBoardSceneView` (TVHeistBoardView.swift) is -- chunky
// voxel-block tiles, small primitive-geometry characters that glide tile-to-tile,
// and a quick fade+shrink beat when a rock block is blasted. Every number a
// player actually needs to track -- level, shared lives, gems remaining, the
// level-complete/level-failed banner -- stays ordinary legible SwiftUI text
// drawn on top of it; the 3D scene is atmosphere, never the source of truth.

struct TVBlastRunnersBoardView: View {
    let room: Room
    @StateObject private var vm = BlastRunnersBoardViewModel()

    var body: some View {
        ZStack {
            Color(hex: "05070a").ignoresSafeArea()

            BlastRunnersCinematicBoardSceneView(state: vm.state)
                .ignoresSafeArea()

            VStack {
                LinearGradient(colors: [.black.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 170)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                headerBar
                Spacer()
                if let banner = vm.state.bannerText {
                    BlastBanner(text: banner, tint: vm.state.bannerTint)
                        .padding(.bottom, 48)
                }
            }
            .padding(40)
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }

    private var headerBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("⛏️ Blast Runners")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                Text("Level \(vm.state.level) of \(vm.state.maxLevel)")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(0..<max(vm.state.livesMax, 1), id: \.self) { index in
                        Image(systemName: index < vm.state.livesCurrent ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundColor(index < vm.state.livesCurrent ? .red : .white.opacity(0.25))
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill").foregroundColor(.cyan)
                    Text("\(vm.state.gemsRemaining) of \(vm.state.gemsTotal) gems")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

private struct BlastBanner: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.title2.bold())
            .foregroundColor(tint)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(tint.opacity(0.16)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - ViewModel

@MainActor
final class BlastRunnersBoardViewModel: ObservableObject {
    @Published var state = BlastRunnersBoardState()
    private let socket = GameSocketManager.shared

    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (response: GameStateResponse) in
            guard response.roomCode == roomCode else { return }
            self?.state.update(from: response.boardState)
        }
    }
}

// MARK: - State

struct BRPlayerState: Identifiable {
    let id: String
    let name: String
    let pos: GridPos
    let facing: String
    let alive: Bool
    let invulnerable: Bool
}

struct BREnemyState: Identifiable {
    let id: String
    let type: String
    let pos: GridPos
}

struct BRProjectileState: Identifiable {
    let id: Int
    let pos: GridPos
    let direction: String
}

struct BlastRunnersBoardState {
    var level = 1
    var maxLevel = 25
    var gridWidth = 8
    var gridHeight = 8
    var tiles: [String] = []
    var gems: [GridPos] = []
    var gemsRemaining = 0
    var gemsTotal = 0
    var exitPos = GridPos(col: 0, row: 0)
    var exitUnlocked = false
    var players: [BRPlayerState] = []
    var enemies: [BREnemyState] = []
    var projectiles: [BRProjectileState] = []
    var livesCurrent = 0
    var livesMax = 0
    var phase = "playing"
    var finished = false
    var lastBlastCol: Int?
    var lastBlastRow: Int?
    var lastBlastAt: Double?

    var bannerText: String? {
        switch phase {
        case "levelComplete": return "Level \(level) Clear!"
        case "levelFailed":   return "Team Down — Resetting Level \(level)"
        case "gameComplete":  return "All 25 Levels Cleared! 🏆"
        default: return nil
        }
    }

    var bannerTint: Color {
        switch phase {
        case "levelComplete", "gameComplete": return .green
        case "levelFailed": return .red
        default: return .white
        }
    }

    func tile(atCol col: Int, row: Int) -> Character {
        guard row >= 0, row < tiles.count else { return "#" }
        let chars = Array(tiles[row])
        guard col >= 0, col < chars.count else { return "#" }
        return chars[col]
    }

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["level"]?.value as? Int { level = v }
        if let v = data["maxLevel"]?.value as? Int { maxLevel = v }
        if let v = data["gridWidth"]?.value as? Int { gridWidth = v }
        if let v = data["gridHeight"]?.value as? Int { gridHeight = v }
        if let v = data["tiles"]?.value as? [String] { tiles = v }

        if let arr = data["gems"]?.value as? [[String: Any]] {
            gems = arr.compactMap { d -> GridPos? in
                guard let c = d["col"] as? Int, let r = d["row"] as? Int else { return nil }
                return GridPos(col: c, row: r)
            }
        }
        if let v = data["gemsRemaining"]?.value as? Int { gemsRemaining = v }
        if let v = data["gemsTotal"]?.value as? Int { gemsTotal = v }
        if let c = data["exitCol"]?.value as? Int, let r = data["exitRow"]?.value as? Int {
            exitPos = GridPos(col: c, row: r)
        }
        if let v = data["exitUnlocked"]?.value as? Bool { exitUnlocked = v }

        if let arr = data["players"]?.value as? [[String: Any]] {
            players = arr.compactMap { d -> BRPlayerState? in
                guard let id = d["playerID"] as? String,
                      let name = d["name"] as? String,
                      let c = d["col"] as? Int, let r = d["row"] as? Int,
                      let facing = d["facing"] as? String else { return nil }
                return BRPlayerState(id: id, name: name, pos: GridPos(col: c, row: r),
                                      facing: facing,
                                      alive: d["alive"] as? Bool ?? true,
                                      invulnerable: d["invulnerable"] as? Bool ?? false)
            }
        }
        if let arr = data["enemies"]?.value as? [[String: Any]] {
            enemies = arr.compactMap { d -> BREnemyState? in
                guard let id = d["id"] as? String,
                      let type = d["type"] as? String,
                      let c = d["col"] as? Int, let r = d["row"] as? Int else { return nil }
                return BREnemyState(id: id, type: type, pos: GridPos(col: c, row: r))
            }
        }
        if let arr = data["projectiles"]?.value as? [[String: Any]] {
            projectiles = arr.enumerated().compactMap { idx, d -> BRProjectileState? in
                guard let c = d["col"] as? Int, let r = d["row"] as? Int,
                      let dir = d["direction"] as? String else { return nil }
                return BRProjectileState(id: idx, pos: GridPos(col: c, row: r), direction: dir)
            }
        }

        if let v = data["livesCurrent"]?.value as? Int { livesCurrent = v }
        if let v = data["livesMax"]?.value as? Int { livesMax = v }
        if let v = data["phase"]?.value as? String { phase = v }
        if let v = data["finished"]?.value as? Bool { finished = v }
        lastBlastCol = data["lastBlastCol"]?.value as? Int
        lastBlastRow = data["lastBlastRow"]?.value as? Int
        lastBlastAt = data["lastBlastAt"]?.value as? Double
    }
}

// MARK: - 3D Board Scene

private func blastMaterial(color: UIColor, roughness: CGFloat, metalness: CGFloat = 0, emission: UIColor? = nil) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = color
    m.roughness.contents = roughness
    m.metalness.contents = metalness
    if let emission {
        m.emission.contents = emission
    }
    return m
}

private let brFloorColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)
private let brRockColor = UIColor(red: 0.42, green: 0.28, blue: 0.16, alpha: 1)
private let brWallColor = UIColor(white: 0.04, alpha: 1)
private let brPlayerPalette: [UIColor] = [.cyan, .yellow, .green, .orange]

struct BlastRunnersCinematicBoardSceneView: UIViewRepresentable {
    var state: BlastRunnersBoardState

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.cameraRig.cameraNode
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .black
        view.isPlaying = true
        view.rendersContinuously = true
        context.coordinator.apply(state, animated: false)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.apply(state, animated: true)
    }

    @MainActor
    final class Coordinator {
        let scene = SCNScene()
        let cameraRig: CinematicCameraRig
        let lighting: CinematicLighting

        private let tileSize: Float = 1.0
        /// Every tile/gem/exit node for the *current* level lives under this
        /// one node, so a level transition (grid resizes, layout changes) is
        /// just "throw this away and rebuild it" instead of diffing a
        /// completely different-shaped grid.
        private var boardRoot = SCNNode()
        private var cols = 8
        private var rows = 8

        private var rockNodes: [GridPos: SCNNode] = [:]
        private var gemNodes: [GridPos: SCNNode] = [:]
        private var exitNode: SCNNode?
        private var exitLight: SCNLight?

        private var playerNodes: [String: BRActorNode] = [:]
        private var enemyNodes: [String: BRActorNode] = [:]
        private var projectileRoot = SCNNode()

        private var builtLevel = -1
        private var builtWidth = -1
        private var builtHeight = -1
        private var lastTiles: [String] = []
        private var lastPhase: String?
        private var lastBlastSeenAt: Double?

        init() {
            // A reasonable default shot for an 8x8 board (level 1's size) --
            // the real board rebuilds (and the camera re-frames) the instant
            // the first real state with actual `tiles` arrives, so this is
            // only ever visible for a single unrendered frame. Kept as a
            // local constant, never a stored-property read, so nothing here
            // touches `self` before every stored property below has a value.
            let radius: Float = 8
            let initialShot = Coordinator.shot(forPhase: "playing", boardRadius: radius)
            cameraRig = CinematicCameraRig(initialShot: initialShot)
            lighting = CinematicLighting(tableRadius: radius * 0.6)

            scene.rootNode.addChildNode(cameraRig.cameraNode)
            lighting.addToScene(scene)
            scene.rootNode.addChildNode(boardRoot)
            scene.rootNode.addChildNode(projectileRoot)
        }

        // MARK: - Grid <-> world space

        private func worldX(_ col: Int) -> Float { (Float(col) - Float(cols - 1) / 2) * tileSize }
        private func worldZ(_ row: Int) -> Float { (Float(row) - Float(rows - 1) / 2) * tileSize }
        private func worldPosition(_ pos: GridPos, y: Float = 0) -> SCNVector3 {
            SCNVector3(worldX(pos.col), y, worldZ(pos.row))
        }

        // MARK: - Live state -> scene

        func apply(_ state: BlastRunnersBoardState, animated: Bool) {
            guard !state.tiles.isEmpty else { return }

            // Keyed off the level *number*, not just grid dimensions --
            // consecutive levels routinely share a width/height (levels 1-4
            // are all 8x8, say), so a dimension-only check would silently
            // keep the previous level's terrain/rock/gem nodes on screen
            // after advancing. A level-failed reset reuses the same level
            // number with an identical regenerated layout (deterministic
            // seed), so it deliberately does *not* force a rebuild here --
            // `applyRockDiff` degrades to a no-op for it (tiles are
            // unchanged) and `updateGems`/`updateEnemies`'s id/position
            // matching already reconciles the refreshed gems/enemies.
            if state.level != builtLevel || state.gridWidth != builtWidth || state.gridHeight != builtHeight {
                rebuildBoard(state: state)
            } else {
                applyRockDiff(oldTiles: lastTiles, newTiles: state.tiles, animated: animated)
            }
            lastTiles = state.tiles

            updateGems(state: state, animated: animated)
            updateExit(state: state, animated: animated)
            updatePlayers(state: state, animated: animated)
            updateEnemies(state: state, animated: animated)
            rebuildProjectiles(state: state)
            triggerBlastFXIfNeeded(state: state)

            if state.phase != lastPhase {
                lastPhase = state.phase
                let radius = Float(max(cols, rows))
                let duration: TimeInterval = animated ? 1.1 : 0
                cameraRig.transition(to: Coordinator.shot(forPhase: state.phase, boardRadius: radius), duration: duration)
                lighting.apply(Coordinator.mood(for: state.phase), duration: duration)
            }
        }

        // MARK: - Board (floor / walls / rock) -- full rebuild per level

        private func rebuildBoard(state: BlastRunnersBoardState) {
            boardRoot.removeFromParentNode()
            boardRoot = SCNNode()
            scene.rootNode.addChildNode(boardRoot)
            rockNodes.removeAll()
            gemNodes.removeAll()
            exitNode = nil
            exitLight = nil

            // Enemies are level-scoped (ids restart at "e0" each level), so
            // stale nodes from the previous level's roster must not survive
            // a rebuild -- `updateEnemies` right after this repopulates them
            // fresh from `state.enemies`.
            for node in enemyNodes.values { node.rootNode.removeFromParentNode() }
            enemyNodes.removeAll()

            cols = state.gridWidth
            rows = state.gridHeight
            builtLevel = state.level
            builtWidth = cols
            builtHeight = rows

            let ground = SCNNode(geometry: SCNBox(
                width: CGFloat(Float(cols) * tileSize + 1),
                height: 0.05,
                length: CGFloat(Float(rows) * tileSize + 1),
                chamferRadius: 0.05
            ))
            ground.geometry?.materials = [blastMaterial(color: UIColor(white: 0.01, alpha: 1), roughness: 0.9)]
            ground.position = SCNVector3(0, -0.06, 0)
            boardRoot.addChildNode(ground)

            for row in 0..<rows {
                let chars = Array(state.tiles[row])
                for col in 0..<cols where col < chars.count {
                    buildTile(pos: GridPos(col: col, row: row), char: chars[col])
                }
            }
        }

        private func buildTile(pos: GridPos, char: Character) {
            let world = worldPosition(pos)

            if char == "#" {
                let wall = SCNNode(geometry: SCNBox(
                    width: CGFloat(tileSize * 0.98), height: 0.9, length: CGFloat(tileSize * 0.98), chamferRadius: 0.03
                ))
                wall.geometry?.materials = [blastMaterial(color: brWallColor, roughness: 0.85)]
                wall.position = SCNVector3(world.x, 0.45, world.z)
                boardRoot.addChildNode(wall)
                return
            }

            let floor = SCNNode(geometry: SCNBox(
                width: CGFloat(tileSize * 0.94), height: 0.08, length: CGFloat(tileSize * 0.94), chamferRadius: 0.03
            ))
            floor.geometry?.materials = [blastMaterial(color: brFloorColor, roughness: 0.8)]
            floor.position = SCNVector3(world.x, 0.04, world.z)
            boardRoot.addChildNode(floor)

            if char == "R" {
                addRockBlock(at: pos, world: world)
            }
        }

        private func addRockBlock(at pos: GridPos, world: SCNVector3) {
            let rock = SCNNode(geometry: SCNBox(
                width: CGFloat(tileSize * 0.8), height: 0.5, length: CGFloat(tileSize * 0.8), chamferRadius: 0.06
            ))
            rock.geometry?.materials = [blastMaterial(color: brRockColor, roughness: 0.95)]
            rock.position = SCNVector3(world.x, 0.25, world.z)
            boardRoot.addChildNode(rock)
            rockNodes[pos] = rock
        }

        /// Same level, but some rock tiles changed. The common case is a
        /// blast turning 'R' into '.', which gets the destroy animation. The
        /// reverse -- a tile going back to 'R' -- doesn't happen from normal
        /// play, but it does happen on a level-failed reset: the level
        /// regenerates its identical original layout (deterministic seed),
        /// which re-arms every rock this attempt had already blasted through.
        /// Without handling that direction too, a reset would leave those
        /// tiles reading as permanently-clear floor even though the server
        /// now considers them solid rock again.
        private func applyRockDiff(oldTiles: [String], newTiles: [String], animated: Bool) {
            guard oldTiles.count == newTiles.count else { return }
            for row in 0..<newTiles.count {
                let oldChars = Array(oldTiles[row])
                let newChars = Array(newTiles[row])
                guard oldChars.count == newChars.count else { continue }
                for col in 0..<newChars.count where oldChars[col] != newChars[col] {
                    let pos = GridPos(col: col, row: row)
                    if newChars[col] == "R" {
                        if rockNodes[pos] == nil {
                            addRockBlock(at: pos, world: worldPosition(pos))
                        }
                    } else if let rock = rockNodes[pos] {
                        rockNodes.removeValue(forKey: pos)
                        destroyRock(rock, animated: animated)
                    }
                }
            }
        }

        private func destroyRock(_ rock: SCNNode, animated: Bool) {
            guard animated else {
                rock.removeFromParentNode()
                return
            }
            let shrink = SCNAction.scale(to: 0.05, duration: 0.25)
            let fade = SCNAction.fadeOut(duration: 0.25)
            shrink.timingMode = .easeIn
            rock.runAction(.group([shrink, fade])) {
                rock.removeFromParentNode()
            }
        }

        // MARK: - Gems

        private func updateGems(state: BlastRunnersBoardState, animated: Bool) {
            let wanted = Set(state.gems)

            for pos in wanted where gemNodes[pos] == nil {
                let world = worldPosition(pos)
                let gem = SCNNode(geometry: SCNBox(width: 0.22, height: 0.22, length: 0.22, chamferRadius: 0.03))
                gem.geometry?.materials = [blastMaterial(
                    color: UIColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1),
                    roughness: 0.2, metalness: 0.4,
                    emission: UIColor(red: 0.1, green: 0.55, blue: 0.7, alpha: 1)
                )]
                gem.eulerAngles = SCNVector3(0, Float.pi / 4, Float.pi / 4)
                gem.position = SCNVector3(world.x, 0.32, world.z)
                boardRoot.addChildNode(gem)
                let spin = SCNAction.rotate(by: CGFloat.pi * 2, around: SCNVector3(0, 1, 0), duration: 3.0)
                gem.runAction(.repeatForever(spin), forKey: "spin")
                gemNodes[pos] = gem
            }

            // Collect stale keys first -- removing from `gemNodes` while a
            // `for ... in gemNodes` loop is still enumerating it is a real
            // Swift crash ("Dictionary was mutated while being enumerated"),
            // not just bad style.
            let stalePositions = gemNodes.keys.filter { !wanted.contains($0) }
            for pos in stalePositions {
                guard let node = gemNodes.removeValue(forKey: pos) else { continue }
                if animated {
                    let up = SCNAction.moveBy(x: 0, y: 0.35, z: 0, duration: 0.3)
                    let fade = SCNAction.fadeOut(duration: 0.3)
                    up.timingMode = .easeOut
                    node.runAction(.group([up, fade])) { node.removeFromParentNode() }
                } else {
                    node.removeFromParentNode()
                }
            }
        }

        // MARK: - Exit

        private func updateExit(state: BlastRunnersBoardState, animated: Bool) {
            let node: SCNNode
            if let existing = exitNode {
                node = existing
            } else {
                let ring = SCNNode(geometry: SCNTorus(ringRadius: CGFloat(tileSize * 0.34), pipeRadius: 0.045))
                ring.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
                boardRoot.addChildNode(ring)

                let light = SCNLight()
                light.type = .omni
                light.intensity = 0
                let lightNode = SCNNode()
                lightNode.light = light
                lightNode.position = SCNVector3(0, 0.5, 0)
                ring.addChildNode(lightNode)

                exitNode = ring
                exitLight = light
                node = ring
            }
            node.position = worldPosition(state.exitPos, y: 0.1)

            let color: UIColor = state.exitUnlocked
                ? UIColor(red: 0.15, green: 0.95, blue: 0.35, alpha: 1)
                : UIColor(red: 0.35, green: 0.12, blue: 0.12, alpha: 1)
            let emission: UIColor = state.exitUnlocked
                ? UIColor(red: 0.1, green: 0.6, blue: 0.2, alpha: 1)
                : UIColor(red: 0.15, green: 0.03, blue: 0.03, alpha: 1)

            SCNTransaction.begin()
            SCNTransaction.animationDuration = animated ? 0.6 : 0
            node.geometry?.materials = [blastMaterial(color: color, roughness: 0.35, emission: emission)]
            exitLight?.intensity = state.exitUnlocked ? 600 : 0
            exitLight?.color = state.exitUnlocked ? UIColor.green : UIColor.red
            SCNTransaction.commit()
        }

        // MARK: - Players

        private func updatePlayers(state: BlastRunnersBoardState, animated: Bool) {
            for (index, player) in state.players.enumerated() {
                let actor: BRActorNode
                if let existing = playerNodes[player.id] {
                    actor = existing
                } else {
                    let color = brPlayerPalette[index % brPlayerPalette.count]
                    actor = BRActorNode(color: color, shape: .capsule)
                    actor.rootNode.position = worldPosition(player.pos)
                    scene.rootNode.addChildNode(actor.rootNode)
                    playerNodes[player.id] = actor
                }

                if player.alive {
                    actor.setHidden(false, animated: animated)
                    let target = worldPosition(player.pos)
                    if animated {
                        actor.walk(to: target, duration: 0.35)
                    } else {
                        actor.rootNode.position = target
                    }
                    actor.setFlashing(player.invulnerable)
                } else {
                    actor.setFlashing(false)
                    actor.setHidden(true, animated: animated)
                }
            }
        }

        // MARK: - Enemies

        private func updateEnemies(state: BlastRunnersBoardState, animated: Bool) {
            let seenIDs = Set(state.enemies.map(\.id))

            for enemy in state.enemies {
                let actor: BRActorNode
                if let existing = enemyNodes[enemy.id] {
                    actor = existing
                } else {
                    actor = BRActorNode(color: Coordinator.color(forEnemyType: enemy.type),
                                         shape: Coordinator.shape(forEnemyType: enemy.type))
                    actor.rootNode.position = worldPosition(enemy.pos)
                    scene.rootNode.addChildNode(actor.rootNode)
                    enemyNodes[enemy.id] = actor
                }
                let target = worldPosition(enemy.pos)
                if animated {
                    actor.walk(to: target, duration: 0.4)
                } else {
                    actor.rootNode.position = target
                }
            }

            // Same "collect keys first" rule as `updateGems` -- mutating
            // `enemyNodes` mid-enumeration would risk the same crash.
            let staleIDs = enemyNodes.keys.filter { !seenIDs.contains($0) }
            for id in staleIDs {
                guard let actor = enemyNodes.removeValue(forKey: id) else { continue }
                actor.rootNode.removeFromParentNode()
            }
        }

        // MARK: - Projectiles
        //
        // Bullets have no stable server-side identity across frames (the
        // server just lists whatever is currently in flight), so rather
        // than guess at matching them frame-to-frame this simply redraws
        // the whole set every update -- a small, fast-moving dot popping to
        // its next position each state push reads fine at this scale, and
        // is a lot more robust than a wrong guess at identity.

        private func rebuildProjectiles(state: BlastRunnersBoardState) {
            projectileRoot.removeFromParentNode()
            projectileRoot = SCNNode()
            scene.rootNode.addChildNode(projectileRoot)

            for projectile in state.projectiles {
                let bolt = SCNNode(geometry: SCNSphere(radius: 0.11))
                bolt.geometry?.materials = [blastMaterial(
                    color: UIColor.orange, roughness: 0.2,
                    emission: UIColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 1)
                )]
                bolt.position = worldPosition(projectile.pos, y: 0.22)
                projectileRoot.addChildNode(bolt)
            }
        }

        // MARK: - Blast FX

        private func triggerBlastFXIfNeeded(state: BlastRunnersBoardState) {
            guard let at = state.lastBlastAt, at != lastBlastSeenAt,
                  let col = state.lastBlastCol, let row = state.lastBlastRow else { return }
            lastBlastSeenAt = at
            spawnBlastBurst(at: GridPos(col: col, row: row))
        }

        /// A quick layered burst of fading/expanding primitive nodes -- the
        /// "particle-ish effect without a real SCNParticleSystem" the brief
        /// asks for.
        private func spawnBlastBurst(at pos: GridPos) {
            let center = worldPosition(pos, y: 0.3)

            let flash = SCNNode(geometry: SCNSphere(radius: 0.18))
            flash.geometry?.materials = [blastMaterial(
                color: .white, roughness: 1.0, emission: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1)
            )]
            flash.position = center
            scene.rootNode.addChildNode(flash)
            let grow = SCNAction.scale(to: 2.2, duration: 0.3)
            let fade = SCNAction.fadeOut(duration: 0.3)
            grow.timingMode = .easeOut
            flash.runAction(.group([grow, fade])) { flash.removeFromParentNode() }

            for i in 0..<6 {
                let shard = SCNNode(geometry: SCNBox(width: 0.08, height: 0.08, length: 0.08, chamferRadius: 0.01))
                shard.geometry?.materials = [blastMaterial(
                    color: brRockColor, roughness: 0.9, emission: UIColor(white: 0.15, alpha: 1)
                )]
                shard.position = center
                scene.rootNode.addChildNode(shard)
                let angle = Float(i) / 6.0 * 2 * Float.pi
                let dx = cos(angle) * 0.5
                let dz = sin(angle) * 0.5
                let fly = SCNAction.moveBy(x: CGFloat(dx), y: 0.25, z: CGFloat(dz), duration: 0.35)
                let fadeShard = SCNAction.fadeOut(duration: 0.35)
                fly.timingMode = .easeOut
                shard.runAction(.group([fly, fadeShard])) { shard.removeFromParentNode() }
            }
        }

        // MARK: - Phase -> cinematic vocabulary

        private static func shot(forPhase phase: String, boardRadius: Float) -> CameraShot {
            switch phase {
            case "levelFailed":
                return CameraShot(
                    position: SCNVector3(0, boardRadius * 0.95, boardRadius * 0.32),
                    lookAt: SCNVector3(0, 0, 0),
                    fieldOfView: 42,
                    focusDistance: CGFloat(boardRadius * 1.0)
                )
            case "levelComplete", "gameComplete":
                return CameraShot(
                    position: SCNVector3(0, boardRadius * 1.05, boardRadius * 0.5),
                    lookAt: SCNVector3(0, 0, 0),
                    fieldOfView: 46,
                    focusDistance: CGFloat(boardRadius * 1.1)
                )
            default:
                return CameraShot(
                    position: SCNVector3(0, boardRadius * 1.35, boardRadius * 0.6),
                    lookAt: SCNVector3(0, 0, 0),
                    fieldOfView: 50,
                    focusDistance: CGFloat(boardRadius * 1.3)
                )
            }
        }

        private static func mood(for phase: String) -> PhaseLightingMood {
            switch phase {
            case "levelFailed": return .tense
            case "levelComplete", "gameComplete": return .warm
            default: return .neutral
            }
        }

        private static func color(forEnemyType type: String) -> UIColor {
            switch type {
            case "chaser": return UIColor(red: 0.95, green: 0.15, blue: 0.35, alpha: 1)
            case "turret": return UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1)
            default: return UIColor(red: 0.55, green: 0.4, blue: 0.9, alpha: 1) // patroller
            }
        }

        private static func shape(forEnemyType type: String) -> BRActorShape {
            switch type {
            case "chaser": return .cone
            case "turret": return .turret
            default: return .cube // patroller
            }
        }
    }
}

private enum BRActorShape { case capsule, cube, cone, turret }

/// A small primitive-geometry character shared by both players and enemies
/// -- capsule/box/cone/cylinder only, the same discipline `PokerDealerNode`
/// and `ThiefCharacterNode` use, no imported model. `rootNode`'s position is
/// the only thing `walk(to:duration:)` touches; the idle bob loop runs
/// forever on a separate child node so a step never needs to pause it.
@MainActor
private final class BRActorNode {
    let rootNode = SCNNode()
    private let bobNode = SCNNode()

    init(color: UIColor, shape: BRActorShape) {
        rootNode.addChildNode(bobNode)
        let material = blastMaterial(color: color, roughness: 0.5, emission: color)

        switch shape {
        case .capsule:
            let body = SCNNode(geometry: SCNCapsule(capRadius: 0.16, height: 0.3))
            body.geometry?.materials = [material]
            body.position = SCNVector3(0, 0.2, 0)
            bobNode.addChildNode(body)
            let head = SCNNode(geometry: SCNSphere(radius: 0.13))
            head.geometry?.materials = [material]
            head.position = SCNVector3(0, 0.42, 0)
            bobNode.addChildNode(head)

        case .cube:
            let body = SCNNode(geometry: SCNBox(width: 0.4, height: 0.4, length: 0.4, chamferRadius: 0.05))
            body.geometry?.materials = [material]
            body.position = SCNVector3(0, 0.2, 0)
            bobNode.addChildNode(body)

        case .cone:
            let body = SCNNode(geometry: SCNCone(topRadius: 0.03, bottomRadius: 0.22, height: 0.42))
            body.geometry?.materials = [material]
            body.position = SCNVector3(0, 0.21, 0)
            bobNode.addChildNode(body)

        case .turret:
            let base = SCNNode(geometry: SCNCylinder(radius: 0.22, height: 0.3))
            base.geometry?.materials = [material]
            base.position = SCNVector3(0, 0.15, 0)
            bobNode.addChildNode(base)
            let lens = SCNNode(geometry: SCNSphere(radius: 0.1))
            lens.geometry?.materials = [blastMaterial(color: .black, roughness: 0.15, emission: color)]
            lens.position = SCNVector3(0, 0.34, 0)
            bobNode.addChildNode(lens)
        }

        startIdle()
    }

    private func startIdle() {
        let up = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 0.5)
        up.timingMode = .easeInEaseOut
        bobNode.runAction(.repeatForever(.sequence([up, up.reversed()])), forKey: "idleBob")
    }

    func walk(to worldPosition: SCNVector3, duration: TimeInterval) {
        rootNode.removeAction(forKey: "walk")
        let move = SCNAction.move(to: worldPosition, duration: duration)
        move.timingMode = .easeInEaseOut
        rootNode.runAction(move, forKey: "walk")
    }

    func setHidden(_ hidden: Bool, animated: Bool) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.4 : 0
        rootNode.opacity = hidden ? 0 : 1
        SCNTransaction.commit()
    }

    /// A brief-invulnerability flicker after respawning -- toggled on/off
    /// rather than fired once, since the server keeps reporting
    /// `invulnerable: true` for the whole window.
    func setFlashing(_ flashing: Bool) {
        if flashing {
            guard rootNode.action(forKey: "flash") == nil else { return }
            let fadeOut = SCNAction.fadeOpacity(to: 0.3, duration: 0.15)
            let fadeIn = SCNAction.fadeOpacity(to: 1.0, duration: 0.15)
            rootNode.runAction(.repeatForever(.sequence([fadeOut, fadeIn])), forKey: "flash")
        } else {
            rootNode.removeAction(forKey: "flash")
            rootNode.opacity = 1
        }
    }
}
