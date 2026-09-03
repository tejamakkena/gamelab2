import SwiftUI

struct TVGameSelectionView: View {
    let onSelect: (GameID) -> Void

    @State private var selectedCategory: GameCategory? = nil
    @FocusState private var focusedGame: GameID?

    private var displayedGames: [GameID] {
        if let cat = selectedCategory {
            return GameID.allCases.filter { $0.category == cat }
        }
        return GameID.allCases
    }

    var body: some View {
        HStack(spacing: 60) {
            // Left sidebar — categories
            VStack(alignment: .leading, spacing: 20) {
                Text("GameLab")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing)
                    )

                Text("Pick a game")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))

                Divider().background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 12) {
                    CategoryPill(label: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(GameCategory.allCases, id: \.self) { cat in
                        CategoryPill(label: cat.rawValue, isSelected: selectedCategory == cat) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }

                Spacer()

                // Connection status dot
                HStack(spacing: 8) {
                    Circle()
                        .fill(GameSocketManager.shared.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(GameSocketManager.shared.isConnected ? "Server connected" : "Reconnecting…")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(width: 280)
            .padding(.vertical, 60)
            .padding(.leading, 60)

            // Right — game grid
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(260), spacing: 28), count: 4),
                    spacing: 28
                ) {
                    ForEach(displayedGames, id: \.self) { game in
                        TVGameCard(game: game, isFocused: focusedGame == game)
                            .focused($focusedGame, equals: game)
                            .onPlayPauseCommand { onSelect(game) }
                            // tvOS primary action = select button
                            .onMoveCommand { _ in }
                            .buttonStyle(.plain)
                            .onTapGesture { onSelect(game) }
                    }
                }
                .padding(.vertical, 60)
                .padding(.trailing, 60)
            }
        }
    }
}

// MARK: - Subviews

private struct TVGameCard: View {
    let game: GameID
    let isFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            Text(game.emoji)
                .font(.system(size: 64))

            Text(game.displayName)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("\(game.minPlayers)–\(game.maxPlayers) players")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 4) {
                if game.hasPrivateInfo {
                    Label("Private info", systemImage: "eye.slash.fill")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }
            }
        }
        .frame(width: 240, height: 200)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isFocused
                      ? Color.purple.opacity(0.4)
                      : Color.white.opacity(0.07))
                .shadow(color: isFocused ? .purple.opacity(0.6) : .clear, radius: 20)
        )
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

private struct CategoryPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.body)
                .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.cyan : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}
