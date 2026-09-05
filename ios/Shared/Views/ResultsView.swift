import SwiftUI

// Both apps show a results screen at the end of a game, so this lives in
// Shared/ rather than either target's own folder — GameLabTV's RootTVView
// needs it, but it was previously declared inside the Controller target's
// OtherControllerViews.swift, which meant the TV target could never see it.

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
