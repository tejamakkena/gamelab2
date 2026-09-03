import SwiftUI

// MARK: - Shared helpers

struct PlaceholderBoardView: View {
    let game: GameID
    var body: some View {
        VStack(spacing: 20) {
            Text(game.emoji).font(.system(size: 80))
            Text(game.displayName).font(.largeTitle.bold()).foregroundColor(.white)
            Text("Coming soon").foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }
}

struct TVWebGameBoardView: View {
    let room: Room
    var body: some View { PlaceholderBoardView(game: room.gameID) }
}

// Shared score header used by multiple board views
private struct TVScoreHeader: View {
    let players: [Player]
    let currentPlayerID: String?

    var body: some View {
        HStack(spacing: 16) {
            ForEach(players) { p in
                HStack(spacing: 8) {
                    Circle()
                        .fill(p.id == currentPlayerID ? Color.cyan : Color.white.opacity(0.15))
                        .frame(width: 12, height: 12)
                    Text(p.name).foregroundColor(p.id == currentPlayerID ? .white : .white.opacity(0.5))
                    Text("\(p.score)").font(.headline.bold()).foregroundColor(.cyan)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(p.id == currentPlayerID ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05)))
            }
            Spacer()
        }
        .padding(.horizontal, 48)
    }
}

// MARK: - Pong Board

struct TVPongBoardView: View {
    let room: Room
    @StateObject private var vm = PongBoardViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Centre divider
            VStack(spacing: 8) {
                ForEach(0..<12, id: \.self) { _ in
                    Rectangle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 24)
                }
            }

            // Left paddle
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 12, height: 80)
                .position(x: 60, y: paddleY(vm.state.leftPaddlePos))

            // Right paddle
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 12, height: 80)
                .position(x: UIScreen.main.bounds.width - 60, y: paddleY(vm.state.rightPaddlePos))

            // Ball
            Circle().fill(Color.white).frame(width: 20, height: 20)
                .position(x: vm.state.ballX * UIScreen.main.bounds.width,
                          y: vm.state.ballY * UIScreen.main.bounds.height)
                .shadow(color: .cyan, radius: 8)

            // Scores
            HStack {
                Text("\(vm.state.scoreLeft)")
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("\(vm.state.scoreRight)")
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 120)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)

            // Player labels
            HStack {
                Text(vm.state.leftPlayerName).font(.title3).foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(vm.state.rightPlayerName).font(.title3).foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 60)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 40)
        }
        .onAppear { vm.bind(roomCode: room.code) }
    }

    private func paddleY(_ normalized: Double) -> CGFloat {
        CGFloat(normalized) * UIScreen.main.bounds.height
    }
}

struct PongState {
    var ballX: Double = 0.5
    var ballY: Double = 0.5
    var leftPaddlePos: Double = 0.5
    var rightPaddlePos: Double = 0.5
    var scoreLeft = 0
    var scoreRight = 0
    var leftPlayerName = "Player 1"
    var rightPlayerName = "Player 2"

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["ballX"]?.value as? Double          { ballX = v }
        if let v = data["ballY"]?.value as? Double          { ballY = v }
        if let v = data["leftPaddle"]?.value as? Double     { leftPaddlePos = v }
        if let v = data["rightPaddle"]?.value as? Double    { rightPaddlePos = v }
        if let v = data["scoreLeft"]?.value as? Int         { scoreLeft = v }
        if let v = data["scoreRight"]?.value as? Int        { scoreRight = v }
        if let v = data["leftName"]?.value as? String       { leftPlayerName = v }
        if let v = data["rightName"]?.value as? String      { rightPlayerName = v }
    }
}

@MainActor final class PongBoardViewModel: ObservableObject {
    @Published var state = PongState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Poker Board

struct TVPokerBoardView: View {
    let room: Room
    @StateObject private var vm = PokerBoardViewModel()

    var body: some View {
        VStack(spacing: 32) {
            // Phase + pot
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text(vm.state.phase.uppercased()).font(.caption.bold()).tracking(3)
                        .foregroundColor(.yellow.opacity(0.7))
                    Text("🃏 Poker").font(.title2.bold()).foregroundColor(.white)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text("POT").font(.caption.bold()).tracking(2).foregroundColor(.white.opacity(0.4))
                    Text("$\(vm.state.pot)").font(.system(size: 36, weight: .bold)).foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 60).padding(.top, 40)

            // Community cards
            VStack(spacing: 12) {
                Text("Community Cards").font(.subheadline).foregroundColor(.white.opacity(0.4))
                HStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { idx in
                        if idx < vm.state.communityCards.count {
                            TVCardView(card: vm.state.communityCards[idx])
                        } else {
                            TVCardBack()
                        }
                    }
                }
            }

