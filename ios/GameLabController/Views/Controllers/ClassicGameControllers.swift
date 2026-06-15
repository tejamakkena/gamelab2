import SwiftUI

// MARK: - Connect 4 Controller

struct Connect4ControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var isMyTurn: Bool { privateData["isMyTurn"] as? Bool ?? false }
    private var myColor: String { privateData["color"] as? String ?? "red" }
    private var columnsFull: Set<Int> {
        Set((privateData["fullColumns"] as? [Int]) ?? [])
    }

    @State private var hoveredCol: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🟡 Connect 4").font(.headline).foregroundColor(.white)
                Spacer()
                Circle()
                    .fill(myColor == "red" ? Color.red : Color.yellow)
                    .frame(width: 24, height: 24)
                Text("You").font(.subheadline).foregroundColor(.white.opacity(0.6))
            }
            .padding(20).background(Color.white.opacity(0.04))

            Spacer()

            if isMyTurn {
                VStack(spacing: 20) {
                    Text("Drop your disc!").font(.title3.bold()).foregroundColor(.yellow)

                    // 7-column tap strip
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { col in
                            let full = columnsFull.contains(col)
                            Button(action: { if !full { drop(col) } }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "chevron.down")
                                        .font(.caption.bold())
                                        .foregroundColor(hoveredCol == col ? .yellow : .white.opacity(0.4))

                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(full ? Color.white.opacity(0.05) : (hoveredCol == col
                                            ? (myColor == "red" ? Color.red.opacity(0.6) : Color.yellow.opacity(0.6))
                                            : Color.white.opacity(0.12)))
                                        .frame(height: 200)
                                        .overlay(
                                            full ? Image(systemName: "xmark").foregroundColor(.white.opacity(0.2)) : nil
                                        )

                                    Text("\(col + 1)").font(.caption2).foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .buttonStyle(.plain).disabled(full)
                            .simultaneousGesture(DragGesture(minimumDistance: 0)
                                .onChanged { _ in hoveredCol = col }
                                .onEnded { _ in hoveredCol = nil }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                waitingLabel("Opponent's turn…")
            }

            Spacer()
        }
        .background(Color(hex: "00040d").ignoresSafeArea())
    }

    private func drop(_ col: Int) {
        onAction("drop", ["column": col])
    }
}

// MARK: - Chess Controller

struct ChessControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var isMyTurn: Bool { privateData["isMyTurn"] as? Bool ?? false }
    private var myColor: String { privateData["pieceColor"] as? String ?? "white" }
    private var board: [[String]] {
        privateData["board"] as? [[String]] ?? Array(repeating: Array(repeating: "", count: 8), count: 8)
    }
    private var validMoves: [[Int]] {
        privateData["validMoves"] as? [[Int]] ?? []
    }

    @State private var selectedSquare: [Int]? = nil

    private var validMoveSet: Set<String> {
        Set(validMoves.map { "\($0[0]),\($0[1])" })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("♟️ Chess").font(.headline).foregroundColor(.white)
                Spacer()
                Text(myColor.capitalized).font(.subheadline)
                    .foregroundColor(myColor == "white" ? .white : .black.opacity(0.8))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(myColor == "white" ? Color.white.opacity(0.2) : Color.black.opacity(0.8)))
            }
            .padding(16).background(Color.white.opacity(0.04))

            if isMyTurn {
                Text(selectedSquare == nil ? "Tap your piece" : "Tap destination")
                    .font(.subheadline).foregroundColor(.cyan.opacity(0.8))
                    .padding(.vertical, 8)
            } else {
                Text("Opponent thinking…").font(.subheadline).foregroundColor(.white.opacity(0.4)).padding(.vertical, 8)
            }

            // 8×8 board
            VStack(spacing: 1) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<8, id: \.self) { col in
                            let piece = board[row][col]
                            let isSelected = selectedSquare == [row, col]
                            let isValidTarget = validMoveSet.contains("\(row),\(col)")
                            let isLight = (row + col) % 2 == 0

                            Button(action: { tapSquare(row: row, col: col) }) {
                                ZStack {
                                    Rectangle().fill(
                                        isSelected ? Color.yellow.opacity(0.6) :
                                        isValidTarget ? Color.green.opacity(0.4) :
                                        isLight ? Color(hex: "f0d9b5") : Color(hex: "b58863")
                                    )
                                    if !piece.isEmpty {
                                        Text(piece).font(.system(size: 28))
                                    }
                                    if isValidTarget && piece.isEmpty {
                                        Circle().fill(Color.green.opacity(0.5)).frame(width: 14, height: 14)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain).disabled(!isMyTurn)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(hex: "1a1a1a"))
            .cornerRadius(12)
            .padding(.horizontal, 12)

            if let sel = selectedSquare {
                Button(action: { selectedSquare = nil }) {
                    Label("Deselect (\(chessCellLabel(sel[0], sel[1])))", systemImage: "xmark.circle")
                        .font(.caption).foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain).padding(.top, 8)
            }

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }

    private func tapSquare(row: Int, col: Int) {
        guard isMyTurn else { return }
        let piece = board[row][col]
        if let sel = selectedSquare {
            if validMoveSet.contains("\(row),\(col)") {
                onAction("move", ["from": sel, "to": [row, col]])
                selectedSquare = nil
            } else if !piece.isEmpty {
                // Re-select different own piece
                onAction("select", ["row": row, "col": col])
                selectedSquare = [row, col]
            } else {
                selectedSquare = nil
            }
        } else if !piece.isEmpty {
            onAction("select", ["row": row, "col": col])
            selectedSquare = [row, col]
        }
    }

    private func chessCellLabel(_ row: Int, _ col: Int) -> String {
        let files = ["a","b","c","d","e","f","g","h"]
        return "\(files[col])\(8 - row)"
    }
}

