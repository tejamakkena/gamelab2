import SwiftUI

/// Boards for the duel and co-op games.

// MARK: - Defuse

struct DefuseState {
    var secondsLeft = 0
    var strikes = 0
    var maxStrikes = 3
    var moduleIndex = 0
    var moduleCount = 0
    var moduleType = ""
    var wires: [String] = []
    var buttonColour = ""
    var buttonLabel = ""
    var symbols: [String] = []
    var won = false
    var finished = false
    var defuserName = ""
    var log: [String] = []

    mutating func update(from d: [String: AnyCodable]) {
        if let v = d["secondsLeft"]?.value as? Int { secondsLeft = v }
        if let v = d["strikes"]?.value as? Int { strikes = v }
        if let v = d["maxStrikes"]?.value as? Int { maxStrikes = v }
        if let v = d["moduleIndex"]?.value as? Int { moduleIndex = v }
        if let v = d["moduleCount"]?.value as? Int { moduleCount = v }
        if let v = d["won"]?.value as? Bool { won = v }
        if let v = d["finished"]?.value as? Bool { finished = v }
        if let v = d["defuserName"]?.value as? String { defuserName = v }
        log = (d["log"]?.value as? [Any] ?? []).compactMap { $0 as? String }
        // The module is public but carries neither the answer nor the manual.
        if let m = d["module"]?.value as? [String: Any] {
            moduleType = m["type"] as? String ?? ""
            wires = (m["wires"] as? [Any] ?? []).compactMap { $0 as? String }
            buttonColour = m["colour"] as? String ?? ""
            buttonLabel = m["label"] as? String ?? ""
            symbols = (m["symbols"] as? [Any] ?? []).compactMap { $0 as? String }
        }
    }
}

struct TVDefuseBoardView: View {
    let room: Room
    @StateObject private var vm = TVBoardModel(initial: DefuseState()) { $0.update(from: $1) }

