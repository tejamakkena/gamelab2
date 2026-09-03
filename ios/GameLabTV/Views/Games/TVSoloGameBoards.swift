import SwiftUI

/// Boards for the games playable with the Siri Remote alone.
///
/// These differ from every other board in the app: they both render the game
/// *and* collect input, sending it through `TVRootViewModel.sendAction` because
/// there is no phone in the room to send it for them.

// MARK: - Shared chrome

private struct SoloHUD: View {
    let title: String
    let score: Int
    let subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("SCORE").font(.caption.bold()).tracking(3)
                    .foregroundColor(.white.opacity(0.4))
                Text("\(score)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 80)
        .padding(.top, 50)
    }
}

private struct RemoteHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundColor(.white.opacity(0.35))
            .padding(.bottom, 40)
    }
}

private struct GameOverBanner: View {
    let score: Int
    var body: some View {
        VStack(spacing: 10) {
            Text("GAME OVER").font(.system(size: 44, weight: .heavy)).tracking(4)
                .foregroundColor(.red)
            Text("Final score \(score)").font(.title2).foregroundColor(.white.opacity(0.7))
        }
        .padding(40)
        .background(RoundedRectangle(cornerRadius: 24).fill(.black.opacity(0.75)))
    }
}

// MARK: - Neon Snake

struct SnakeState {
    var width = 20, height = 20
    var food = (x: 10, y: 10)
    var bodies: [[(x: Int, y: Int)]] = []
    var colors: [Bool] = []          // alive flags, parallel to bodies
    var score = 0
    var finished = false

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["width"]?.value as? Int  { width = v }
        if let v = data["height"]?.value as? Int { height = v }
        if let f = data["food"]?.value as? [String: Any],
           let fx = f["x"] as? Int, let fy = f["y"] as? Int { food = (fx, fy) }
        if let v = data["finished"]?.value as? Bool { finished = v }
        if let snakes = data["snakes"]?.value as? [Any] {
            bodies = []; colors = []; score = 0
            for raw in snakes {
                guard let s = raw as? [String: Any] else { continue }
                let cells = (s["body"] as? [Any] ?? []).compactMap { item -> (x: Int, y: Int)? in
                    guard let c = item as? [String: Any],
                          let x = c["x"] as? Int, let y = c["y"] as? Int else { return nil }
                    return (x, y)
                }
                bodies.append(cells)
                colors.append(s["alive"] as? Bool ?? false)
                score = max(score, s["score"] as? Int ?? 0)
            }
        }
    }
}

@MainActor final class SnakeBoardViewModel: ObservableObject {
    @Published var state = SnakeState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

struct TVNeonSnakeBoardView: View {
    let room: Room
    @EnvironmentObject private var root: TVRootViewModel
    @StateObject private var vm = SnakeBoardViewModel()

    private let cell: CGFloat = 34

    var body: some View {
        VStack(spacing: 0) {
            SoloHUD(title: "🐍 Neon Snake", score: vm.state.score, subtitle: nil)
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 3)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.4)))

                Canvas { ctx, _ in
                    let f = vm.state.food
                    ctx.fill(Path(roundedRect: CGRect(x: CGFloat(f.x) * cell + 3,
                                                      y: CGFloat(f.y) * cell + 3,
                                                      width: cell - 6, height: cell - 6),
                                  cornerRadius: 6),
                             with: .color(.yellow))

                    for (i, body) in vm.state.bodies.enumerated() {
                        let alive = i < vm.state.colors.count ? vm.state.colors[i] : false
                        for (j, c) in body.enumerated() {
                            let shade = alive ? 1.0 - Double(j) / Double(max(body.count, 12)) * 0.55 : 0.2
                            ctx.fill(
                                Path(roundedRect: CGRect(x: CGFloat(c.x) * cell + 2,
                                                         y: CGFloat(c.y) * cell + 2,
                                                         width: cell - 4, height: cell - 4),
                                     cornerRadius: 7),
                                with: .color(.cyan.opacity(shade))
                            )
                        }
                    }
                }
                .frame(width: CGFloat(vm.state.width) * cell,
                       height: CGFloat(vm.state.height) * cell)

                if vm.state.finished { GameOverBanner(score: vm.state.score) }
            }
            .frame(width: CGFloat(vm.state.width) * cell + 8,
                   height: CGFloat(vm.state.height) * cell + 8)
            Spacer()
            RemoteHint(text: "Swipe or click the remote's edges to steer")
        }
        .remoteDPad { event in
            if let dir = event.directionName {
                root.sendAction("turn", ["direction": dir])
            }
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

// MARK: - 2048

struct Twenty48State {
    var size = 4
    var tiles: [Int] = Array(repeating: 0, count: 16)
    var score = 0
    var best = 0
    var done = false

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["size"]?.value as? Int { size = v }
        if let boards = data["boards"]?.value as? [Any],
           let first = boards.first as? [String: Any] {
            if let t = first["tiles"] as? [Any] { tiles = t.compactMap { $0 as? Int } }
            if let v = first["score"] as? Int { score = v }
            if let v = first["best"]  as? Int { best = v }
            if let v = first["done"]  as? Bool { done = v }
        }
    }
}

