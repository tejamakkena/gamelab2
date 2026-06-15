import SwiftUI

/// Displayed on TV while players join via their phones.
struct TVLobbyView: View {
    let room: Room
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 80) {
            // Left — room code + QR
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Join on your phone")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))

                    Text(room.code)
                        .font(.system(size: 96, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .kerning(12)

                    Text("gamelab.app  •  Enter code above")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.4))
                }

                // Animated pulse ring around code
                ZStack {
                    Circle()
                        .stroke(Color.purple.opacity(0.2), lineWidth: 2)
                        .frame(width: 220, height: 220)
                    Circle()
                        .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                        .frame(width: 270, height: 270)
                        .scaleEffect(1.05)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: true)

                    Text(room.gameID.emoji)
                        .font(.system(size: 80))
                }
            }
            .frame(maxWidth: 520)

            // Right — player list + start
            VStack(alignment: .leading, spacing: 24) {
                Text(room.gameID.displayName)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)

                Text("\(room.players.count) / \(room.gameID.maxPlayers) players")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.5))

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(room.players) { player in
                            PlayerRow(player: player)
                        }
                        // Empty slots
                        ForEach(room.players.count..<room.gameID.maxPlayers, id: \.self) { _ in
                            EmptySlotRow()
                        }
                    }
                }

                Spacer()

                let canStart = room.players.count >= room.gameID.minPlayers
                Button(action: onStart) {
                    Label(canStart ? "Start Game" : "Waiting for \(room.gameID.minPlayers - room.players.count) more…",
                          systemImage: canStart ? "play.fill" : "hourglass")
                        .font(.title3.bold())
                        .foregroundColor(canStart ? .black : .white.opacity(0.4))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(canStart ? Color.cyan : Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canStart)
            }
            .frame(maxWidth: 520)
        }
        .padding(80)
    }
}

private struct PlayerRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.purple.opacity(0.4))
                .frame(width: 40, height: 40)
                .overlay(Text(String(player.name.prefix(1))).foregroundColor(.white))

            Text(player.name)
                .foregroundColor(.white)
                .font(.body)

            if player.isHost { Text("HOST").font(.caption2).foregroundColor(.cyan) }

            Spacer()

            Image(systemName: player.isReady ? "checkmark.circle.fill" : "circle")
                .foregroundColor(player.isReady ? .green : .white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }
}

private struct EmptySlotRow: View {
    var body: some View {
        HStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1, antialiased: true)
                .frame(width: 40, height: 40)
            Text("Waiting…")
                .foregroundColor(.white.opacity(0.2))
                .font(.body)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }
}