    private func wireColor(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "blue": return .blue
        case "yellow": return .yellow
        case "white": return .white
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🧨 Defuse").font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(vm.state.defuserName) holds the bomb — everyone else has the manual")
                        .font(.headline).foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<vm.state.maxStrikes, id: \.self) { i in
                        Text("✕").font(.title.bold())
                            .foregroundColor(i < vm.state.strikes ? .red : .white.opacity(0.15))
                    }
                }
                Text(String(format: "%d:%02d", vm.state.secondsLeft / 60, vm.state.secondsLeft % 60))
                    .font(.system(size: 62, weight: .heavy, design: .monospaced))
                    .foregroundColor(vm.state.secondsLeft < 30 ? .red : .green)
            }
            .padding(.horizontal, 70).padding(.top, 44)

            Spacer()

            if vm.state.finished {
                VStack(spacing: 16) {
                    Text(vm.state.won ? "💚" : "💥").font(.system(size: 130))
                    Text(vm.state.won ? "DEFUSED" : "BOOM")
                        .font(.system(size: 64, weight: .heavy)).tracking(6)
                        .foregroundColor(vm.state.won ? .green : .red)
                }
            } else {
                VStack(spacing: 30) {
                    Text("MODULE \(vm.state.moduleIndex + 1) OF \(vm.state.moduleCount)")
                        .font(.caption.bold()).tracking(4).foregroundColor(.white.opacity(0.4))

                    switch vm.state.moduleType {
                    case "wires":
                        VStack(spacing: 18) {
                            ForEach(Array(vm.state.wires.enumerated()), id: \.offset) { i, w in
                                HStack(spacing: 20) {
                                    Text("\(i + 1)").font(.title2.bold())
                                        .foregroundColor(.white.opacity(0.4)).frame(width: 40)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(wireColor(w))
                                        .frame(width: 460, height: 22)
                                }
                            }
                        }
                    case "button":
                        VStack(spacing: 18) {
                            Circle().fill(wireColor(vm.state.buttonColour))
                                .frame(width: 220, height: 220)
                                .overlay(Text(vm.state.buttonLabel)
                                    .font(.system(size: 30, weight: .heavy))
                                    .foregroundColor(vm.state.buttonColour == "white" ? .black : .white))
                        }
                    case "symbols":
                        HStack(spacing: 24) {
                            ForEach(Array(vm.state.symbols.enumerated()), id: \.offset) { i, s in
                                VStack(spacing: 10) {
                                    Text(s).font(.system(size: 76)).foregroundColor(.white)
                                    Text("\(i + 1)").font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .frame(width: 150, height: 180)
                                .background(RoundedRectangle(cornerRadius: 14)
                                    .fill(.white.opacity(0.07)))
                            }
                        }
                    default:
                        ProgressView().tint(.white)
                    }
                }
            }

            Spacer()
            HStack(spacing: 16) {
                ForEach(vm.state.log, id: \.self) { entry in
                    Text(entry).font(.callout)
                        .foregroundColor(entry.hasPrefix("Strike") ? .red : .green)
                }
            }
            .padding(.bottom, 40)
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

// MARK: - Battleship

struct BattleshipState {
    var size = 8
    var boards: [(ownerName: String, shots: [Int: String], sunk: Int)] = []
    var currentPlayerID: String? = nil
    var winner: String? = nil
    var players: [BoardPlayer] = []

    mutating func update(from d: [String: AnyCodable]) {
        if let v = d["size"]?.value as? Int { size = v }
        currentPlayerID = d["currentPlayerID"]?.value as? String
        winner = d["winner"]?.value as? String
        players = BoardPlayer.list(from: d["players"]?.value)
        boards = (d["boards"]?.value as? [Any] ?? []).compactMap {
            guard let b = $0 as? [String: Any] else { return nil }
            var shots: [Int: String] = [:]
            for item in (b["shots"] as? [Any] ?? []) {
                if let s = item as? [String: Any],
                   let cell = s["cell"] as? Int, let r = s["result"] as? String {
                    shots[cell] = r
                }
            }
            return (b["ownerName"] as? String ?? "", shots, b["sunk"] as? Int ?? 0)
        }
    }
}

struct TVBattleshipBoardView: View {
    let room: Room
    @StateObject private var vm = TVBoardModel(initial: BattleshipState()) { $0.update(from: $1) }

    var body: some View {
        VStack(spacing: 0) {
            TVRoundHeader(emoji: "🚢", title: "Battleship",
                          round: 0, totalRounds: 0, secondsLeft: 0,
                          phaseLabel: vm.state.winner != nil ? "game over" : "fire!")
            Spacer()
            HStack(spacing: 90) {
                ForEach(Array(vm.state.boards.enumerated()), id: \.offset) { _, board in
                    VStack(spacing: 16) {
                        Text(board.ownerName).font(.title2.bold()).foregroundColor(.white)
                        Text("\(board.sunk) ships sunk").font(.callout)
                            .foregroundColor(.cyan)
                        // Only hits and misses — fleet positions stay on the phones.
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(52), spacing: 5),
                                                 count: vm.state.size), spacing: 5) {
                            ForEach(0..<(vm.state.size * vm.state.size), id: \.self) { cell in
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(board.shots[cell] == "hit" ? Color.red
                                          : board.shots[cell] == "miss" ? Color.white.opacity(0.22)
                                          : Color.blue.opacity(0.28))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Text(board.shots[cell] == "hit" ? "💥"
                                             : board.shots[cell] == "miss" ? "·" : "")
                                            .font(.title3)
                                    )
                            }
                        }
                    }
                }
            }
            if let winner = vm.state.winner,
               let name = vm.state.players.first(where: { $0.id == winner })?.name {
                Text("🏆 \(name) wins")
                    .font(.system(size: 44, weight: .heavy)).foregroundColor(.yellow)
                    .padding(.top, 26)
            }
            Spacer()
            TVScoreStrip(players: vm.state.players)
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

// MARK: - Air Hockey

struct AirHockeyState {
    var width: Double = 100, height: Double = 160
    var puck = (x: 50.0, y: 80.0)
    var paddles: [(name: String, x: Double, score: Int)] = []
    var paddleWidth: Double = 18
    var winScore = 7
    var finished = false

