# GameLab iOS + Apple TV

**Phone = Controller. TV = Board.**

## Project Structure

```
ios/
├── Package.swift              — SPM package (shared library + SocketIO dep)
├── Shared/                    — Code used by both apps
│   ├── Constants.swift        — Server URL, device ID, Color(hex:)
│   ├── Models/
│   │   ├── Game.swift         — GameID enum (all 17 games + 5 invented)
│   │   └── Room.swift         — Room, Player, RoomState models
│   └── Networking/
│       ├── SocketManager.swift  — Singleton Socket.IO client
│       └── GameMessage.swift    — All event names + payload types
│
├── GameLabTV/                 — tvOS app (the board on your TV)
│   ├── App/
│   │   ├── GameLabTVApp.swift
│   │   └── RootTVView.swift   — Screen router + TVRootViewModel
│   └── Views/
│       ├── TVGameSelectionView.swift  — Netflix-style game picker
│       ├── TVLobbyView.swift          — Room code + player list
│       ├── TVGameBoardView.swift      — Routes to per-game board
│       └── Games/
│           ├── TVHeistBoardView.swift   — Full Heist board (invented game)
│           └── TVTriviaBoardView.swift  — Trivia board
│
└── GameLabController/         — iOS app (the controller on your phone)
    ├── App/
    │   ├── GameLabControllerApp.swift
    │   └── RootControllerView.swift  — Screen router + ControllerRootViewModel
    └── Views/
        ├── JoinRoomView.swift    — Enter room code shown on TV
        ├── WaitingView.swift     — Lobby waiting room
        └── Controllers/
            ├── ControllerGameView.swift        — Routes to per-game controller
            ├── HeistControllerView.swift       — Guard (cameras) / Thief (D-pad)
            ├── TriviaControllerView.swift      — Answer tap buttons
            └── OtherControllerViews.swift      — Poker, Pong tilt, Snake shake,
                                                  MindMeld, HotGrid, StockPanic,
                                                  SpeedSculptor, Tambola, fallback
```

## Xcode Setup

1. Open Xcode → **Create a new Xcode project**
2. Create **two targets**:
   - `GameLabTV` — tvOS App
   - `GameLabController` — iOS App
3. Add the Swift files from each folder to their respective targets
4. Add `Shared/` files to both targets
5. In each target's Package Dependencies, add:
   ```
   https://github.com/socketio/socket.io-client-swift  (≥ 16.0.0)
   ```
6. In `Shared/Constants.swift` set `serverURL` to your Flask server's address

## How It Works

```
TV App                          Flask Server (existing)        Phone App
───────────────────────────────────────────────────────────────────────────
Create room (game selected) ──> assigns room code
Display room code + QR ─────────────────────────────────────── Enter code
                               player joins room <──────────── JoinRoom
Room updated (player list) <── broadcast room state
[Host presses Start] ────────> start_game event
                               assigns roles (Heist: 1 guard)
game_state broadcast ──────────────────────────────────────── (TV board)
                               private_state per player <───── (phone only)
Player action ──────────────────────────────── onAction("move", ...) ──>
                               validates + updates state
game_state broadcast ──────────────────────────────────────── (TV updates)
```

## Invented Games (phone-first design)

| Game | Why phone-as-controller shines |
|---|---|
| **Heist** | Guard's camera positions are secret (phone only). Thieves see only their own tile. TV shows the full vault — pure asymmetric information. |
| **Stock Panic** | Portfolio is private (phone). TV shows only prices + news events. |
| **Mind Meld** | Everyone types simultaneously in secret. TV reveals all at once. |
| **Hot Grid** | Phone picks a hidden tile; TV reveals what was underneath. |
| **Speed Sculptor** | Phone is the drawing canvas. TV shows all drawings side by side for voting. |

## Server Changes Needed

Add these Socket.IO events to the Flask backend (minimal additions):

```python
# In each game's socket_events.py:
@socketio.on('create_room')
def on_create_room(data):
    # generate room code, store game state, emit room_joined

@socketio.on('join_room')
def on_join_room(data):
    # add player, broadcast room_updated

@socketio.on('game_action')
def on_game_action(data):
    # validate, update game state
    # emit game_state to room (TV sees it)
    # emit private_state to specific player (phone sees it)
```

The existing Flask-SocketIO setup already supports all of this.
