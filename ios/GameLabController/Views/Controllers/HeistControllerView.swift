import SwiftUI

/// Heist phone controller — completely different UI for Guard vs Thief.
struct HeistControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    private var role: HeistRole {
        (privateData["role"] as? String) == "guard" ? .guard : .thief
    }

    var body: some View {
        switch role {
        case .guard:
            GuardControllerView(privateData: privateData, onAction: onAction)
        case .thief:
            ThiefControllerView(privateData: privateData, onAction: onAction)
        }
    }
}

// MARK: - Guard Controller
// Guard sees camera positions on their phone and sets which cameras are active.
// This info is PRIVATE — thieves can't see it on the TV until reveal phase.

private struct GuardControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    @State private var activeCameras: Set<String> = []
    @State private var phase: HeistPhase = .guardSets
    @State private var hasSubmitted = false

    // Camera slots the guard can activate (positions on the grid)
    private var cameraSlots: [CameraSlot] {
        (privateData["cameraSlots"] as? [[String: Any]] ?? defaultCameraSlots)
            .compactMap { dict -> CameraSlot? in
                guard let id = dict["id"] as? String,
                      let label = dict["label"] as? String,
                      let dir = dict["direction"] as? String
                else { return nil }
                return CameraSlot(id: id, label: label, direction: dir)
            }
    }

    private var defaultCameraSlots: [[String: Any]] {
        [
            ["id": "cam_tl", "label": "Top Left",     "direction": "↘"],
            ["id": "cam_tr", "label": "Top Right",    "direction": "↙"],
            ["id": "cam_bl", "label": "Bottom Left",  "direction": "↗"],
            ["id": "cam_br", "label": "Bottom Right", "direction": "↖"],
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Role badge
            roleBadge

            Spacer()

            if phase == .guardSets {
                VStack(spacing: 28) {
                    Text("Choose cameras to activate")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))

                    Text("Activate up to 2")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))

                    // 2×2 camera grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(cameraSlots) { slot in
                            CameraToggleTile(
                                slot: slot,
                                isActive: activeCameras.contains(slot.id),
                                canActivate: activeCameras.count < 2 || activeCameras.contains(slot.id)
                            ) {
                                toggleCamera(slot.id)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Submit
                    Button(action: submitCameras) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                            Text(hasSubmitted ? "Cameras Set ✓" : "Lock Cameras")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(hasSubmitted ? Color.green.opacity(0.3) : Color.red.opacity(0.8))
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(hasSubmitted)
                    .padding(.horizontal, 24)
                }
            } else {
                // During thieves move phase, guard waits and sees coverage map
                VStack(spacing: 16) {
                    Text("📷 Cameras Active")
                        .font(.title3.bold())
                        .foregroundColor(.red)

                    Text("Watching for thieves…")
                        .foregroundColor(.white.opacity(0.5))

                    ForEach(cameraSlots.filter { activeCameras.contains($0.id) }) { slot in
                        HStack {
                            Text(slot.direction).font(.title2)
                            Text(slot.label)
                                .foregroundColor(.white)
                            Spacer()
                            Text("ACTIVE")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.15)))
                        .padding(.horizontal, 24)
                    }
                }
            }

            Spacer()
        }
        .background(Color(hex: "140000").ignoresSafeArea())
        .onAppear {
            if let p = privateData["phase"] as? String {
                phase = HeistPhase(rawValue: p) ?? .guardSets
            }
        }
    }

    private var roleBadge: some View {
        HStack(spacing: 12) {
            Text("🛡")
                .font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text("You are the Guard")
                    .font(.headline)
                    .foregroundColor(.red)
                Text("Only YOU can see camera positions")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(20)
        .background(Color.red.opacity(0.1))
    }

    private func toggleCamera(_ id: String) {
        if activeCameras.contains(id) {
            activeCameras.remove(id)
        } else if activeCameras.count < 2 {
            activeCameras.insert(id)
        }
    }

    private func submitCameras() {
        hasSubmitted = true
        onAction("set_cameras", ["cameras": Array(activeCameras)])
    }
}

