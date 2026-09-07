import SwiftUI

struct TVGameSelectionView: View {
    let onSelect: (GameID) -> Void
    /// Starts a game with no phones at all — the Siri Remote is the controller.
    var onSelectSolo: ((GameID) -> Void)? = nil

    @State private var selectedCategory: GameCategory? = nil
    @FocusState private var focusedGame: GameID?
    @State private var hasAppeared = false
    @State private var isPulsing = false

    // Every soloPlayable game also supports more than one player (Neon
    // Snake, 2048, Simon Says: up to 4; Brick Breaker: up to 2; Atlas: up to
    // 8) -- picking one used to always start it solo immediately with no
    // way to invite anyone, despite the card's own "N–M players" caption
    // advertising otherwise. Reported directly: Neon Snake showed no room
    // code and no controller access at all, and Atlas -- whose only input
    // style is typed text -- had no way to answer, since AtlasControllerView
    // (the phone UI that types the answer) can never appear if no phone can
    // ever join. This prompt gives a real choice instead of assuming solo.
    @State private var soloChoiceGame: GameID? = nil

    // Gives the first game card a deterministic initial focus target instead
    // of leaving it to the focus engine's default first-focusable-view guess
    // (which would otherwise land on the "All" sidebar pill), so
    // GameLabTVUITests doesn't need to reproduce an exact D-pad navigation
    // sequence just to reach a card before pressing Select.
    //
    // Deliberately NOT using .prefersDefaultFocus(_:in:): the first attempt
    // at this used exactly that, and GameLabTVUITests' own first real CI run
    // showed Select/Play-Pause never reaching pick(_:) at all -- consistent
    // with a known tvOS gotcha where .prefersDefaultFocus racing a LazyVGrid's
    // own child layout can silently lose to whatever non-lazy view (here, the
    // sidebar's "All" pill) is already laid out by the time the focus engine
    // resolves an initial target. Setting the existing, already-working
    // $focusedGame binding directly (below, on .onAppear) sidesteps that
    // race entirely -- it's the same binding swipe navigation already uses
    // successfully, just assigned imperatively instead of declaratively.
    // GameLabTVUITests keeps its own defensive hasFocus check + Right-press
    // fallback regardless, so a future regression here fails loudly there
    // with a clear message instead of silently pressing the wrong element.

