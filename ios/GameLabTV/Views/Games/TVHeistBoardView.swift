import SwiftUI

// MARK: - Heist — TV Board
//
// GAME RULES:
//   • 3–6 players. One is secretly the Guard, rest are Thieves.
//   • TV shows the full vault floor plan (5×7 grid).
//   • Guard's phone shows camera positions + coverage arcs (private).
//   • Thieves' phones show only their own position (private).
//   • Each round: Guard sets cameras (phone), Thieves move 1 tile (phone).
//   • If a Thief lands on a camera-covered tile → caught, eliminated.
//   • Thieves must reach the Vault tile (center) and escape to EXIT tile.
//   • Guard wins if all Thieves caught. Thieves win if any escapes.

struct TVHeistBoardView: View {
    let room: Room
    @StateObject private var vm = HeistBoardViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Main board — 5/7 width
            ZStack {
                Color(hex: "0a0a14").ignoresSafeArea()

                VStack(spacing: 24) {
                    headerBar
                    boardGrid
                }
                .padding(48)
            }
            .frame(maxWidth: .infinity)

            // Right sidebar — player status
            playerSidebar
                .frame(width: 320)
                .background(Color.white.opacity(0.04))
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🏦 Heist")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                Text("Round \(vm.state.round) of \(HeistConstants.maxRounds)")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Phase indicator
            PhaseTag(phase: vm.state.phase)

            Spacer()

            // Countdown timer ring
            TimerRing(
                secondsLeft: vm.state.secondsLeft,
                total: HeistConstants.secondsPerPhase
            )
        }
    }

    // MARK: - Board Grid

    private var boardGrid: some View {
        let cols = HeistConstants.cols
        let rows = HeistConstants.rows

        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { col in
                        let pos = GridPos(col: col, row: row)
                        HeistTile(
                            pos: pos,
                            tileType: vm.state.tileType(at: pos),
                            cameraArc: vm.state.cameraArcCovers(pos),
                            thieves: vm.state.thieves(at: pos),
                            isGuardKnown: vm.state.isGuardRevealedAt(pos)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Sidebar

    private var playerSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Players")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
                .padding(24)

            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(vm.state.playerStatuses) { status in
                        HeistPlayerRow(status: status)
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }

            Spacer()

            if let winner = vm.state.winner {
                WinnerBanner(winner: winner)
                    .padding(24)
            }
        }
    }
}

// MARK: - Tile View

private struct HeistTile: View {
    let pos: GridPos
    let tileType: HeistTileType
    let cameraArc: Bool        // true → camera watches this tile this round
    let thieves: [HeistThiefStatus]
    let isGuardKnown: Bool

    var body: some View {
        ZStack {
            // Base tile
            RoundedRectangle(cornerRadius: 6)
                .fill(baseFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(borderColor, lineWidth: 1)
                )

            // Camera coverage overlay
            if cameraArc {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(0.25))
                    .overlay(
                        Image(systemName: "video.fill")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.7))
                            .padding(2),
                        alignment: .topTrailing
                    )
            }

            // Tile icon
            tileIcon

            // Thieves (shown as coloured dots)
            if !thieves.isEmpty {
                HStack(spacing: 3) {
                    ForEach(thieves) { t in
                        Circle()
                            .fill(t.color)
                            .frame(width: 14, height: 14)
                            .shadow(color: t.color, radius: 4)
                    }
                }
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: tileSize, height: tileSize)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: thieves.map(\.id))
    }

    private var tileSize: CGFloat { 88 }

    private var baseFill: Color {
        switch tileType {
        case .empty:   return Color(hex: "1a1a2e")
        case .wall:    return Color(hex: "0d0d14")
        case .vault:   return Color(hex: "2d1b00")
        case .exit:    return Color(hex: "0d2d00")
        case .camera:  return Color(hex: "2d0000")
        }
    }

    private var borderColor: Color {
        switch tileType {
        case .vault:  return .yellow.opacity(0.6)
        case .exit:   return .green.opacity(0.6)
        case .camera: return .red.opacity(0.4)
        default:      return Color.white.opacity(0.06)
        }
    }

    @ViewBuilder
    private var tileIcon: some View {
        switch tileType {
        case .vault:
            Text("💰").font(.system(size: 28))
        case .exit:
            Text("🚪").font(.system(size: 28))
        case .camera:
            Text("📷").font(.system(size: 22)).opacity(isGuardKnown ? 1 : 0)
        case .wall:
            Rectangle()
                .fill(Color(hex: "080810"))
                .cornerRadius(4)
                .padding(4)
        default:
            EmptyView()
        }
    }
}

// MARK: - Supporting views

private struct PhaseTag: View {
    let phase: HeistPhase

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(phase.color).frame(width: 10, height: 10)
            Text(phase.label)
                .font(.headline)
                .foregroundColor(phase.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(phase.color.opacity(0.15)))
    }
}

private struct TimerRing: View {
    let secondsLeft: Int
    let total: Int

    private var progress: Double { Double(secondsLeft) / Double(total) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progress > 0.4 ? Color.cyan : Color.red,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: secondsLeft)
            Text("\(secondsLeft)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(width: 70, height: 70)
    }
}

private struct HeistPlayerRow: View {
    let status: HeistPlayerStatus

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(status.role == .guard ? Color.red.opacity(0.3) : status.color.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(status.role == .guard ? "🛡" : "🥷")
                        .font(.system(size: 18))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(status.name)
                    .font(.body)
                    .foregroundColor(status.isCaught ? .white.opacity(0.3) : .white)
                Text(status.role == .guard ? "Guard" : status.isCaught ? "Caught" : "Thief")
                    .font(.caption)
                    .foregroundColor(status.role == .guard ? .red.opacity(0.7) : .white.opacity(0.4))
            }

