import SwiftUI

struct TVTriviaBoardView: View {
    let room: Room
    @StateObject private var vm = TriviaboardViewModel()

    var body: some View {
        VStack(spacing: 32) {
            // Score bar
            HStack {
                ForEach(vm.players) { p in
                    PlayerScoreChip(player: p, isAnswered: vm.answeredIDs.contains(p.id))
                }
            }
            .padding(.horizontal, 60)

            if let q = vm.currentQuestion {
                // Category tag
                Text(q.category.uppercased())
                    .font(.caption.bold())
                    .tracking(3)
                    .foregroundColor(.cyan.opacity(0.8))

                // Question
                Text(q.text)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 100)
                    .fixedSize(horizontal: false, vertical: true)

                // Choices — revealed one second after question appears
                if vm.showChoices {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 20
                    ) {
                        ForEach(Array(q.choices.enumerated()), id: \.offset) { idx, choice in
                            ChoiceTile(
                                label: choice,
                                index: idx,
                                state: vm.choiceState(for: idx, correctIndex: q.correctIndex)
                            )
                        }
                    }
                    .padding(.horizontal, 80)
                }

                // Timer ring
                TimerRing(secondsLeft: vm.secondsLeft, total: 20)

            } else {
                Text("Loading question…")
                    .foregroundColor(.white.opacity(0.3))
            }

            Spacer()
        }
        .padding(.top, 48)
        .background(Color(hex: "0a0a14").ignoresSafeArea())
        .onAppear { vm.bind(roomCode: room.code) }
    }
}

private struct PlayerScoreChip: View {
    let player: Player
    let isAnswered: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isAnswered ? Color.green.opacity(0.4) : Color.white.opacity(0.1))
                .frame(width: 10, height: 10)
            Text(player.name)
                .font(.body)
                .foregroundColor(isAnswered ? .white : .white.opacity(0.4))
            Text("\(player.score)")
                .font(.headline.bold())
                .foregroundColor(.cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.07)))
    }
}

private struct ChoiceTile: View {
    enum ChoiceState { case idle, correct, wrong }
    let label: String
    let index: Int
    let state: ChoiceState

    private let letters = ["A", "B", "C", "D"]

    var body: some View {
        HStack(spacing: 16) {
            Text(letters[index])
                .font(.headline.bold())
                .frame(width: 40, height: 40)
                .background(Circle().fill(badgeColor))
                .foregroundColor(.white)

            Text(label)
                .font(.title3)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(tileFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(borderColor, lineWidth: 2)
                )
        )
    }

    private var badgeColor: Color {
        switch state {
        case .idle:    return Color.white.opacity(0.15)
        case .correct: return .green
        case .wrong:   return .red
        }
    }

    private var tileFill: Color {
        switch state {
        case .idle:    return Color.white.opacity(0.06)
        case .correct: return Color.green.opacity(0.15)
        case .wrong:   return Color.red.opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:    return Color.white.opacity(0.08)
        case .correct: return .green.opacity(0.8)
        case .wrong:   return .red.opacity(0.5)
        }
    }
}

// MARK: - ViewModel

struct TriviaQuestion {
    let text: String
    let choices: [String]
    let correctIndex: Int
    let category: String
}

@MainActor
final class TriviaboardViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var currentQuestion: TriviaQuestion? = nil
    @Published var showChoices = false
    @Published var secondsLeft = 20
    @Published var answeredIDs: Set<String> = []
    @Published var revealedCorrectIndex: Int? = nil

    private let socket = GameSocketManager.shared

    func bind(roomCode: String) {
        socket.on(.gameState) { [weak self] (r: GameStateResponse) in
            guard r.roomCode == roomCode else { return }
            self?.updateState(from: r.boardState)
        }
    }

    func choiceState(for index: Int, correctIndex: Int) -> ChoiceTile.ChoiceState {
        guard let revealed = revealedCorrectIndex else { return .idle }
        if index == revealed { return .correct }
        return .idle
    }

    private func updateState(from data: [String: AnyCodable]) {
        if let s = data["secondsLeft"]?.value as? Int { secondsLeft = s }
        // Parse question, choices, players from server payload
    }
}