            // Player seats around table
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(room.players.count, 4)),
                      spacing: 20) {
                ForEach(vm.state.playerSeats) { seat in
                    PokerSeatView(seat: seat)
                }
            }
            .padding(.horizontal, 60)

            Spacer()
        }
        .background(Color(hex: "001a00").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

private struct TVCardView: View {
    let card: String
    private var isRed: Bool { card.contains("♥") || card.contains("♦") }
    var body: some View {
        Text(card)
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(isRed ? .red : .black)
            .frame(width: 70, height: 100)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            .shadow(radius: 4)
    }
}

private struct TVCardBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: "1a0a2e"))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.purple.opacity(0.4), lineWidth: 1))
            .frame(width: 70, height: 100)
            .overlay(Text("🂠").font(.system(size: 40)))
    }
}

struct PokerSeat: Identifiable {
    let id: String
    let name: String
    let chips: Int
    let currentBet: Int
    let status: String  // "active", "folded", "all-in", "waiting"
    let isCurrentTurn: Bool
}

struct PokerBoardState {
    var communityCards: [String] = []
    var pot = 0
    var phase = "pre-flop"
    var playerSeats: [PokerSeat] = []

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["pot"]?.value as? Int             { pot = v }
        if let v = data["phase"]?.value as? String        { phase = v }
        if let v = data["communityCards"]?.value as? [String] { communityCards = v }
        if let seats = data["players"]?.value as? [[String: Any]] {
            playerSeats = seats.compactMap { d -> PokerSeat? in
                guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
                return PokerSeat(id: id, name: name,
                                 chips: d["chips"] as? Int ?? 0,
                                 currentBet: d["currentBet"] as? Int ?? 0,
                                 status: d["status"] as? String ?? "waiting",
                                 isCurrentTurn: d["isCurrentTurn"] as? Bool ?? false)
            }
        }
    }
}

@MainActor final class PokerBoardViewModel: ObservableObject {
    @Published var state = PokerBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

private struct PokerSeatView: View {
    let seat: PokerSeat
    var body: some View {
        VStack(spacing: 6) {
            Text(seat.name).font(.headline)
                .foregroundColor(seat.isCurrentTurn ? .yellow : .white)
            Text("$\(seat.chips)").font(.subheadline).foregroundColor(.green)
            if seat.currentBet > 0 {
                Text("Bet: $\(seat.currentBet)").font(.caption).foregroundColor(.cyan)
            }
            Text(seat.status).font(.caption2.bold())
                .foregroundColor(statusColor(seat.status))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(seat.isCurrentTurn ? Color.yellow.opacity(0.1) : Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(seat.isCurrentTurn ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 2)))
    }
    private func statusColor(_ s: String) -> Color {
        switch s { case "active": return .white; case "folded": return .red.opacity(0.6);
                   case "all-in": return .orange; default: return .white.opacity(0.3) }
    }
}

// MARK: - Connect 4 Board

struct TVConnect4BoardView: View {
    let room: Room
    @StateObject private var vm = Connect4BoardViewModel()

    private let rows = 6, cols = 7

    var body: some View {
        VStack(spacing: 24) {
            TVScoreHeader(players: room.players, currentPlayerID: vm.state.currentPlayerID)
                .padding(.top, 40)

            Text("🟡 Connect 4").font(.largeTitle.bold()).foregroundColor(.white)

            if let winner = vm.state.winner {
                Text("\(winner) wins! 🎉").font(.title2.bold()).foregroundColor(.yellow)
            } else {
                Text(vm.state.currentPlayerName.isEmpty ? "" : "\(vm.state.currentPlayerName)'s turn")
                    .font(.title3).foregroundColor(.white.opacity(0.6))
            }

            // Grid
            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<cols, id: \.self) { col in
                            let cell = vm.state.grid[row][col]
                            let isWin = vm.state.winCells.contains("\(row),\(col)")
                            Circle()
                                .fill(cellColor(cell))
                                .frame(width: 72, height: 72)
                                .shadow(color: isWin ? .yellow : .clear, radius: 10)
                                .scaleEffect(isWin ? 1.1 : 1.0)
                                .animation(.spring(), value: isWin)
                        }
                    }
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "001a3a")))

            Spacer()
        }
        .background(Color(hex: "000814").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }

    private func cellColor(_ cell: String) -> Color {
        switch cell { case "red": return .red; case "yellow": return .yellow;
                      default: return Color(hex: "0a1a2e") }
    }
}

struct Connect4BoardState {
    var grid: [[String]] = Array(repeating: Array(repeating: "", count: 7), count: 6)
    var currentPlayerID = ""
    var currentPlayerName = ""
    var winner: String? = nil
    var winCells: Set<String> = []

