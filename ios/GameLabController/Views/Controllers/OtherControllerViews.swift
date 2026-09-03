import SwiftUI
import CoreMotion

// MARK: - Poker Controller (private hand on phone)

struct PokerControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var hand: [String] { privateData["hand"] as? [String] ?? [] }
    private var chips: Int { privateData["chips"] as? Int ?? 0 }
    private var canBet: Bool { (privateData["isMyTurn"] as? Bool) ?? false }
    @State private var betAmount: Double = 0
    private var minBet: Int { privateData["minBet"] as? Int ?? 0 }
    private var maxBet: Int { chips }

    var body: some View {
        VStack(spacing: 24) {
            // Private hand — only you see this
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash.fill").foregroundColor(.cyan)
                    Text("Your Hand (private)").font(.caption).foregroundColor(.cyan)
                }
                HStack(spacing: 12) {
                    ForEach(hand, id: \.self) { card in
                        CardView(card: card)
                    }
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.cyan.opacity(0.08)))
            .padding(.horizontal, 20)

            Text("Chips: \(chips)").font(.headline).foregroundColor(.white)

            if canBet {
                VStack(spacing: 16) {
                    Text("Your Turn").font(.title3.bold()).foregroundColor(.yellow)

                    // Bet slider
                    VStack(spacing: 8) {
                        Text("Bet: \(Int(betAmount))").foregroundColor(.white)
                        Slider(value: $betAmount, in: Double(minBet)...Double(max(maxBet, minBet)))
                            .tint(.yellow)
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        ActionBtn("Fold",  color: .red)    { onAction("fold",  [:]) }
                        ActionBtn("Check", color: .gray)   { onAction("check", [:]) }
                        ActionBtn("Bet",   color: .yellow)  { onAction("bet",   ["amount": Int(betAmount)]) }
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                Text("Waiting for your turn…")
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
        .background(Color(hex: "001400").ignoresSafeArea())
        .onAppear { betAmount = Double(minBet) }
    }
}

private struct CardView: View {
    let card: String   // e.g. "A♠", "K♥"
    private var isRed: Bool { card.contains("♥") || card.contains("♦") }
    var body: some View {
        Text(card)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(isRed ? .red : .white)
            .frame(width: 60, height: 84)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            .shadow(radius: 4)
    }
}

private struct ActionBtn: View {
    let label: String
    let color: Color
    let action: () -> Void
    init(_ label: String, color: Color, action: @escaping () -> Void) {
        self.label = label; self.color = color; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(label).font(.headline).foregroundColor(color == .yellow ? .black : .white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.85)))
        }.buttonStyle(.plain)
    }
}

// MARK: - Snake & Ladder — Shake to Roll

struct ShakeToRollControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    @State private var lastRoll: Int? = nil
    @State private var shakeScale: CGFloat = 1.0
    private var isMyTurn: Bool { (privateData["isMyTurn"] as? Bool) ?? false }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text("🎲")
                .font(.system(size: 100))
                .scaleEffect(shakeScale)
                .onShake {
                    guard isMyTurn else { return }
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { shakeScale = 1.4 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring()) { shakeScale = 1.0 }
                        let roll = Int.random(in: 1...6)
                        lastRoll = roll
                        onAction("roll", ["value": roll])
                    }
                }

            if let roll = lastRoll {
                Text("You rolled \(roll)!")
                    .font(.largeTitle.bold()).foregroundColor(.white)
            }

            Text(isMyTurn ? "Shake to roll!" : "Not your turn…")
                .font(.title3)
                .foregroundColor(isMyTurn ? .cyan : .white.opacity(0.4))

            if let pos = privateData["position"] as? Int {
                Text("Your position: \(pos)")
                    .font(.subheadline).foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }
}

// MARK: - Pong — Tilt controller