// MARK: - Thief Controller
// Thief sees ONLY their position on a simplified map.
// They pick a direction to move each round.

private struct ThiefControllerView: View {
    let privateData: [String: Any]
    let onAction: (String, [String: Any]) -> Void

    @State private var hasMoved = false
    @State private var myPosition: GridPos = .init(col: 1, row: 1)
    @State private var thiefColor: Color = .cyan

    private var isMovingPhase: Bool {
        (privateData["phase"] as? String) == HeistPhase.thievesMove.rawValue
    }

    var body: some View {
        VStack(spacing: 0) {
            // Role badge
            roleBadge

            Spacer()

            VStack(spacing: 28) {
                // Mini position indicator
                HStack(spacing: 12) {
                    Text("Your position")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.subheadline)
                    Spacer()
                    Text("C\(myPosition.col) R\(myPosition.row)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 24)

                // Direction pad
                VStack(spacing: 12) {
                    DirectionButton(symbol: "arrow.up", label: "Up") {
                        move(direction: "up")
                    }
                    HStack(spacing: 40) {
                        DirectionButton(symbol: "arrow.left", label: "Left") {
                            move(direction: "left")
                        }
                        DirectionButton(symbol: "arrow.right", label: "Right") {
                            move(direction: "right")
                        }
                    }
                    DirectionButton(symbol: "arrow.down", label: "Down") {
                        move(direction: "down")
                    }
                }
                .opacity(isMovingPhase && !hasMoved ? 1 : 0.3)

                if hasMoved {
                    Label("Move sent — waiting for round to end", systemImage: "hourglass")
                        .font(.subheadline)
                        .foregroundColor(.cyan.opacity(0.7))
                } else if !isMovingPhase {
                    Label("Wait for the Guard to set cameras…", systemImage: "eye")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            // Tip: avoid lit tiles
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("Avoid tiles with camera arcs on the TV!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(hex: "000d14").ignoresSafeArea())
        .onAppear {
            if let col = privateData["col"] as? Int,
               let row = privateData["row"] as? Int {
                myPosition = GridPos(col: col, row: row)
            }
        }
    }

    private var roleBadge: some View {
        HStack(spacing: 12) {
            Text("🥷")
                .font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text("You are a Thief")
                    .font(.headline)
                    .foregroundColor(.cyan)
                Text("Reach the vault 💰 then escape 🚪")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(20)
        .background(Color.cyan.opacity(0.08))
    }

    private func move(direction: String) {
        guard isMovingPhase, !hasMoved else { return }
        hasMoved = true
        onAction("move", ["direction": direction])
    }
}

// MARK: - Subviews

private struct CameraToggleTile: View {
    let slot: CameraSlot
    let isActive: Bool
    let canActivate: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 10) {
                Text(slot.direction)
                    .font(.system(size: 36))
                Text(slot.label)
                    .font(.caption)
                    .foregroundColor(isActive ? .white : .white.opacity(0.5))
                    .multilineTextAlignment(.center)
                Text(isActive ? "ACTIVE" : "OFF")
                    .font(.caption2.bold())
                    .foregroundColor(isActive ? .red : .white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? Color.red.opacity(0.25) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isActive ? Color.red.opacity(0.6) : Color.white.opacity(0.08),
                                          lineWidth: isActive ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(canActivate ? 1 : 0.4)
        .disabled(!canActivate && !isActive)
        .scaleEffect(isActive ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

private struct DirectionButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .semibold))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 80)
            .background(
                Circle().fill(Color.white.opacity(0.1))
                    .overlay(Circle().strokeBorder(Color.cyan.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting types

private struct CameraSlot: Identifiable {
    let id: String
    let label: String
    let direction: String
}