    mutating func update(from d: [String: AnyCodable]) {
        if let v = d["width"]?.value as? Double { width = v }
        if let v = d["height"]?.value as? Double { height = v }
        if let p = d["puck"]?.value as? [String: Any],
           let x = p["x"] as? Double, let y = p["y"] as? Double { puck = (x, y) }
        if let v = d["paddleWidth"]?.value as? Double { paddleWidth = v }
        if let v = d["winScore"]?.value as? Int { winScore = v }
        if let v = d["finished"]?.value as? Bool { finished = v }
        paddles = (d["paddles"]?.value as? [Any] ?? []).compactMap {
            guard let p = $0 as? [String: Any] else { return nil }
            return (p["name"] as? String ?? "", p["x"] as? Double ?? 50,
                    p["score"] as? Int ?? 0)
        }
    }
}

struct TVAirHockeyBoardView: View {
    let room: Room
    @StateObject private var vm = TVBoardModel(initial: AirHockeyState()) { $0.update(from: $1) }

    private let scale: CGFloat = 6.0

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    ForEach(Array(vm.state.paddles.enumerated()), id: \.offset) { i, p in
                        VStack(spacing: 2) {
                            Text(p.name).font(.headline).foregroundColor(.white.opacity(0.6))
                            Text("\(p.score)").font(.system(size: 54, weight: .heavy))
                                .foregroundColor(i == 0 ? .cyan : .pink)
                        }
                        if i == 0 { Spacer() }
                    }
                }
                .padding(.horizontal, 120).padding(.top, 40)
                Spacer()
            }

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.25), lineWidth: 3)
                    .background(RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.45)))

                Canvas { ctx, size in
                    // Centre line and circle
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: size.height / 2))
                    line.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    ctx.stroke(line, with: .color(.white.opacity(0.15)), lineWidth: 2)
                    ctx.stroke(Path(ellipseIn: CGRect(x: size.width / 2 - 60,
                                                      y: size.height / 2 - 60,
                                                      width: 120, height: 120)),
                               with: .color(.white.opacity(0.15)), lineWidth: 2)

                    // Paddles
                    for (i, p) in vm.state.paddles.enumerated() {
                        let y: CGFloat = i == 0 ? 6 * scale : (vm.state.height - 6) * scale
                        ctx.fill(
                            Path(roundedRect: CGRect(
                                x: (p.x - vm.state.paddleWidth / 2) * scale, y: y - 8,
                                width: vm.state.paddleWidth * scale, height: 16),
                                 cornerRadius: 8),
                            with: .color(i == 0 ? .cyan : .pink))
                    }

                    ctx.fill(
                        Path(ellipseIn: CGRect(x: (vm.state.puck.x - 3) * scale,
                                               y: (vm.state.puck.y - 3) * scale,
                                               width: 6 * scale, height: 6 * scale)),
                        with: .color(.white))
                }
                .frame(width: vm.state.width * scale, height: vm.state.height * scale)

                if vm.state.finished {
                    Text("GAME OVER").font(.system(size: 54, weight: .heavy)).tracking(5)
                        .foregroundColor(.yellow)
                        .padding(34)
                        .background(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.8)))
                }
            }
            .frame(width: vm.state.width * scale + 8, height: vm.state.height * scale + 8)
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

// MARK: - Heist Escape

struct HeistEscapeState {
    var size = 7
    var position = 0
    var exitCell = 48
    var trail: [Int] = []
    var secondsLeft = 0
    var won = false
    var finished = false
    var players: [BoardPlayer] = []

    mutating func update(from d: [String: AnyCodable]) {
        if let v = d["size"]?.value as? Int { size = v }
        if let v = d["position"]?.value as? Int { position = v }
        if let v = d["exitCell"]?.value as? Int { exitCell = v }
        if let v = d["secondsLeft"]?.value as? Int { secondsLeft = v }
        if let v = d["won"]?.value as? Bool { won = v }
        if let v = d["finished"]?.value as? Bool { finished = v }
        trail = (d["trail"]?.value as? [Any] ?? []).compactMap { $0 as? Int }
        players = BoardPlayer.list(from: d["players"]?.value)
    }
}

struct TVHeistEscapeBoardView: View {
    let room: Room
    @StateObject private var vm = TVBoardModel(initial: HeistEscapeState()) { $0.update(from: $1) }