// MARK: - Memory Controller

struct MemoryControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var isMyTurn: Bool { privateData["isMyTurn"] as? Bool ?? false }
    private var myScore: Int { privateData["myScore"] as? Int ?? 0 }
    private var flippedIndices: Set<Int> {
        Set((privateData["flipped"] as? [Int]) ?? [])
    }
    private var matchedIndices: Set<Int> {
        Set((privateData["matched"] as? [Int]) ?? [])
    }
    private var cardCount: Int { privateData["cardCount"] as? Int ?? 16 }
    private var cardValues: [String] {
        privateData["cardValues"] as? [String] ?? Array(repeating: "?", count: cardCount)
    }

    private let cols = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("🧩 Memory").font(.headline).foregroundColor(.white)
                Spacer()
                Text("Pairs: \(myScore)").font(.subheadline.bold()).foregroundColor(.cyan)
            }
            .padding(16).background(Color.white.opacity(0.04))

            Spacer()

            if isMyTurn {
                Text("Flip two cards!").font(.subheadline).foregroundColor(.green.opacity(0.8))
                    .padding(.vertical, 8)
            } else {
                waitingLabel("Opponent's turn…")
                    .padding(.vertical, 8)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: cols), spacing: 10) {
                ForEach(0..<cardCount, id: \.self) { idx in
                    let revealed = flippedIndices.contains(idx) || matchedIndices.contains(idx)
                    let matched = matchedIndices.contains(idx)

                    Button(action: { tapCard(idx) }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(matched ? Color.green.opacity(0.3) :
                                      revealed ? Color.white.opacity(0.15) :
                                      Color(hex: "1e1e3a"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(matched ? Color.green.opacity(0.6) : Color.white.opacity(0.08),
                                                      lineWidth: 1.5)
                                )

                            if revealed {
                                Text(cardValues[idx]).font(.system(size: 28))
                            } else {
                                Image(systemName: "questionmark").font(.title2)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                        .frame(height: 70)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isMyTurn || revealed)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }

    private func tapCard(_ index: Int) {
        guard isMyTurn, !flippedIndices.contains(index), !matchedIndices.contains(index) else { return }
        onAction("flip", ["index": index])
    }
}

// MARK: - Roulette Controller

struct RouletteControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var chips: Int { privateData["chips"] as? Int ?? 100 }
    private var currentBets: [String: Int] { privateData["bets"] as? [String: Int] ?? [:] }
    private var isSpinning: Bool { privateData["isSpinning"] as? Bool ?? false }
    private var lastResult: Int? { privateData["lastResult"] as? Int }

    @State private var selectedChip = 5

    private let chipValues = [1, 5, 25, 100]
    private let betTargets: [(String, String)] = [
        ("red", "🔴 Red"), ("black", "⚫ Black"),
        ("odd", "Odd"), ("even", "Even"),
        ("1-12", "1st 12"), ("13-24", "2nd 12"), ("25-36", "3rd 12"),
        ("low", "1–18"), ("high", "19–36"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("🎡 Roulette").font(.title2.bold()).foregroundColor(.white)
                    Spacer()
                    Text("$\(chips)").font(.headline.bold()).foregroundColor(.green)
                }
                .padding(.horizontal, 20).padding(.top, 20)

                if let result = lastResult {
                    Text("Last spin: \(result)").font(.subheadline)
                        .foregroundColor(.yellow).padding(.horizontal, 20)
                }

                // Chip selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chip value").font(.caption.bold()).foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 20)
                    HStack(spacing: 10) {
                        ForEach(chipValues, id: \.self) { val in
                            Button(action: { selectedChip = val }) {
                                Text("$\(val)").font(.headline)
                                    .frame(width: 64, height: 44)
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedChip == val ? Color.yellow.opacity(0.8) : Color.white.opacity(0.1)))
                                    .foregroundColor(selectedChip == val ? .black : .white)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Button(action: clearBets) {
                            Label("Clear", systemImage: "trash").font(.caption)
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain).padding(.trailing, 20)
                    }
                    .padding(.horizontal, 20)
                }

                // Bet targets
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 10) {
                    ForEach(betTargets, id: \.0) { id, label in
                        BetTile(
                            label: label,
                            betAmount: currentBets[id] ?? 0,
                            onTap: { placeBet(on: id) }
                        )
                    }
                }
                .padding(.horizontal, 16)

                // Spin button
                Button(action: spin) {
                    Text(isSpinning ? "Spinning…" : "🎰 Spin!")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(isSpinning ? Color.white.opacity(0.1) : Color.green.opacity(0.85)))
                        .foregroundColor(isSpinning ? .white.opacity(0.4) : .black)
                }
                .buttonStyle(.plain).disabled(isSpinning || currentBets.isEmpty).padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(Color(hex: "060d00").ignoresSafeArea())
    }

    private func placeBet(on target: String) {
        guard !isSpinning, selectedChip <= chips else { return }
        onAction("place_bet", ["target": target, "amount": selectedChip])
    }

    private func clearBets() {
        onAction("clear_bets", [:])
    }

    private func spin() {
        onAction("spin", [:])
    }
}