@MainActor final class Twenty48ViewModel: ObservableObject {
    @Published var state = Twenty48State()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

struct TVTwenty48BoardView: View {
    let room: Room
    @EnvironmentObject private var root: TVRootViewModel
    @StateObject private var vm = Twenty48ViewModel()

    private let tile: CGFloat = 130

    /// The familiar 2048 ramp — warmer as the value climbs.
    private func color(for value: Int) -> Color {
        switch value {
        case 0:     return .white.opacity(0.06)
        case 2:     return Color(hex: "eee4da")
        case 4:     return Color(hex: "ede0c8")
        case 8:     return Color(hex: "f2b179")
        case 16:    return Color(hex: "f59563")
        case 32:    return Color(hex: "f67c5f")
        case 64:    return Color(hex: "f65e3b")
        case 128:   return Color(hex: "edcf72")
        case 256:   return Color(hex: "edcc61")
        case 512:   return Color(hex: "edc850")
        case 1024:  return Color(hex: "edc53f")
        default:    return Color(hex: "edc22e")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SoloHUD(title: "2️⃣ 2048", score: vm.state.score,
                    subtitle: "best tile \(vm.state.best)")
            Spacer()
            ZStack {
                VStack(spacing: 12) {
                    ForEach(0..<vm.state.size, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(0..<vm.state.size, id: \.self) { col in
                                let idx = row * vm.state.size + col
                                let value = idx < vm.state.tiles.count ? vm.state.tiles[idx] : 0
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(color(for: value))
                                    .frame(width: tile, height: tile)
                                    .overlay(
                                        Text(value > 0 ? "\(value)" : "")
                                            .font(.system(size: value > 999 ? 40 : 52,
                                                          weight: .heavy, design: .rounded))
                                            .foregroundColor(value <= 4 ? Color(hex: "776e65") : .white)
                                    )
                                    .animation(.easeOut(duration: 0.12), value: value)
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.05)))

                if vm.state.done { GameOverBanner(score: vm.state.score) }
            }
            Spacer()
            RemoteHint(text: "Swipe the remote's touch surface to slide the tiles")
        }
        .remoteSwipe { event in
            if let dir = event.directionName {
                root.sendAction("swipe", ["direction": dir])
            }
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

// MARK: - Brick Breaker

struct BrickState {
    var width: Double = 100, height: Double = 140
    var ball = (x: 50.0, y: 100.0)
    var paddle: Double = 50
    var paddleWidth: Double = 20
    var bricks: [(id: Int, x: Double, y: Double, w: Double, h: Double)] = []
    var lives = 3
    var score = 0
    var finished = false

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["width"]?.value  as? Double { width = v }
        if let v = data["height"]?.value as? Double { height = v }
        if let b = data["ball"]?.value as? [String: Any],
           let x = b["x"] as? Double, let y = b["y"] as? Double { ball = (x, y) }
        if let v = data["paddle"]?.value as? Double { paddle = v }
        if let v = data["paddleWidth"]?.value as? Double { paddleWidth = v }
        if let v = data["lives"]?.value as? Int { lives = v }
        if let v = data["score"]?.value as? Int { score = v }
        if let v = data["finished"]?.value as? Bool { finished = v }
        if let raw = data["bricks"]?.value as? [Any] {
            bricks = raw.compactMap { item in
                guard let b = item as? [String: Any],
                      let id = b["id"] as? Int,
                      let x = b["x"] as? Double, let y = b["y"] as? Double,
                      let w = b["w"] as? Double, let h = b["h"] as? Double
                else { return nil }
                return (id, x, y, w, h)
            }
        }
    }
}

@MainActor final class BrickViewModel: ObservableObject {
    @Published var state = BrickState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

struct TVBrickBreakerBoardView: View {
    let room: Room
    @EnvironmentObject private var root: TVRootViewModel
    @StateObject private var vm = BrickViewModel()

    private let scale: CGFloat = 7.0

    var body: some View {
        VStack(spacing: 0) {
            SoloHUD(title: "🧱 Brick Breaker", score: vm.state.score,
                    subtitle: String(repeating: "♥", count: max(0, vm.state.lives)))
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 3)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.4)))

                Canvas { ctx, _ in
                    for brick in vm.state.bricks {
                        // Colour by row so the wall reads as bands.
                        let band = Int(brick.y / 7) % 5
                        let colors: [Color] = [.red, .orange, .yellow, .green, .cyan]
                        ctx.fill(
                            Path(roundedRect: CGRect(x: brick.x * scale, y: brick.y * scale,
                                                     width: brick.w * scale, height: brick.h * scale),
                                 cornerRadius: 4),
                            with: .color(colors[band])
                        )
                    }
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: (vm.state.ball.x - 1.6) * scale,
                                               y: (vm.state.ball.y - 1.6) * scale,
                                               width: 3.2 * scale, height: 3.2 * scale)),
                        with: .color(.white)
                    )
                    ctx.fill(
                        Path(roundedRect: CGRect(
                            x: (vm.state.paddle - vm.state.paddleWidth / 2) * scale,
                            y: (vm.state.height - 10) * scale,
                            width: vm.state.paddleWidth * scale, height: 3 * scale),
                             cornerRadius: 5),
                        with: .color(.cyan)
                    )
                }
                .frame(width: vm.state.width * scale, height: vm.state.height * scale)

                if vm.state.finished { GameOverBanner(score: vm.state.score) }
            }
            .frame(width: vm.state.width * scale + 8, height: vm.state.height * scale + 8)
            Spacer()
            RemoteHint(text: "Drag across the remote to move the paddle")
        }
        .remoteScrub { event in
            if case .scrub(let t) = event {
                root.sendAction("paddle", ["x": t * vm.state.width])
            }
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

// MARK: - Simon Says

struct SimonState {
    var phase = "show"
    var round = 0
    var sequence: [String] = []
    var progress = 0
    var currentName = ""
    var finished = false

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["phase"]?.value as? String { phase = v }
        if let v = data["round"]?.value as? Int    { round = v }
        if let v = data["progress"]?.value as? Int { progress = v }
        if let v = data["currentName"]?.value as? String { currentName = v }
        if let v = data["finished"]?.value as? Bool { finished = v }
        // Empty during the input phase by design — the answer must not be on screen.
        sequence = (data["sequence"]?.value as? [Any])?.compactMap { $0 as? String } ?? []
    }
}