struct PongControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    @StateObject private var motion = MotionManager()
    @State private var lastSent: Date = .distantPast

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("🏓 Pong")
                .font(.largeTitle.bold()).foregroundColor(.white)

            Text("Tilt your phone to move your paddle")
                .foregroundColor(.white.opacity(0.5))

            // Visual tilt indicator
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 120, height: 300)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cyan)
                    .frame(width: 20, height: 60)
                    .offset(y: CGFloat(motion.roll) * 100)
            }

            Text("Side: \(privateData["side"] as? String ?? "?")")
                .font(.caption).foregroundColor(.white.opacity(0.4))

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
        .onChange(of: motion.roll) { roll in
            let now = Date()
            guard now.timeIntervalSince(lastSent) > 0.05 else { return } // 20 fps max
            lastSent = now
            onAction("paddle", ["position": roll])
        }
    }
}

@MainActor
final class MotionManager: ObservableObject {
    @Published var roll: Double = 0
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            self?.roll = max(-1, min(1, motion.attitude.roll / (.pi / 2)))
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

// MARK: - Mind Meld

struct MindMeldControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    @State private var wordInput = ""
    @State private var hasSubmitted = false
    private var category: String { privateData["category"] as? String ?? "" }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("🔮 Mind Meld").font(.largeTitle.bold()).foregroundColor(.white)
            Text("Category: \(category)").font(.title3).foregroundColor(.cyan)
            Text("Type ONE word that fits the category.\nTry to match what others think!").font(.subheadline)
                .foregroundColor(.white.opacity(0.5)).multilineTextAlignment(.center)

            if !hasSubmitted {
                TextField("Your word…", text: $wordInput)
                    .font(.title2).foregroundColor(.white).multilineTextAlignment(.center)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                    .padding(.horizontal, 32)

                Button(action: submit) {
                    Text("Submit").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.purple))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain).disabled(wordInput.isEmpty).padding(.horizontal, 32)
            } else {
                Image(systemName: "brain.filled.head.profile").font(.system(size: 60)).foregroundColor(.purple)
                Text("Word submitted!\nWatch the TV for the meld…").font(.title3).foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .background(Color(hex: "0d0a14").ignoresSafeArea())
    }

    private func submit() {
        guard !wordInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        hasSubmitted = true
        onAction("word", ["word": wordInput.trimmingCharacters(in: .whitespaces).lowercased()])
    }
}

// MARK: - Hot Grid

struct HotGridControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    @State private var hasPicked = false
    private var isMyTurn: Bool { (privateData["isMyTurn"] as? Bool) ?? false }
    private let gridSize = 5

    var body: some View {
        VStack(spacing: 24) {
            Text("💣 Hot Grid").font(.largeTitle.bold()).foregroundColor(.white)
            Text(isMyTurn ? "Pick a tile!" : "Waiting for your turn…")
                .font(.title3).foregroundColor(isMyTurn ? .yellow : .white.opacity(0.4))

            if isMyTurn && !hasPicked {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: gridSize), spacing: 12) {
                    ForEach(0..<gridSize*gridSize, id: \.self) { idx in
                        Button(action: { pick(idx) }) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 52)
                                .overlay(Text("?").font(.title2).foregroundColor(.white.opacity(0.5)))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            Spacer()
        }
        .padding(.top, 40)
        .background(Color(hex: "0a0a0a").ignoresSafeArea())
    }

    private func pick(_ index: Int) {
        hasPicked = true
        onAction("pick_tile", ["index": index])
    }
}

// MARK: - Stock Panic

struct StockPanicControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var portfolio: [String: Int] { privateData["portfolio"] as? [String: Int] ?? [:] }
    private var cash: Int { privateData["cash"] as? Int ?? 0 }
    private var stocks: [String] { portfolio.keys.sorted() }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("📈 Stock Panic").font(.title.bold()).foregroundColor(.white)
                Text("Cash: $\(cash)").font(.headline).foregroundColor(.green)

                ForEach(stocks, id: \.self) { stock in
                    HStack(spacing: 16) {
                        Text(stock).font(.headline).foregroundColor(.white).frame(width: 80)
                        Text("×\(portfolio[stock] ?? 0)").foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Button("Buy") { onAction("trade", ["stock": stock, "action": "buy"]) }
                            .foregroundColor(.green).padding(.horizontal, 14).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.2)))
                            .buttonStyle(.plain)
                        Button("Sell") { onAction("trade", ["stock": stock, "action": "sell"]) }
                            .foregroundColor(.red).padding(.horizontal, 14).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.2)))
                            .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                }
            }
            .padding(24)
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }
}