    mutating func update(from data: [String: AnyCodable]) {
        if let g = data["grid"]?.value as? [[String]]  { grid = g }
        if let v = data["currentPlayerID"]?.value as? String  { currentPlayerID = v }
        if let v = data["currentPlayerName"]?.value as? String { currentPlayerName = v }
        if let v = data["winner"]?.value as? String    { winner = v }
        if let v = data["winCells"]?.value as? [String] { winCells = Set(v) }
    }
}

@MainActor final class Connect4BoardViewModel: ObservableObject {
    @Published var state = Connect4BoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Memory Board

struct TVMemoryBoardView: View {
    let room: Room
    @StateObject private var vm = MemoryBoardViewModel()

    private let cols = 4

    var body: some View {
        VStack(spacing: 24) {
            TVScoreHeader(players: room.players, currentPlayerID: vm.state.currentPlayerID)
                .padding(.top, 40)

            Text("🧩 Memory").font(.largeTitle.bold()).foregroundColor(.white)

            Text(vm.state.currentPlayerName.isEmpty ? "" : "\(vm.state.currentPlayerName)'s turn")
                .font(.title3).foregroundColor(.white.opacity(0.5))

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(120), spacing: 16), count: cols), spacing: 16) {
                ForEach(Array(vm.state.cards.enumerated()), id: \.offset) { idx, card in
                    TVMemoryCard(card: card)
                }
            }
            .padding(32)

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

struct MemoryCard: Identifiable {
    let id: Int
    var value: String
    var state: MemoryCardState  // hidden, flipped, matched
}

enum MemoryCardState: String { case hidden, flipped, matched }

private struct TVMemoryCard: View {
    let card: MemoryCard
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(card.state == .matched ? Color.green.opacity(0.25)
                      : card.state == .flipped ? Color.white.opacity(0.15)
                      : Color(hex: "1e1e3a"))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(card.state == .matched ? Color.green.opacity(0.5) : Color.white.opacity(0.06),
                                  lineWidth: 2))
                .frame(width: 112, height: 112)

            if card.state != .hidden {
                Text(card.value).font(.system(size: 48))
            } else {
                Image(systemName: "questionmark").font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .rotation3DEffect(
            .degrees(card.state == .hidden ? 0 : 180),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: card.state)
    }
}

struct MemoryBoardState {
    var cards: [MemoryCard] = []
    var currentPlayerID = ""
    var currentPlayerName = ""

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["currentPlayerID"]?.value as? String   { currentPlayerID = v }
        if let v = data["currentPlayerName"]?.value as? String { currentPlayerName = v }
        if let rawCards = data["cards"]?.value as? [[String: Any]] {
            cards = rawCards.enumerated().compactMap { idx, d -> MemoryCard? in
                let stateStr = d["state"] as? String ?? "hidden"
                return MemoryCard(
                    id: idx,
                    value: d["value"] as? String ?? "?",
                    state: MemoryCardState(rawValue: stateStr) ?? .hidden
                )
            }
        }
    }
}

@MainActor final class MemoryBoardViewModel: ObservableObject {
    @Published var state = MemoryBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Mafia Board

struct TVMafiaBoardView: View {
    let room: Room
    @StateObject private var vm = MafiaBoardViewModel()

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🕵️ Mafia").font(.system(size: 48, weight: .bold)).foregroundColor(.white)
                    Text(vm.state.phase == "day" ? "☀️ Day \(vm.state.round) — Vote to eliminate"
                         : "🌙 Night — Mafia is choosing")
                        .font(.title3).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                TimerRing(secondsLeft: vm.state.secondsLeft, total: vm.state.phase == "day" ? 60 : 30)
            }
            .padding(.horizontal, 60).padding(.top, 40)

            // Players grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                ForEach(vm.state.players) { p in
                    MafiaPlayerTile(player: p)
                }
            }
            .padding(.horizontal, 60)

            // Vote tally (day only)
            if vm.state.phase == "day" && !vm.state.votes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vote Tally").font(.headline).foregroundColor(.white.opacity(0.5))
                    ForEach(vm.state.votes.sorted(by: { $0.value > $1.value }), id: \.key) { name, count in
                        HStack {
                            Text(name).foregroundColor(.white)
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(0..<count, id: \.self) { _ in
                                    Circle().fill(Color.red).frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
                .padding(.horizontal, 60)
            }

            if let eliminated = vm.state.lastEliminated {
                Text("\(eliminated) was eliminated!")
                    .font(.title3.bold()).foregroundColor(.red)
            }

            Spacer()
        }
        .background(Color(hex: vm.state.phase == "day" ? "0a0814" : "00000a").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

struct MafiaPlayer: Identifiable {
    let id: String
    let name: String
    var isAlive: Bool
    var revealedRole: String?
}

private struct MafiaPlayerTile: View {
    let player: MafiaPlayer
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(player.isAlive ? Color.white.opacity(0.1) : Color.red.opacity(0.15))
                    .frame(width: 64, height: 64)
                Text(player.isAlive ? String(player.name.prefix(1)) : "💀")
                    .font(.title.bold()).foregroundColor(.white)
            }
            Text(player.name).font(.subheadline)
                .foregroundColor(player.isAlive ? .white : .white.opacity(0.3))
                .strikethrough(!player.isAlive)
            if let role = player.revealedRole {
                Text(role).font(.caption2.bold()).foregroundColor(.red)
            }
        }
        .opacity(player.isAlive ? 1 : 0.5)
    }
}