    var body: some View {
        VStack(spacing: 0) {
            TVRoundHeader(emoji: "🗝️", title: "Heist Escape",
                          round: 0, totalRounds: 0, secondsLeft: vm.state.secondsLeft,
                          phaseLabel: "each phone holds part of the map")
            Spacer()
            if vm.state.finished {
                VStack(spacing: 16) {
                    Text(vm.state.won ? "🎉" : "🚨").font(.system(size: 130))
                    Text(vm.state.won ? "ESCAPED" : "CAUGHT")
                        .font(.system(size: 60, weight: .heavy)).tracking(5)
                        .foregroundColor(vm.state.won ? .green : .red)
                }
            } else {
                // The maze itself is never drawn — only where the team has been.
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(90), spacing: 8),
                                         count: vm.state.size), spacing: 8) {
                    ForEach(0..<(vm.state.size * vm.state.size), id: \.self) { cell in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(cell == vm.state.exitCell ? Color.green.opacity(0.35)
                                      : vm.state.trail.contains(cell) ? Color.cyan.opacity(0.2)
                                      : Color.white.opacity(0.05))
                            if cell == vm.state.position {
                                Text("🕵️").font(.system(size: 44))
                            } else if cell == vm.state.exitCell {
                                Text("🚪").font(.system(size: 38))
                            }
                        }
                        .frame(width: 90, height: 90)
                    }
                }
            }
            Spacer()
            TVScoreStrip(players: vm.state.players)
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

// MARK: - Ludo

struct LudoState {
    var die = 0
    var rolled = false
    var currentPlayerID: String? = nil
    var seats: [(name: String, seat: Int, tokens: [Int], absolute: [Int?])] = []
    var winner: String? = nil
    var players: [BoardPlayer] = []

    mutating func update(from d: [String: AnyCodable]) {
        if let v = d["die"]?.value as? Int { die = v }
        if let v = d["rolled"]?.value as? Bool { rolled = v }
        currentPlayerID = d["currentPlayerID"]?.value as? String
        winner = d["winner"]?.value as? String
        players = BoardPlayer.list(from: d["players"]?.value)
        seats = (d["seats"]?.value as? [Any] ?? []).compactMap {
            guard let s = $0 as? [String: Any] else { return nil }
            return (s["name"] as? String ?? "",
                    s["seat"] as? Int ?? 0,
                    (s["tokens"] as? [Any] ?? []).compactMap { $0 as? Int },
                    (s["absolute"] as? [Any] ?? []).map { $0 as? Int })
        }
    }
}

struct TVLudoBoardView: View {
    let room: Room
    @StateObject private var vm = TVBoardModel(initial: LudoState()) { $0.update(from: $1) }

    private let seatColors: [Color] = [.red, .green, .yellow, .blue]
    private let track = 52
    private let radius: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            TVRoundHeader(emoji: "🎲", title: "Ludo", round: 0, totalRounds: 0, secondsLeft: 0,
                          phaseLabel: vm.state.rolled ? "pick a token" : "roll the dice")
            Spacer()
            HStack(spacing: 70) {
                // Ring board: 52 squares laid out in a circle keeps every token
                // visible at TV distance without a cramped cross layout.
                ZStack {
                    ForEach(0..<track, id: \.self) { i in
                        let angle = Double(i) / Double(track) * 2 * .pi - .pi / 2
                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 30, height: 30)
                            .offset(x: radius * cos(angle), y: radius * sin(angle))
                    }
                    ForEach(Array(vm.state.seats.enumerated()), id: \.offset) { _, seat in
                        ForEach(Array(seat.absolute.enumerated()), id: \.offset) { _, abs in
                            if let pos = abs {
                                let angle = Double(pos) / Double(track) * 2 * .pi - .pi / 2
                                Circle()
                                    .fill(seatColors[seat.seat % 4])
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .offset(x: radius * cos(angle), y: radius * sin(angle))
                            }
                        }
                    }
                    VStack(spacing: 6) {
                        Text("🎲").font(.system(size: 60))
                        Text(vm.state.die > 0 ? "\(vm.state.die)" : "—")
                            .font(.system(size: 70, weight: .heavy)).foregroundColor(.white)
                    }
                }
                .frame(width: radius * 2 + 60, height: radius * 2 + 60)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(vm.state.seats.enumerated()), id: \.offset) { _, seat in
                        let active = vm.state.players.first { $0.id == vm.state.currentPlayerID }?.name == seat.name
                        HStack(spacing: 12) {
                            Circle().fill(seatColors[seat.seat % 4]).frame(width: 22, height: 22)
                            Text(seat.name).font(.title3.bold())
                                .foregroundColor(active ? .white : .white.opacity(0.5))
                            Spacer()
                            Text("\(seat.tokens.filter { $0 >= 100 }.count)/4 home")
                                .font(.callout).foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .frame(width: 340)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(active ? .white.opacity(0.12) : .white.opacity(0.04)))
                    }
                }
            }
            Spacer()
            TVScoreStrip(players: vm.state.players)
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

