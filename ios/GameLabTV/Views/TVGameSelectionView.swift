import SwiftUI

struct TVGameSelectionView: View {
    let onSelect: (GameID) -> Void
    /// Starts a game with no phones at all — the Siri Remote is the controller.
    var onSelectSolo: ((GameID) -> Void)? = nil

    @State private var selectedCategory: GameCategory? = nil
    @FocusState private var focusedGame: GameID?
    @State private var hasAppeared = false
    @State private var isPulsing = false

    // Observed rather than read off the singleton, so the dot actually updates
    // when the connection drops.
    @ObservedObject private var socket = GameSocketManager.shared

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
                        selectCategory(nil)
                    }
                    ForEach(GameCategory.allCases, id: \.self) { cat in
                        CategoryPill(label: cat.rawValue, isSelected: selectedCategory == cat) {
                            selectCategory(selectedCategory == cat ? nil : cat)
                        }
                    }
                }

                Spacer()

                // Connection status dot — breathes gently while reconnecting
                // so the state reads as "actively retrying", not stuck.
                HStack(spacing: 8) {
                    Circle()
                        .fill(socket.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                        .opacity(socket.isConnected ? 1 : (isPulsing ? 1 : 0.3))
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                                isPulsing = true
                            }
                        }
                    Text(socket.isConnected ? "Server connected" : "Reconnecting…")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(width: 280)
            .padding(.vertical, 60)
            .padding(.leading, 60)
            // Gives the focus engine a clear boundary: moving right off the
            // last category jumps into the grid's own section below, rather
            // than the engine guessing at a target across two sibling stacks.
            .focusSection()

            // Right — game grid
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(260), spacing: 28), count: 4),
                    spacing: 28
                ) {
                    ForEach(displayedGames, id: \.self) { game in
                        // A real Button, not a plain VStack with .onTapGesture --
                        // .focusable() alone (the swipe-navigation fix) makes a
                        // view reachable by the remote, but a Select-button
                        // click on a custom focusable view isn't reliably
                        // delivered as a tap gesture on tvOS. Button is the
                        // primitive tvOS actually wires Select through, which
                        // is exactly why CategoryPill (already a Button)
                        // never had this problem. .buttonStyle(.plain) drops
                        // tvOS's own button chrome so TVGameCard's custom
                        // focus styling is what's actually seen.
                        Button {
                            pick(game)
                        } label: {
                            TVGameCard(game: game, isFocused: focusedGame == game)
                        }
                        .buttonStyle(.plain)
                        .focused($focusedGame, equals: game)
                        .onPlayPauseCommand { pick(game) }
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 60)
                .padding(.trailing, 60)
                .animation(.easeInOut(duration: 0.25), value: selectedCategory)
            }
            .focusSection()
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { hasAppeared = true }
        }
    }

    private func selectCategory(_ category: GameCategory?) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedCategory = category
        }
    }

    /// A solo-capable game starts immediately with no room code and no lobby;
    /// everything else goes through the normal join flow.
    private func pick(_ game: GameID) {
        if game.soloPlayable, let onSelectSolo {
            onSelectSolo(game)
        } else {
            onSelect(game)
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
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text("\(game.minPlayers)–\(game.maxPlayers) players")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .frame(width: 240, height: 200)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isFocused
                      ? Color.purple.opacity(0.4)
                      : Color.white.opacity(0.07))
                .shadow(color: isFocused ? .purple.opacity(0.6) : .clear, radius: 20)
        )
        // Small fixed-size icon badges pinned to a corner, entirely
        // independent of the text layout above -- unlike the previous
        // full-text Label row, these can never grow wider than the card and
        // spill past its rounded-rectangle background.
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 6) {
                if game.hasPrivateInfo {
                    GameBadge(systemImage: "eye.slash.fill", color: .cyan)
                }
                if game.supportsRemote {
                    GameBadge(systemImage: "av.remote.fill", color: .green)
                }
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

private struct GameBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(color.opacity(0.85)))
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
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