struct MafiaBoardState {
    var players: [MafiaPlayer] = []
    var phase = "day"
    var round = 1
    var secondsLeft = 60
    var votes: [String: Int] = [:]
    var lastEliminated: String? = nil

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["phase"]?.value as? String        { phase = v }
        if let v = data["round"]?.value as? Int           { round = v }
        if let v = data["secondsLeft"]?.value as? Int     { secondsLeft = v }
        if let v = data["lastEliminated"]?.value as? String { lastEliminated = v }
        if let v = data["votes"]?.value as? [String: Int] { votes = v }
        if let ps = data["players"]?.value as? [[String: Any]] {
            players = ps.compactMap { d -> MafiaPlayer? in
                guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
                return MafiaPlayer(id: id, name: name,
                                   isAlive: d["isAlive"] as? Bool ?? true,
                                   revealedRole: d["revealedRole"] as? String)
            }
        }
    }
}

@MainActor final class MafiaBoardViewModel: ObservableObject {
    @Published var state = MafiaBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Roulette Board

struct TVRouletteBoardView: View {
    let room: Room
    @StateObject private var vm = RouletteBoardViewModel()

    // Numbers 0-36 arranged in the European layout
    private let numberGrid: [[Int]] = [
        [3,6,9,12,15,18,21,24,27,30,33,36],
        [2,5,8,11,14,17,20,23,26,29,32,35],
        [1,4,7,10,13,16,19,22,25,28,31,34],
    ]

    var body: some View {
        HStack(spacing: 60) {
            // Left — wheel indicator + result
            VStack(spacing: 24) {
                Text("🎡 Roulette").font(.system(size: 40, weight: .bold)).foregroundColor(.white)

                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 4).frame(width: 280, height: 280)
                    Circle().stroke(Color.green.opacity(0.5), lineWidth: 2).frame(width: 220, height: 220)

                    if vm.state.isSpinning {
                        Text("🎰").font(.system(size: 80))
                    } else if let result = vm.state.lastResult {
                        VStack(spacing: 4) {
                            Text("\(result)").font(.system(size: 72, weight: .black))
                                .foregroundColor(isRed(result) ? .red : result == 0 ? .green : .white)
                            Text(isRed(result) ? "RED" : result == 0 ? "GREEN" : "BLACK")
                                .font(.headline).foregroundColor(.white.opacity(0.5))
                        }
                    } else {
                        Text("Place\nyour bets").font(.title3).foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                }

                // Total bets per player
                VStack(spacing: 8) {
                    ForEach(room.players) { p in
                        HStack {
                            Text(p.name).foregroundColor(.white)
                            Spacer()
                            Text("Bet: $\(vm.state.playerBets[p.id] ?? 0)").foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .frame(maxWidth: 400)

            // Right — number grid
            VStack(spacing: 4) {
                Text("0").font(.headline.bold()).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.5)))
                    .padding(.horizontal, 4)

                ForEach(Array(numberGrid.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.self) { num in
                            Text("\(num)").font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 4)
                                    .fill(isRed(num) ? Color.red.opacity(0.7) : Color.black.opacity(0.7)))
                                .overlay(
                                    vm.state.lastResult == num ?
                                    RoundedRectangle(cornerRadius: 4).strokeBorder(.yellow, lineWidth: 3) : nil
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: 500)
        }
        .padding(60)
        .background(Color(hex: "060d00").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }

    private func isRed(_ n: Int) -> Bool {
        [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36].contains(n)
    }
}

struct RouletteBoardState {
    var isSpinning = false
    var lastResult: Int? = nil
    var playerBets: [String: Int] = [:]

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["isSpinning"]?.value as? Bool  { isSpinning = v }
        if let v = data["lastResult"]?.value as? Int   { lastResult = v }
        if let v = data["playerBets"]?.value as? [String: Int] { playerBets = v }
    }
}

@MainActor final class RouletteBoardViewModel: ObservableObject {
    @Published var state = RouletteBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Digit Guess Board (Mastermind / shared guess history)

struct TVDigitGuessBoardView: View {
    let room: Room
    @StateObject private var vm = DigitGuessBoardViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text("🔢 Digit Guess").font(.system(size: 48, weight: .bold)).foregroundColor(.white)
                .padding(.top, 40)