// MARK: - Carrom

struct CarromState {
    var board: Double = 100
    var coins: [(id: Int, x: Double, y: Double, kind: String)] = []
    var strikerX: Double = 50
    var currentPlayerID: String? = nil
    var targetScore = 8
    var winner: String? = nil
    var players: [BoardPlayer] = []

    mutating func update(from d: [String: AnyCodable]) {
        if let v = d["board"]?.value as? Double { board = v }
        if let v = d["strikerX"]?.value as? Double { strikerX = v }
        if let v = d["targetScore"]?.value as? Int { targetScore = v }
        currentPlayerID = d["currentPlayerID"]?.value as? String
        winner = d["winner"]?.value as? String
        players = BoardPlayer.list(from: d["players"]?.value)
        coins = (d["coins"]?.value as? [Any] ?? []).compactMap {
            guard let c = $0 as? [String: Any], let id = c["id"] as? Int else { return nil }
            return (id, c["x"] as? Double ?? 0, c["y"] as? Double ?? 0,
                    c["kind"] as? String ?? "white")
        }
    }
}

struct TVCarromBoardView: View {
    let room: Room
    @StateObject private var vm = TVBoardModel(initial: CarromState()) { $0.update(from: $1) }

    private let scale: CGFloat = 8.0

    var body: some View {
        VStack(spacing: 0) {
            TVRoundHeader(emoji: "⚫", title: "Carrom", round: 0, totalRounds: 0, secondsLeft: 0,
                          phaseLabel: "first to \(vm.state.targetScore)")
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "d9b382"))
                    .frame(width: vm.state.board * scale, height: vm.state.board * scale)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "6b4f2a"), lineWidth: 10))

                Canvas { ctx, size in
                    // Pockets
                    for p in [CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0),
                              CGPoint(x: 0, y: size.height),
                              CGPoint(x: size.width, y: size.height)] {
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 28, y: p.y - 28,
                                                        width: 56, height: 56)),
                                 with: .color(.black))
                    }
                    ctx.stroke(Path(ellipseIn: CGRect(x: size.width / 2 - 45,
                                                      y: size.height / 2 - 45,
                                                      width: 90, height: 90)),
                               with: .color(Color(hex: "6b4f2a").opacity(0.5)), lineWidth: 3)

                    for coin in vm.state.coins {
                        let color: Color = coin.kind == "queen" ? .red
                                         : coin.kind == "black" ? .black
                                         : Color(hex: "f5e6c8")
                        ctx.fill(Path(ellipseIn: CGRect(x: coin.x * scale - 12,
                                                        y: coin.y * scale - 12,
                                                        width: 24, height: 24)),
                                 with: .color(color))
                    }
                    // Striker
                    ctx.fill(Path(ellipseIn: CGRect(x: vm.state.strikerX * scale - 16,
                                                    y: 92 * scale - 16,
                                                    width: 32, height: 32)),
                             with: .color(.cyan))
                }
                .frame(width: vm.state.board * scale, height: vm.state.board * scale)
            }
            Spacer()
            TVScoreStrip(players: vm.state.players)
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

// MARK: - Teen Patti

struct TeenPattiState {
    var pot = 0
    var currentStake = 0
    var currentPlayerID: String? = nil
    var seats: [(id: String, name: String, chips: Int, folded: Bool,
                 blind: Bool, stake: Int)] = []
    var showdown: [(name: String, cards: [(rank: Int, suit: String)], rank: Int)] = []
    var winner: String? = nil
    var players: [BoardPlayer] = []