            Spacer()

            if status.hasEscaped {
                Text("ESCAPED").font(.caption2.bold()).foregroundColor(.green)
            } else if status.isCaught {
                Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .opacity(status.isCaught ? 0.5 : 1)
    }
}

private struct WinnerBanner: View {
    let winner: HeistWinner

    var body: some View {
        VStack(spacing: 8) {
            Text(winner == .guard ? "🛡 Guard Wins!" : "🥷 Thieves Win!")
                .font(.title3.bold())
                .foregroundColor(winner == .guard ? .red : .green)
            Text(winner == .guard ? "All thieves caught." : "A thief escaped!")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(winner == .guard ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
        )
    }
}

// MARK: - ViewModel

@MainActor
final class HeistBoardViewModel: ObservableObject {
    @Published var state = HeistBoardState()
    private let socket = GameSocketManager.shared

    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (response: GameStateResponse) in
            guard response.roomCode == roomCode else { return }
            self?.state.update(from: response.boardState)
        }
    }
}

// MARK: - State

struct HeistBoardState {
    var round = 1
    var phase: HeistPhase = .guardSets
    var secondsLeft = HeistConstants.secondsPerPhase
    var grid: [[HeistTileType]] = HeistBoardState.defaultGrid()
    var cameraPositions: [GridPos] = []           // Guard-controlled this round
    var cameraArcTiles: Set<GridPos> = []          // Computed from camera angles
    var thiefPositions: [String: GridPos] = [:]    // playerID → pos (revealed on TV)
    var playerStatuses: [HeistPlayerStatus] = []
    var winner: HeistWinner? = nil

    // Build the grid only once (layout is static)
    static func defaultGrid() -> [[HeistTileType]] {
        let cols = HeistConstants.cols
        let rows = HeistConstants.rows
        var g = Array(repeating: Array(repeating: HeistTileType.empty, count: cols), count: rows)

        // Walls along border
        for c in 0..<cols { g[0][c] = .wall; g[rows-1][c] = .wall }
        for r in 0..<rows { g[r][0] = .wall; g[r][cols-1] = .wall }

        // Inner wall obstacles
        let walls: [GridPos] = [
            .init(col:2,row:1), .init(col:2,row:2), .init(col:2,row:3),
            .init(col:4,row:3), .init(col:4,row:4), .init(col:4,row:5),
            .init(col:2,row:5), .init(col:2,row:6)
        ]
        for w in walls { g[w.row][w.col] = .wall }

        // Camera stands (Guard can use these)
        let cameras: [GridPos] = [
            .init(col:1,row:1), .init(col:5,row:1),
            .init(col:1,row:5), .init(col:5,row:5)
        ]
        for c in cameras { g[c.row][c.col] = .camera }

        // Vault in centre
        g[HeistConstants.rows/2][HeistConstants.cols/2] = .vault

        // Exits
        g[3][0] = .exit
        g[3][cols-1] = .exit

        return g
    }

    func tileType(at pos: GridPos) -> HeistTileType {
        guard pos.row >= 0, pos.row < grid.count,
              pos.col >= 0, pos.col < grid[0].count else { return .wall }
        return grid[pos.row][pos.col]
    }

    func cameraArcCovers(_ pos: GridPos) -> Bool { cameraArcTiles.contains(pos) }

    func thieves(at pos: GridPos) -> [HeistThiefStatus] {
        playerStatuses.filter {
            $0.role == .thief && !$0.isCaught && thiefPositions[$0.id] == pos
        }.map { HeistThiefStatus(id: $0.id, color: $0.color) }
    }

    func isGuardRevealedAt(_ pos: GridPos) -> Bool { cameraPositions.contains(pos) }

    mutating func update(from data: [String: AnyCodable]) {
        if let r = data["round"]?.value as? Int       { round = r }
        if let s = data["secondsLeft"]?.value as? Int { secondsLeft = s }
        if let p = data["phase"]?.value as? String    { phase = HeistPhase(rawValue: p) ?? .guardSets }
        // Camera arcs, thief positions, and player statuses decoded similarly
        // (full server payload parsing omitted for brevity — server sends these fields)
    }
}

// MARK: - Supporting types

struct GridPos: Hashable, Codable {
    let col: Int
    let row: Int
}

enum HeistTileType { case empty, wall, vault, exit, camera }

enum HeistPhase: String {
    case guardSets  = "guard_sets"
    case thievesMove = "thieves_move"
    case reveal     = "reveal"

    var label: String {
        switch self {
        case .guardSets:   return "Guard Setting Cameras"
        case .thievesMove: return "Thieves Moving"
        case .reveal:      return "Reveal"
        }
    }
    var color: Color {
        switch self {
        case .guardSets:   return .red
        case .thievesMove: return .cyan
        case .reveal:      return .yellow
        }
    }
}

enum HeistWinner { case guard_, thieves }
// disambiguate keyword
extension HeistWinner {
    static let `guard` = HeistWinner.guard_
}

struct HeistPlayerStatus: Identifiable {
    let id: String
    let name: String
    let role: HeistRole
    let color: Color
    var isCaught: Bool
    var hasEscaped: Bool
}

struct HeistThiefStatus: Identifiable {
    let id: String
    let color: Color
}

enum HeistRole { case `guard`, thief }

enum HeistConstants {
    static let cols = 7
    static let rows = 7
    static let maxRounds = 8
    static let secondsPerPhase = 20
}