    // TEMPORARY diagnostic: four different Select-click mechanisms have each
    // been reported as "still doesn't do anything" on real hardware, with no
    // way from here to tell whether the input is reaching `pick(_:)` at all
    // or whether it fires but something after it (onSelect/onSelectSolo ->
    // the socket round-trip -> the screen transition) is what's silent. This
    // makes that unambiguous with a full-screen flash + label the instant
    // pick(_:) runs, before any of that downstream logic -- independent of
    // TVGameCard's own focus styling, which was a red herring earlier: a
    // Button's default focus chrome is a FOCUS effect, not proof a click
    // fired. Remove this whole block once the real cause is confirmed.
    //
    // #if DEBUG: this used to ship (unintentionally) into real TestFlight
    // builds -- a yellow full-screen banner is not something real users
    // should ever see. It's gated to DEBUG now that GameLabTVUITests exists
    // to answer the "does Select even fire pick(_:)" question automatically,
    // in a Simulator, on every PR -- which is the actual replacement for the
    // 15 rounds of manual on-device testing this was added for. DEBUG is
    // available here because local/CI Simulator builds (build-check, and the
    // new tv-ui-test job) default to the Debug configuration, while the real
    // TestFlight archive (deploy-tvos) explicitly passes
    // -configuration Release, which #if DEBUG excludes.
    #if DEBUG
    @State private var debugLastInput: String? = nil
    #endif

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
                        // Third attempt at this, so a full account of what
                        // was tried and why, confirmed from real on-device
                        // testing each time:
                        //   1. Plain VStack + .onTapGesture: swipe worked
                        //      (once .focusable() was added), but Select
                        //      never fired the tap at all.
                        //   2. Button + .buttonStyle(.plain): Select finally
                        //      registered, but tvOS drew its own default
                        //      focus/pressed "card" chrome underneath the
                        //      button regardless of style -- the stray white
                        //      rounded rectangle that was reported.
                        //   3. Plain VStack + .onLongPressGesture(minimumDuration: 0):
                        //      removed the white chrome, but on real
                        //      hardware Select stopped registering again --
                        //      apparently no more reliable than
                        //      .onTapGesture was for a non-Button view.
                        // (2) is the only one of the three that actually
                        // made Select fire reliably, so Button is right --
                        // what (2) needed was .focusEffectDisabled()
                        // (tvOS 17+, matches this app's deployment target),
                        // which turns off tvOS's own automatic focus
                        // rendering on a focusable element while leaving it
                        // fully interactive, so TVGameCard's own isFocused
                        // styling becomes the only visual effect again.
                        // .focusEffectDisabled() (attempt 4) turned out to be
                        // worse, not better: confirmed on real hardware that
                        // adding it made Select stop registering ANYTHING at
                        // all -- no visual change, nothing -- whereas plain
                        // Button + .buttonStyle(.plain) alone (attempt 2,
                        // reverted to here) is the one and only configuration
                        // out of four tried that has ever actually been
                        // confirmed on real hardware to register a click.
                        // Keeping the unwanted white focus-chrome for now
                        // (it's a real, separate, purely cosmetic tvOS quirk
                        // with .plain on some OS versions) rather than
                        // trading working functionality for a fix that
                        // doesn't work at all. A cosmetic fix belongs in its
                        // own follow-up once clicking is confirmed solid.
                        Button {
                            #if DEBUG
                            debugMark("Select", game)
                            #endif
                            pick(game)
                        } label: {
                            TVGameCard(game: game, isFocused: focusedGame == game)
                        }
                        .buttonStyle(.plain)
                        .focused($focusedGame, equals: game)
                        .accessibilityIdentifier("gameCard_\(game.rawValue)")
                        .onPlayPauseCommand {
                            #if DEBUG
                            debugMark("Play/Pause", game)
                            #endif
                            pick(game)
                        }
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
            // Imperatively assign initial focus onto the first card, on the
            // same $focusedGame binding swipe navigation already uses
            // successfully -- see this property's own doc comment for why
            // this replaced .prefersDefaultFocus(_:in:).
            if focusedGame == nil {
                focusedGame = displayedGames.first
            }
        }
        // TEMPORARY diagnostic overlay -- see debugLastInput's declaration.
        // Impossible to miss: a full-screen flash naming exactly which input
        // fired and for which game, the instant it fires, before anything
        // else runs. If this never appears no matter what's pressed, the
        // remote's input truly never reaches this view at all -- if it does
        // appear but the screen never advances past this one, the bug is
        // downstream in pick(_:)/onSelect/onSelectSolo or the server
        // round-trip, not the button/gesture mechanism this has been
        // chasing across four prior attempts.
        //
        // #if DEBUG (see debugLastInput's declaration for why): GameLabTVUITests
        // reads this Text's accessibilityIdentifier ("debugLastInput") and its
        // label to assert Select/Play-Pause actually reached pick(_:), in a
        // tvOS Simulator, on every PR -- automating the exact check this
        // banner used to require a human with a real Apple TV for.
        #if DEBUG
        .overlay {
            if let debugLastInput {
                Text(debugLastInput)
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundColor(.black)
                    .padding(40)
                    .background(Color.yellow)
                    .accessibilityIdentifier("debugLastInput")
                    .transition(.opacity)
            }
        }
        #endif
        .confirmationDialog(
            "How do you want to play?",
            isPresented: Binding(
                get: { soloChoiceGame != nil },
                set: { if !$0 { soloChoiceGame = nil } }
            ),
            titleVisibility: .visible,
            presenting: soloChoiceGame
        ) { game in
            Button("Play Solo Now") {
                soloChoiceGame = nil
                onSelectSolo?(game)
            }
            Button("Invite Friends") {
                soloChoiceGame = nil
                onSelect(game)
            }
            Button("Cancel", role: .cancel) { soloChoiceGame = nil }
        } message: { game in
            Text("Play \(game.displayName) alone with the Siri Remote, or get a room code so up to \(game.maxPlayers) friends can join on their phones.")
        }
    }

    #if DEBUG
    private func debugMark(_ source: String, _ game: GameID) {
        withAnimation(.easeIn(duration: 0.05)) {
            debugLastInput = "\(source) fired: \(game.rawValue)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) { debugLastInput = nil }
        }
    }
    #endif

    private func selectCategory(_ category: GameCategory?) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedCategory = category
        }
    }

    /// A solo-capable game prompts for Solo vs. Invite Friends (see
    /// soloChoiceGame's own doc comment); everything else goes straight
    /// through the normal join flow. Falls back to the normal flow too when
    /// no solo path was even wired up by the caller.
    private func pick(_ game: GameID) {
        guard game.soloPlayable, onSelectSolo != nil else {
            onSelect(game)
            return
        }
        soloChoiceGame = game
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