@MainActor final class SimonViewModel: ObservableObject {
    @Published var state = SimonState()
    @Published var litPad: String? = nil
    private let socket = GameSocketManager.shared
    private var playbackTask: Task<Void, Never>?

    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard let self, r.roomCode == roomCode else { return }
            let wasShowing = self.state.phase == "show"
            self.state.update(from: r.boardState)
            if self.state.phase == "show", !wasShowing || self.playbackTask == nil {
                self.playSequence()
            }
        }
    }

    /// Flash the sequence once when the show phase begins. The server's own
    /// show-phase timer is sized to match this playback.
    private func playSequence() {
        playbackTask?.cancel()
        let steps = state.sequence
        playbackTask = Task { @MainActor in
            for pad in steps {
                litPad = pad
                try? await Task.sleep(nanoseconds: 420_000_000)
                litPad = nil
                try? await Task.sleep(nanoseconds: 260_000_000)
                if Task.isCancelled { return }
            }
        }
    }

    func flash(_ pad: String) {
        litPad = pad
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            if litPad == pad { litPad = nil }
        }
    }
}

struct TVSimonSaysBoardView: View {
    let room: Room
    @EnvironmentObject private var root: TVRootViewModel
    @StateObject private var vm = SimonViewModel()

    private let pads = ["up", "right", "down", "left"]
    private let colors: [String: Color] = [
        "up": .green, "right": .red, "down": .yellow, "left": .blue,
    ]