// MARK: - Speed Sculptor (drawing canvas)

struct SpeedSculptorControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    @State private var lines: [DrawLine] = []
    @State private var currentLine: DrawLine? = nil
    @State private var submitted = false
    private var prompt: String { privateData["prompt"] as? String ?? "?" }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("🎨 Draw: \(prompt)").font(.headline).foregroundColor(.white)
                Spacer()
                Button("Clear") { lines = []; currentLine = nil }
                    .foregroundColor(.cyan).buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.white.opacity(0.06))

            // Drawing canvas
            Canvas { ctx, size in
                for line in lines {
                    var path = Path()
                    guard let first = line.points.first else { continue }
                    path.move(to: first)
                    for pt in line.points.dropFirst() { path.addLine(to: pt) }
                    ctx.stroke(path, with: .color(line.color), style: .init(lineWidth: line.width, lineCap: .round, lineJoin: .round))
                }
                if let current = currentLine {
                    var path = Path()
                    guard let first = current.points.first else { return }
                    path.move(to: first)
                    for pt in current.points.dropFirst() { path.addLine(to: pt) }
                    ctx.stroke(path, with: .color(current.color), style: .init(lineWidth: current.width, lineCap: .round, lineJoin: .round))
                }
            }
            .background(Color.white)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if currentLine == nil {
                            currentLine = DrawLine(points: [value.location], color: .black, width: 4)
                        } else {
                            currentLine?.points.append(value.location)
                        }
                    }
                    .onEnded { _ in
                        if let line = currentLine { lines.append(line) }
                        currentLine = nil
                    }
            )

            if !submitted {
                Button(action: submitDrawing) {
                    Text("Submit Drawing").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.purple))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain).padding(16)
            } else {
                Text("✓ Submitted! Watch the TV.").foregroundColor(.green).padding(16)
            }
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }

    private func submitDrawing() {
        submitted = true
        // Encode lines as simplified point arrays for server
        let encoded = lines.map { line in
            line.points.map { ["x": $0.x, "y": $0.y] }
        }
        onAction("drawing", ["lines": encoded, "prompt": prompt])
    }
}

struct DrawLine {
    var points: [CGPoint]
    let color: Color
    let width: CGFloat
}

// MARK: - Tambola (Bingo ticket)

struct TambolaControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var ticket: [[Int?]] { (privateData["ticket"] as? [[Int?]]) ?? [] }
    private var markedNumbers: Set<Int> {
        Set((privateData["marked"] as? [Int]) ?? [])
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("🎱 Tambola").font(.title.bold()).foregroundColor(.white)
            Text("Your Ticket").font(.subheadline).foregroundColor(.white.opacity(0.4))

            VStack(spacing: 6) {
                ForEach(Array(ticket.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, num in
                            if let n = num {
                                Button(action: { onAction("mark", ["number": n]) }) {
                                    Text("\(n)").font(.system(.body, design: .monospaced).bold())
                                        .frame(width: 40, height: 40)
                                        .background(RoundedRectangle(cornerRadius: 8)
                                            .fill(markedNumbers.contains(n) ? Color.green.opacity(0.4) : Color.white.opacity(0.1)))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.03))
                                    .frame(width: 40, height: 40)
                            }
                        }
                    }
                }
            }

            Button(action: { onAction("claim", ["type": "full_house"]) }) {
                Text("🎉 Claim Full House!").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.yellow.opacity(0.85)))
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain).padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 40)
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }
}

// MARK: - Generic tap controller (fallback)

struct GenericTapControllerView: View {
    let room: Room
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(room.gameID.emoji).font(.system(size: 72))
            Text(room.gameID.displayName).font(.title.bold()).foregroundColor(.white)
            Text("Game in progress").foregroundColor(.white.opacity(0.4))
            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }
}