private struct BetTile: View {
    let label: String
    let betAmount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(label).font(.body).foregroundColor(.white)
                if betAmount > 0 {
                    Text("$\(betAmount)").font(.caption.bold()).foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(betAmount > 0 ? Color.green.opacity(0.2) : Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(betAmount > 0 ? Color.green.opacity(0.5) : Color.white.opacity(0.08),
                                  lineWidth: 1.5)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mafia Controller

struct MafiaControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var role: String { privateData["role"] as? String ?? "town" }
    private var phase: String { privateData["phase"] as? String ?? "day" }
    private var isAlive: Bool { privateData["isAlive"] as? Bool ?? true }
    private var players: [[String: Any]] { privateData["players"] as? [[String: Any]] ?? [] }
    private var myVote: String? { privateData["myVote"] as? String }
    private var investigateResult: String? { privateData["investigateResult"] as? String }

    var body: some View {
        VStack(spacing: 0) {
            // Role card
            roleCard

            Spacer()

            if !isAlive {
                eliminatedView
            } else if phase == "day" {
                dayPhaseView
            } else {
                nightPhaseView
            }

            Spacer()
        }
        .background(Color(hex: phase == "day" ? "0a0814" : "000814").ignoresSafeArea())
    }

    private var roleCard: some View {
        let (emoji, color, desc): (String, Color, String) = {
            switch role {
            case "mafia":   return ("🔪", .red, "Eliminate town at night")
            case "sheriff": return ("⭐", .yellow, "Investigate one player per night")
            case "doctor":  return ("💉", .green, "Save one player per night")
            default:        return ("👤", .white, "Vote out Mafia during the day")
            }
        }()

        return HStack(spacing: 12) {
            Text(emoji).font(.system(size: 36))
            VStack(alignment: .leading, spacing: 2) {
                Text(role.capitalized).font(.headline).foregroundColor(color)
                Text(desc).font(.caption).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            Text(phase == "day" ? "☀️ Day" : "🌙 Night")
                .font(.caption.bold())
                .foregroundColor(phase == "day" ? .yellow : .cyan)
        }
        .padding(20)
        .background(color.opacity(0.1))
    }

    private var dayPhaseView: some View {
        VStack(spacing: 16) {
            Text("Vote to eliminate").font(.headline).foregroundColor(.white.opacity(0.7))
            ForEach(alivePlayers, id: \.0) { id, name in
                Button(action: { vote(for: id) }) {
                    HStack {
                        Text(name).foregroundColor(.white)
                        Spacer()
                        if myVote == id {
                            Label("Your vote", systemImage: "checkmark").font(.caption).foregroundColor(.red)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(myVote == id ? Color.red.opacity(0.2) : Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(myVote == id ? Color.red.opacity(0.5) : .clear, lineWidth: 1.5)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
    }

    private var nightPhaseView: some View {
        VStack(spacing: 16) {
            switch role {
            case "mafia":
                Text("Choose your target").font(.headline).foregroundColor(.red)
                ForEach(alivePlayers.filter { $0.0 != (privateData["myID"] as? String ?? "") }, id: \.0) { id, name in
                    Button(action: { nightAction(action: "eliminate", targetID: id) }) {
                        Text(name).foregroundColor(.white).frame(maxWidth: .infinity).padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

            case "doctor":
                Text("Save someone tonight").font(.headline).foregroundColor(.green)
                ForEach(alivePlayers, id: \.0) { id, name in
                    Button(action: { nightAction(action: "save", targetID: id) }) {
                        Text(name).foregroundColor(.white).frame(maxWidth: .infinity).padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

            case "sheriff":
                Text("Investigate a player").font(.headline).foregroundColor(.yellow)
                if let result = investigateResult {
                    Text("Result: \(result)").font(.body.bold())
                        .foregroundColor(result.lowercased().contains("mafia") ? .red : .green)
                        .padding(.horizontal, 24)
                }
                ForEach(alivePlayers.filter { $0.0 != (privateData["myID"] as? String ?? "") }, id: \.0) { id, name in
                    Button(action: { nightAction(action: "investigate", targetID: id) }) {
                        Text(name).foregroundColor(.white).frame(maxWidth: .infinity).padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

            default:
                VStack(spacing: 12) {
                    Text("🌙").font(.system(size: 56))
                    Text("Sleep tight…\nMafia is choosing their target.").font(.body)
                        .foregroundColor(.white.opacity(0.5)).multilineTextAlignment(.center)
                }
            }
        }
    }

    private var eliminatedView: some View {
        VStack(spacing: 16) {
            Text("💀").font(.system(size: 72))
            Text("You were eliminated").font(.title2.bold()).foregroundColor(.red)
            Text("Watch the TV to see how the game ends.").font(.subheadline)
                .foregroundColor(.white.opacity(0.5)).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    private var alivePlayers: [(String, String)] {
        players.compactMap { d -> (String, String)? in
            guard let id = d["id"] as? String,
                  let name = d["name"] as? String,
                  d["isAlive"] as? Bool ?? true else { return nil }
            return (id, name)
        }
    }

    private func vote(for targetID: String) {
        onAction("vote", ["targetID": targetID])
    }

    private func nightAction(action: String, targetID: String) {
        onAction(action, ["targetID": targetID])
    }
}

// MARK: - Digit Guess Controller (Mastermind / Bulls & Cows)

struct DigitGuessControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var isMyTurn: Bool { privateData["isMyTurn"] as? Bool ?? true }
    private var myGuesses: [[String: Any]] { privateData["myGuesses"] as? [[String: Any]] ?? [] }
    private var won: Bool { privateData["won"] as? Bool ?? false }

    @State private var digits: [Int] = [0, 0, 0, 0]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("🔢 Digit Guess").font(.headline).foregroundColor(.white)
                Spacer()
                Text("Guesses: \(myGuesses.count)").font(.subheadline).foregroundColor(.white.opacity(0.5))
            }
            .padding(16).background(Color.white.opacity(0.04))

            Spacer()

            if won {
                VStack(spacing: 12) {
                    Text("🎉").font(.system(size: 60))
                    Text("You cracked it!").font(.title2.bold()).foregroundColor(.green)
                    Text("in \(myGuesses.count) guesses").foregroundColor(.white.opacity(0.5))
                }
            } else {
                VStack(spacing: 24) {
                    Text("Guess the 4-digit code").font(.subheadline).foregroundColor(.white.opacity(0.5))

                    // 4-digit selectors
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { pos in
                            VStack(spacing: 0) {
                                Button(action: { digits[pos] = (digits[pos] + 1) % 10 }) {
                                    Image(systemName: "chevron.up").foregroundColor(.white.opacity(0.5)).frame(height: 32)
                                }
                                .buttonStyle(.plain)

                                Text("\(digits[pos])")
                                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))

                                Button(action: { digits[pos] = (digits[pos] + 9) % 10 }) {
                                    Image(systemName: "chevron.down").foregroundColor(.white.opacity(0.5)).frame(height: 32)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button(action: submitGuess) {
                        Text("Submit Guess").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(isMyTurn ? Color.purple : Color.white.opacity(0.08)))
                            .foregroundColor(isMyTurn ? .white : .white.opacity(0.3))
                    }
                    .buttonStyle(.plain).disabled(!isMyTurn).padding(.horizontal, 24)

                    // Guess history
                    if !myGuesses.isEmpty {
                        VStack(spacing: 6) {
                            Text("Your guesses").font(.caption.bold()).foregroundColor(.white.opacity(0.4))
                            ForEach(Array(myGuesses.enumerated()), id: \.offset) { _, g in
                                HStack {
                                    Text(g["guess"] as? String ?? "????")
                                        .font(.system(.body, design: .monospaced).bold()).foregroundColor(.white)
                                    Spacer()
                                    Text("🐂\(g["bulls"] as? Int ?? 0)  🐄\(g["cows"] as? Int ?? 0)")
                                        .font(.caption).foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }

    private func submitGuess() {
        guard isMyTurn else { return }
        onAction("guess", ["digits": digits, "code": digits.map(String.init).joined()])
    }
}

// MARK: - Raja Mantri Controller

struct RajaMantriControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var role: String { privateData["role"] as? String ?? "" }
    private var phase: String { privateData["phase"] as? String ?? "deal" }
    private var players: [(String, String)] {
        let raw = privateData["players"] as? [[String: Any]] ?? []
        return raw.compactMap { d -> (String, String)? in
            guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
            return (id, name)
        }
    }
    private var myScore: Int { privateData["score"] as? Int ?? 0 }
    private var hasGuessed: Bool { privateData["hasGuessed"] as? Bool ?? false }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("👑 Raja Mantri").font(.headline).foregroundColor(.white)
                Spacer()
                Text("Score: \(myScore)").font(.subheadline.bold()).foregroundColor(.cyan)
            }
            .padding(16).background(Color.white.opacity(0.04))

            Spacer()

            VStack(spacing: 24) {
                // Role card
                if !role.isEmpty {
                    VStack(spacing: 8) {
                        Text(roleEmoji(role)).font(.system(size: 72))
                        Text(role).font(.system(size: 32, weight: .bold)).foregroundColor(roleColor(role))
                        Text(roleDesc(role)).font(.subheadline).foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 20).fill(roleColor(role).opacity(0.08)))
                    .padding(.horizontal, 24)
                }

                // Sipahi guesses who is the Chor
                if role == "Sipahi" && phase == "guess" && !hasGuessed {
                    VStack(spacing: 12) {
                        Text("Catch the Chor!").font(.headline.bold()).foregroundColor(.yellow)
                        Text("Who is the thief?").font(.subheadline).foregroundColor(.white.opacity(0.5))
                        ForEach(players, id: \.0) { id, name in
                            Button(action: { onAction("accuse", ["targetID": id]) }) {
                                HStack {
                                    Text(name).foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "hand.point.right.fill").foregroundColor(.yellow)
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                } else if phase == "wait" || hasGuessed {
                    Label("Wait for the round to end", systemImage: "hourglass")
                        .font(.subheadline).foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()
        }
        .background(Color(hex: "0a0a14").ignoresSafeArea())
    }

    private func roleEmoji(_ r: String) -> String {
        switch r { case "Raja": return "👑"; case "Mantri": return "🎩"; case "Chor": return "🦹"; default: return "⚔️" }
    }
    private func roleColor(_ r: String) -> Color {
        switch r { case "Raja": return .yellow; case "Mantri": return .purple; case "Chor": return .red; default: return .cyan }
    }
    private func roleDesc(_ r: String) -> String {
        switch r {
        case "Raja":   return "You are the King. Stay safe."
        case "Mantri": return "You are the Minister. Protect the Raja."
        case "Chor":   return "You are the Thief. Hide your identity!"
        default:       return "You are the Guard. Find the Chor!"
        }
    }
}

// MARK: - Shared helpers

private func waitingLabel(_ text: String) -> some View {
    Label(text, systemImage: "hourglass")
        .font(.subheadline).foregroundColor(.white.opacity(0.4))
}