    mutating func update(from d: [String: AnyCodable]) {
        if let v = d["pot"]?.value as? Int { pot = v }
        if let v = d["currentStake"]?.value as? Int { currentStake = v }
        currentPlayerID = d["currentPlayerID"]?.value as? String
        winner = d["winner"]?.value as? String
        players = BoardPlayer.list(from: d["players"]?.value)
        seats = (d["seats"]?.value as? [Any] ?? []).compactMap {
            guard let s = $0 as? [String: Any] else { return nil }
            return (s["playerID"] as? String ?? "", s["name"] as? String ?? "",
                    s["chips"] as? Int ?? 0, s["folded"] as? Bool ?? false,
                    s["blind"] as? Bool ?? false, s["stake"] as? Int ?? 0)
        }
        showdown = (d["showdown"]?.value as? [Any] ?? []).compactMap {
            guard let s = $0 as? [String: Any] else { return nil }
            let cards = (s["cards"] as? [Any] ?? []).compactMap { c -> (rank: Int, suit: String)? in
                guard let card = c as? [String: Any], let r = card["rank"] as? Int
                else { return nil }
                return (r, card["suit"] as? String ?? "♠")
            }
            return (s["name"] as? String ?? "", cards, s["rank"] as? Int ?? 0)
        }
    }
}

struct TVTeenPattiBoardView: View {
    let room: Room
    @StateObject private var vm = TVBoardModel(initial: TeenPattiState()) { $0.update(from: $1) }

    private func rankName(_ r: Int) -> String {
        ["", "High Card", "Pair", "Colour", "Sequence", "Pure Sequence", "Trail"][min(r, 6)]
    }

    private func cardLabel(_ rank: Int) -> String {
        switch rank {
        case 14: return "A"
        case 13: return "K"
        case 12: return "Q"
        case 11: return "J"
        default: return "\(rank)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("🎴 Teen Patti").font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                VStack(spacing: 2) {
                    Text("POT").font(.caption.bold()).tracking(3)
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(vm.state.pot)").font(.system(size: 46, weight: .heavy))
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 70).padding(.top, 44)

            Spacer()

            if vm.state.showdown.isEmpty {
                // Cards stay on the phones until showdown.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                    ForEach(Array(vm.state.seats.enumerated()), id: \.offset) { _, seat in
                        VStack(spacing: 8) {
                            Text(seat.name).font(.title3.bold())
                                .foregroundColor(seat.folded ? .white.opacity(0.3) : .white)
                            HStack(spacing: 5) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(seat.folded ? Color.white.opacity(0.07)
                                                          : Color.purple.opacity(0.55))
                                        .frame(width: 40, height: 58)
                                }
                            }
                            Text("\(seat.chips)").font(.headline).foregroundColor(.cyan)
                            if seat.blind && !seat.folded {
                                Text("BLIND").font(.caption.bold()).tracking(2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 18).frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(seat.id == vm.state.currentPlayerID
                                  ? Color.white.opacity(0.14) : Color.white.opacity(0.04)))
                    }
                }
                .padding(.horizontal, 80)
            } else {
                VStack(spacing: 18) {
                    ForEach(Array(vm.state.showdown.enumerated()), id: \.offset) { _, s in
                        HStack(spacing: 18) {
                            Text(s.name).font(.title2.bold()).foregroundColor(.white)
                                .frame(width: 200, alignment: .leading)
                            HStack(spacing: 8) {
                                ForEach(Array(s.cards.enumerated()), id: \.offset) { _, c in
                                    VStack(spacing: 0) {
                                        Text(cardLabel(c.rank)).font(.title3.bold())
                                        Text(c.suit).font(.title3)
                                    }
                                    .foregroundColor(c.suit == "♥" || c.suit == "♦" ? .red : .black)
                                    .frame(width: 54, height: 76)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(.white))
                                }
                            }
                            Text(rankName(s.rank)).font(.headline).foregroundColor(.yellow)
                        }
                    }
                }
            }

            Spacer()
            TVScoreStrip(players: vm.state.players)
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }
}