// TV board views are defined in TVClassicGameBoards.swift and TVHeistBoardView.swift

// MARK: - Results views

struct TVResultsView: View {
    let room: Room
    let onPlayAgain: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 8) {
                Text("🏆 Final Results").font(.system(size: 56, weight: .black)).foregroundColor(.white)
                Text(room.gameID.displayName).font(.title3).foregroundColor(.white.opacity(0.4))
            }

            let sorted = room.players.sorted { $0.score > $1.score }
            VStack(spacing: 16) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { rank, player in
                    HStack(spacing: 24) {
                        Text(rank == 0 ? "🥇" : rank == 1 ? "🥈" : rank == 2 ? "🥉" : "\(rank+1).")
                            .font(.system(size: 40)).frame(width: 60)
                        Text(player.name).font(.title2.bold()).foregroundColor(.white)
                        Spacer()
                        Text("\(player.score) pts")
                            .font(.title.bold())
                            .foregroundColor(rank == 0 ? .yellow : .cyan)
                    }
                    .padding(.horizontal, 100)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(rank == 0 ? Color.yellow.opacity(0.1) : Color.white.opacity(0.05))
                    )
                    .padding(.horizontal, 60)
                }
            }

            Button(action: onPlayAgain) {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .font(.title3.bold())
                    .padding(.horizontal, 60).padding(.vertical, 20)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.purple))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }
}

struct ResultsControllerView: View {
    let room: Room
    let onLeave: () -> Void

    private var myID: String { AppConstants.deviceID }
    private var sorted: [Player] { room.players.sorted { $0.score > $1.score } }
    private var myRank: Int {
        (sorted.firstIndex(where: { $0.id == myID }) ?? 0) + 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("🏁 Game Over").font(.largeTitle.bold()).foregroundColor(.white)
                Text(room.gameID.displayName).font(.subheadline).foregroundColor(.white.opacity(0.4))
            }
            .padding(.top, 48).padding(.bottom, 24)

            // My rank callout
            HStack(spacing: 12) {
                Text(rankEmoji(myRank)).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text("You finished \(ordinal(myRank))").font(.headline).foregroundColor(.white)
                    if let me = sorted.first(where: { $0.id == myID }) {
                        Text("\(me.score) points").font(.subheadline).foregroundColor(.cyan)
                    }
                }
                Spacer()
            }
            .padding(16).padding(.horizontal, 24)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
            .padding(.horizontal, 24)

            // Full leaderboard
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { rank, player in
                        HStack(spacing: 12) {
                            Text(rankEmoji(rank + 1)).font(.title3).frame(width: 36)
                            Text(player.name)
                                .font(.body)
                                .foregroundColor(player.id == myID ? .cyan : .white)
                                .fontWeight(player.id == myID ? .bold : .regular)
                            if player.id == myID {
                                Text("YOU").font(.caption2.bold()).foregroundColor(.cyan)
                            }
                            Spacer()
                            Text("\(player.score)").font(.headline.bold()).foregroundColor(.white)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(player.id == myID ? Color.cyan.opacity(0.1) : Color.white.opacity(0.04)))
                    }
                }
                .padding(.horizontal, 24).padding(.top, 16)
            }

            Spacer()

            Button(action: onLeave) {
                Label("Leave Room", systemImage: "arrow.left.circle")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.1)))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain).padding(.horizontal, 24).padding(.bottom, 40)
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }

    private func rankEmoji(_ rank: Int) -> String {
        switch rank { case 1: return "🥇"; case 2: return "🥈"; case 3: return "🥉"; default: return "\(rank)." }
    }

    private func ordinal(_ n: Int) -> String {
        switch n { case 1: return "1st"; case 2: return "2nd"; case 3: return "3rd"; default: return "\(n)th" }
    }
}

// MARK: - Shake gesture

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(ShakeDetector(action: action))
    }
}

struct ShakeDetector: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .deviceDidShakeNotification)) { _ in
            action()
        }
    }
}

extension Notification.Name {
    static let deviceDidShakeNotification = Notification.Name("DeviceDidShake")
}