            Text(vm.state.solved ? "Code cracked! 🎉" : "Guess the secret 4-digit code")
                .font(.title3).foregroundColor(vm.state.solved ? .green : .white.opacity(0.5))

            // Player columns
            HStack(alignment: .top, spacing: 24) {
                ForEach(vm.state.playerColumns) { col in
                    VStack(spacing: 8) {
                        Text(col.playerName).font(.headline).foregroundColor(.white)
                            .padding(.bottom, 4)
                        ForEach(Array(col.guesses.enumerated()), id: \.offset) { _, guess in
                            HStack {
                                Text(guess.code)
                                    .font(.system(.body, design: .monospaced).bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text("🐂\(guess.bulls) 🐄\(guess.cows)")
                                    .font(.caption).foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(guess.bulls == 4 ? Color.green.opacity(0.3) : Color.white.opacity(0.05)))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 60)

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

struct DigitGuessEntry: Identifiable {
    let id = UUID()
    let code: String
    let bulls: Int
    let cows: Int
}

struct DigitGuessPlayerColumn: Identifiable {
    let id: String
    let playerName: String
    var guesses: [DigitGuessEntry]
}

struct DigitGuessBoardState {
    var playerColumns: [DigitGuessPlayerColumn] = []
    var solved = false

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["solved"]?.value as? Bool { solved = v }
        if let cols = data["players"]?.value as? [[String: Any]] {
            playerColumns = cols.compactMap { d -> DigitGuessPlayerColumn? in
                guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
                let guesses = (d["guesses"] as? [[String: Any]] ?? []).compactMap { g -> DigitGuessEntry? in
                    guard let code = g["code"] as? String else { return nil }
                    return DigitGuessEntry(code: code,
                                          bulls: g["bulls"] as? Int ?? 0,
                                          cows: g["cows"] as? Int ?? 0)
                }
                return DigitGuessPlayerColumn(id: id, playerName: name, guesses: guesses)
            }
        }
    }
}

@MainActor final class DigitGuessBoardViewModel: ObservableObject {
    @Published var state = DigitGuessBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Raja Mantri Board

struct TVRajaMantriBoard: View {
    let room: Room
    @StateObject private var vm = RajaMantriViewModel()

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Text("👑 Raja Mantri").font(.system(size: 44, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("Round \(vm.state.round)").font(.title3).foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 60).padding(.top, 40)

            Text(vm.state.phaseLabel).font(.title2).foregroundColor(.cyan.opacity(0.8))

            // Player role cards (revealed after round ends)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(room.players.count, 4)),
                      spacing: 20) {
                ForEach(vm.state.playerRoles) { p in
                    RajaMantriPlayerCard(player: p)
                }
            }
            .padding(.horizontal, 60)

            if let result = vm.state.roundResult {
                Text(result).font(.title3.bold()).foregroundColor(.yellow)
            }

            // Score table
            VStack(spacing: 10) {
                ForEach(room.players.sorted(by: { $0.score > $1.score })) { p in
                    HStack {
                        Text(p.name).foregroundColor(.white)
                        Spacer()
                        Text("\(p.score) pts").font(.headline.bold()).foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
            .padding(.horizontal, 60)

            Spacer()
        }
        .background(Color(hex: "0a0814").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

struct RajaPlayer: Identifiable {
    let id: String
    let name: String
    var revealedRole: String?
    var isAccused: Bool
}

private struct RajaMantriPlayerCard: View {
    let player: RajaPlayer
    var body: some View {
        VStack(spacing: 10) {
            Text(player.revealedRole.map { roleEmoji($0) } ?? "🂠").font(.system(size: 48))
            Text(player.name).font(.headline).foregroundColor(.white)
            if let role = player.revealedRole {
                Text(role).font(.caption.bold()).foregroundColor(roleColor(role))
            }
            if player.isAccused {
                Text("← ACCUSED").font(.caption2.bold()).foregroundColor(.red)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
    }

    private func roleEmoji(_ r: String) -> String {
        switch r { case "Raja": return "👑"; case "Mantri": return "🎩"; case "Chor": return "🦹"; default: return "⚔️" }
    }
    private func roleColor(_ r: String) -> Color {
        switch r { case "Raja": return .yellow; case "Mantri": return .purple; case "Chor": return .red; default: return .cyan }
    }
}

struct RajaMantriState {
    var round = 1
    var phase = "deal"
    var playerRoles: [RajaPlayer] = []
    var roundResult: String? = nil

    var phaseLabel: String {
        switch phase {
        case "deal":    return "Roles are being dealt…"
        case "guess":   return "Sipahi is guessing the Chor!"
        case "reveal":  return "Roles revealed!"
        default:        return phase
        }
    }

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["round"]?.value as? Int           { round = v }
        if let v = data["phase"]?.value as? String        { phase = v }
        if let v = data["roundResult"]?.value as? String  { roundResult = v }
        if let ps = data["players"]?.value as? [[String: Any]] {
            playerRoles = ps.compactMap { d -> RajaPlayer? in
                guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
                return RajaPlayer(id: id, name: name,
                                  revealedRole: d["role"] as? String,
                                  isAccused: d["isAccused"] as? Bool ?? false)
            }
        }
    }
}

@MainActor final class RajaMantriViewModel: ObservableObject {
    @Published var state = RajaMantriState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Tambola Board

struct TVTambolaBoardView: View {
    let room: Room
    @StateObject private var vm = TambolaBoardViewModel()

    var body: some View {
        HStack(spacing: 60) {
            // Left — caller column
            VStack(spacing: 20) {
                Text("🎱 Tambola").font(.system(size: 40, weight: .bold)).foregroundColor(.white)

                if let last = vm.state.lastCalled {
                    VStack(spacing: 8) {
                        Text("\(last)").font(.system(size: 96, weight: .black))
                            .foregroundColor(.yellow)
                        Text("Last Called").font(.subheadline).foregroundColor(.white.opacity(0.4))
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.yellow.opacity(0.1)))
                }

                Text("Called: \(vm.state.calledNumbers.count)").font(.body).foregroundColor(.white.opacity(0.5))

                Spacer()

                // Claims
                ForEach(vm.state.claims, id: \.self) { claim in
                    Text("🎉 \(claim)").font(.headline).foregroundColor(.green)
                }
            }
            .frame(width: 320)

            // Right — number board (1–90 grid)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(56)), count: 10), spacing: 8) {
                ForEach(1...90, id: \.self) { num in
                    Text("\(num)")
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(vm.state.calledNumbers.contains(num) ? .black : .white)
                        .frame(width: 50, height: 40)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(vm.state.calledNumbers.contains(num)
                                  ? Color.yellow : Color.white.opacity(0.06)))
                }
            }
            .padding(24)
        }
        .padding(60)
        .background(Color(hex: "0a0814").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

struct TambolaBoardState {
    var calledNumbers: Set<Int> = []
    var lastCalled: Int? = nil
    var claims: [String] = []

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["called"]?.value as? [Int]       { calledNumbers = Set(v) }
        if let v = data["lastCalled"]?.value as? Int      { lastCalled = v }
        if let v = data["claims"]?.value as? [String]     { claims = v }
    }
}

@MainActor final class TambolaBoardViewModel: ObservableObject {
    @Published var state = TambolaBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Stock Panic Board

struct TVStockPanicBoardView: View {
    let room: Room
    @StateObject private var vm = StockPanicBoardViewModel()

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("📈 Stock Panic").font(.system(size: 44, weight: .bold)).foregroundColor(.white)
                Spacer()
                if let news = vm.state.latestNews {
                    HStack(spacing: 8) {
                        Image(systemName: "newspaper.fill").foregroundColor(.yellow)
                        Text(news).font(.subheadline).foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(Color.yellow.opacity(0.15)))
                }
            }
            .padding(.horizontal, 60).padding(.top, 40)

            // Stock ticker
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(vm.state.stocks) { stock in
                    StockTile(stock: stock)
                }
            }
            .padding(.horizontal, 60)

            // Leaderboard
            HStack(alignment: .top, spacing: 0) {
                ForEach(room.players.sorted(by: { $0.score > $1.score })) { p in
                    VStack(spacing: 4) {
                        Text(p.name).font(.subheadline).foregroundColor(.white)
                        Text("$\(p.score)").font(.headline.bold()).foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
            .padding(.horizontal, 60)

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

struct StockEntry: Identifiable {
    let id: String
    let name: String
    var price: Int
    var change: Int
}

private struct StockTile: View {
    let stock: StockEntry
    var body: some View {
        VStack(spacing: 6) {
            Text(stock.name).font(.headline).foregroundColor(.white)
            Text("$\(stock.price)").font(.system(size: 32, weight: .bold))
                .foregroundColor(stock.change >= 0 ? .green : .red)
            HStack(spacing: 4) {
                Image(systemName: stock.change >= 0 ? "arrow.up" : "arrow.down")
                Text("\(abs(stock.change))").font(.caption)
            }
            .foregroundColor(stock.change >= 0 ? .green : .red)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    }
}

struct StockPanicBoardState {
    var stocks: [StockEntry] = []
    var latestNews: String? = nil

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["latestNews"]?.value as? String { latestNews = v }
        if let s = data["stocks"]?.value as? [[String: Any]] {
            stocks = s.compactMap { d -> StockEntry? in
                guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
                return StockEntry(id: id, name: name,
                                  price: d["price"] as? Int ?? 0,
                                  change: d["change"] as? Int ?? 0)
            }
        }
    }
}

@MainActor final class StockPanicBoardViewModel: ObservableObject {
    @Published var state = StockPanicBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Mind Meld Board

struct TVMindMeldBoardView: View {
    let room: Room
    @StateObject private var vm = MindMeldBoardViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Text("🔮 Mind Meld").font(.system(size: 48, weight: .bold)).foregroundColor(.white)
                .padding(.top, 40)

            if let category = vm.state.category {
                Text("Category: \(category)").font(.title2).foregroundColor(.cyan)
            }

            if vm.state.showReveal {
                // Reveal all words
                VStack(spacing: 16) {
                    Text("Words submitted:").font(.headline).foregroundColor(.white.opacity(0.5))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(vm.state.submissions) { sub in
                            VStack(spacing: 4) {
                                Text(sub.word).font(.title2.bold()).foregroundColor(.white)
                                Text(sub.playerName).font(.caption).foregroundColor(.white.opacity(0.5))
                                if sub.isMeld {
                                    Text("MELD +\(sub.meldCount)!").font(.caption.bold()).foregroundColor(.green)
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(sub.isMeld ? Color.green.opacity(0.2) : Color.white.opacity(0.06)))
                        }
                    }
                }
                .padding(.horizontal, 60)
            } else {
                // Waiting for submissions
                VStack(spacing: 16) {
                    let submitted = vm.state.submissions.count
                    let total = room.players.count
                    Text("\(submitted) / \(total) submitted").font(.title2).foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 12) {
                        ForEach(room.players) { p in
                            VStack(spacing: 6) {
                                Image(systemName: vm.state.submittedIDs.contains(p.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.title).foregroundColor(vm.state.submittedIDs.contains(p.id) ? .green : .white.opacity(0.3))
                                Text(p.name).font(.caption).foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                }
            }

            TVScoreHeader(players: room.players, currentPlayerID: nil)

            Spacer()
        }
        .background(Color(hex: "0d0a14").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

struct MeldSubmission: Identifiable {
    let id: String
    let playerName: String
    let word: String
    var isMeld: Bool
    var meldCount: Int
}

struct MindMeldBoardState {
    var category: String? = nil
    var submittedIDs: Set<String> = []
    var submissions: [MeldSubmission] = []
    var showReveal = false

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["category"]?.value as? String        { category = v }
        if let v = data["showReveal"]?.value as? Bool        { showReveal = v }
        if let v = data["submittedIDs"]?.value as? [String]  { submittedIDs = Set(v) }
        if let subs = data["submissions"]?.value as? [[String: Any]] {
            submissions = subs.compactMap { d -> MeldSubmission? in
                guard let id = d["id"] as? String,
                      let name = d["playerName"] as? String,
                      let word = d["word"] as? String else { return nil }
                return MeldSubmission(id: id, playerName: name, word: word,
                                      isMeld: d["isMeld"] as? Bool ?? false,
                                      meldCount: d["meldCount"] as? Int ?? 0)
            }
        }
    }
}

@MainActor final class MindMeldBoardViewModel: ObservableObject {
    @Published var state = MindMeldBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Hot Grid Board

struct TVHotGridBoardView: View {
    let room: Room
    @StateObject private var vm = HotGridBoardViewModel()

    private let gridSize = 5

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Text("💣 Hot Grid").font(.system(size: 44, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("\(vm.state.currentPlayerName)'s turn").font(.title3).foregroundColor(.yellow)
            }
            .padding(.horizontal, 60).padding(.top, 40)

            TVScoreHeader(players: room.players, currentPlayerID: vm.state.currentPlayerID)

            // 5×5 grid
            VStack(spacing: 12) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(0..<gridSize, id: \.self) { col in
                            let idx = row * gridSize + col
                            let tile = vm.state.tiles[safe: idx]
                            HotGridTileView(tile: tile)
                        }
                    }
                }
            }

            Spacer()
        }
        .background(Color(hex: "0a0a0a").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

enum HotGridTileContent { case hidden, coin(Int), trap, teleport }

private struct HotGridTileView: View {
    let tile: HotGridTileContent?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(tileFill)
                .frame(width: 100, height: 100)
            tileContent
        }
    }

    @ViewBuilder private var tileContent: some View {
        switch tile {
        case .hidden, .none:
            Text("?").font(.system(size: 36, weight: .bold)).foregroundColor(.white.opacity(0.3))
        case .coin(let v):
            VStack(spacing: 2) {
                Text("🪙").font(.system(size: 36))
                Text("+\(v)").font(.caption.bold()).foregroundColor(.yellow)
            }
        case .trap:
            Text("💀").font(.system(size: 40))
        case .teleport:
            Text("🌀").font(.system(size: 40))
        }
    }

    private var tileFill: Color {
        switch tile {
        case .hidden, .none: return Color(hex: "1a1a1a")
        case .coin:          return Color.yellow.opacity(0.2)
        case .trap:          return Color.red.opacity(0.25)
        case .teleport:      return Color.purple.opacity(0.25)
        }
    }
}

struct HotGridBoardState {
    var tiles: [HotGridTileContent] = Array(repeating: .hidden, count: 25)
    var currentPlayerID = ""
    var currentPlayerName = ""

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["currentPlayerID"]?.value as? String   { currentPlayerID = v }
        if let v = data["currentPlayerName"]?.value as? String { currentPlayerName = v }
        if let rawTiles = data["tiles"]?.value as? [String] {
            tiles = rawTiles.map { t -> HotGridTileContent in
                if t == "hidden"    { return .hidden }
                if t == "trap"      { return .trap }
                if t == "teleport"  { return .teleport }
                if let v = Int(t)   { return .coin(v) }
                return .hidden
            }
        }
    }
}

@MainActor final class HotGridBoardViewModel: ObservableObject {
    @Published var state = HotGridBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Speed Sculptor Board

struct TVSpeedSculptorBoardView: View {
    let room: Room
    @StateObject private var vm = SpeedSculptorBoardViewModel()

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("🎨 Speed Sculptor").font(.system(size: 40, weight: .bold)).foregroundColor(.white)
                Spacer()
                if let prompt = vm.state.prompt {
                    Text("Drawing: \(prompt)").font(.title2.bold()).foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 60).padding(.top, 40)

            if vm.state.votingPhase {
                // Show all drawings + vote tally
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(room.players.count, 3)),
                          spacing: 20) {
                    ForEach(vm.state.drawings) { drawing in
                        DrawingCard(drawing: drawing)
                    }
                }
                .padding(.horizontal, 60)
            } else {
                // Countdown while players draw
                VStack(spacing: 24) {
                    TimerRing(secondsLeft: vm.state.secondsLeft, total: 20)
                        .frame(width: 120, height: 120)
                    Text("Players are drawing…").font(.title2).foregroundColor(.white.opacity(0.5))
                    let submitted = vm.state.submittedCount
                    Text("\(submitted) / \(room.players.count) submitted")
                        .font(.subheadline).foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

struct PlayerDrawing: Identifiable {
    let id: String
    let playerName: String
    let lines: [[[Double]]]  // simplified line arrays from server
    var voteCount: Int
}

private struct DrawingCard: View {
    let drawing: PlayerDrawing
    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in
                for line in drawing.lines {
                    var path = Path()
                    let pts = line.compactMap { p -> CGPoint? in
                        guard p.count >= 2 else { return nil }
                        return CGPoint(x: p[0] * size.width, y: p[1] * size.height)
                    }
                    guard let first = pts.first else { continue }
                    path.move(to: first)
                    for pt in pts.dropFirst() { path.addLine(to: pt) }
                    ctx.stroke(path, with: .color(.black), lineWidth: 3)
                }
            }
            .background(Color.white)
            .frame(height: 220)
            .cornerRadius(12)

            HStack {
                Text(drawing.playerName).font(.headline).foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill").foregroundColor(.cyan)
                    Text("\(drawing.voteCount)").font(.headline.bold()).foregroundColor(.cyan)
                }
            }
        }
    }
}

struct SpeedSculptorBoardState {
    var prompt: String? = nil
    var secondsLeft = 20
    var votingPhase = false
    var submittedCount = 0
    var drawings: [PlayerDrawing] = []

    mutating func update(from data: [String: AnyCodable]) {
        if let v = data["prompt"]?.value as? String       { prompt = v }
        if let v = data["secondsLeft"]?.value as? Int     { secondsLeft = v }
        if let v = data["votingPhase"]?.value as? Bool    { votingPhase = v }
        if let v = data["submittedCount"]?.value as? Int  { submittedCount = v }
        if let ds = data["drawings"]?.value as? [[String: Any]] {
            drawings = ds.compactMap { d -> PlayerDrawing? in
                guard let id = d["id"] as? String, let name = d["playerName"] as? String else { return nil }
                return PlayerDrawing(id: id, playerName: name,
                                     lines: d["lines"] as? [[[Double]]] ?? [],
                                     voteCount: d["voteCount"] as? Int ?? 0)
            }
        }
    }
}

@MainActor final class SpeedSculptorBoardViewModel: ObservableObject {
    @Published var state = SpeedSculptorBoardState()
    private let socket = GameSocketManager.shared
    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.state.update(from: r.boardState)
        }
    }
}

// MARK: - Array safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - TimerRing (shared across board views)

struct TimerRing: View {
    let secondsLeft: Int
    let total: Int

    private var progress: Double { total > 0 ? Double(secondsLeft) / Double(total) : 0 }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress > 0.4 ? Color.cyan : Color.red,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: secondsLeft)
            Text("\(secondsLeft)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(width: 70, height: 70)
    }
}