    var body: some View {
        VStack(spacing: 0) {
            SoloHUD(title: "🟩 Simon Says", score: vm.state.round,
                    subtitle: vm.state.phase == "show" ? "watch…" : "your turn")
            Spacer()
            ZStack {
                VStack(spacing: 18) {
                    pad("up")
                    HStack(spacing: 18) { pad("left"); pad("right") }
                    pad("down")
                }
                if vm.state.finished { GameOverBanner(score: vm.state.round) }
            }
            Spacer()
            RemoteHint(text: vm.state.phase == "show"
                       ? "Watch the sequence"
                       : "Repeat it with the remote's D-pad")
        }
        .remoteDPad { event in
            guard vm.state.phase == "input", let dir = event.directionName else { return }
            vm.flash(dir)
            root.sendAction("pad", ["pad": dir])
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }

    private func pad(_ name: String) -> some View {
        let lit = vm.litPad == name
        return RoundedRectangle(cornerRadius: 24)
            .fill((colors[name] ?? .gray).opacity(lit ? 1.0 : 0.28))
            .frame(width: 220, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(lit ? 0.9 : 0.15), lineWidth: lit ? 5 : 2)
            )
            .scaleEffect(lit ? 1.06 : 1.0)
            .animation(.easeOut(duration: 0.12), value: lit)
    }
}

// MARK: - Atlas

struct AtlasState {
    var letter = ""
    var chain: [(place: String, name: String)] = []
    var chainLength = 0
    var secondsLeft = 0
    var currentName = ""
    var finished = false

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["letter"]?.value as? String { letter = v }
        if let v = data["chainLength"]?.value as? Int { chainLength = v }
        if let v = data["secondsLeft"]?.value as? Int { secondsLeft = v }
        if let v = data["currentName"]?.value as? String { currentName = v }
        if let v = data["finished"]?.value as? Bool { finished = v }
        if let raw = data["chain"]?.value as? [Any] {
            chain = raw.compactMap { item in
                guard let c = item as? [String: Any],
                      let place = c["place"] as? String else { return nil }
                return (place, c["name"] as? String ?? "")
            }
        }
    }
}

@MainActor final class AtlasViewModel: ObservableObject {
    @Published var state = AtlasState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

struct TVAtlasBoardView: View {
    let room: Room
    @StateObject private var vm = AtlasViewModel()

    var body: some View {
        VStack(spacing: 0) {
            SoloHUD(title: "🌍 Atlas", score: vm.state.chainLength,
                    subtitle: vm.state.currentName.isEmpty ? nil : "\(vm.state.currentName)'s turn")
            Spacer()
            VStack(spacing: 34) {
                VStack(spacing: 8) {
                    Text("NEXT PLACE STARTS WITH")
                        .font(.caption.bold()).tracking(4)
                        .foregroundColor(.white.opacity(0.4))
                    Text(vm.state.letter)
                        .font(.system(size: 150, weight: .heavy, design: .rounded))
                        .foregroundColor(.cyan)
                }

                TimerRing(secondsLeft: vm.state.secondsLeft, total: 20)
                    .frame(width: 120, height: 120)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(vm.state.chain.enumerated()), id: \.offset) { _, entry in
                            VStack(spacing: 4) {
                                Text(entry.place).font(.title3.bold()).foregroundColor(.white)
                                Text(entry.name).font(.caption)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 22).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(.white.opacity(0.07)))
                        }
                    }
                    .padding(.horizontal, 80)
                }
            }
            Spacer()
            RemoteHint(text: "Type the next place on a phone, or pass the remote around")
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}
