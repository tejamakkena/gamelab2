"""Solo engines, all playable with the Siri Remote alone.

These accept the same ``game_action`` events as every other game -- the tvOS app
sends them on the player's behalf when the remote is used, so no separate input
path is needed on the server.
"""

import random
import time

from games.native_hub.engine import NativeGameEngine

DIRECTIONS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}


class NeonSnakeEngine(NativeGameEngine):
    """Classic snake on a 20x20 grid, driven by the remote's D-pad."""

    game_id = "neon_snake"
    min_players = 1
    max_players = 4
    tick_hz = 8.0            # the snake's step rate, not a render rate

    W = H = 20

    def __init__(self, room, broadcaster):
        super().__init__(room, broadcaster)
        self.snakes: dict[str, dict] = {}
        self.food: tuple = (10, 10)
        self._finished = False

    def start(self, players):
        for i, player in enumerate(players):
            start = (3 + i * 4, 10)
            self.snakes[player.id] = {
                "body": [start], "dir": (1, 0), "pending": (1, 0),
                "alive": True, "score": 0,
            }
        self._place_food()

    def _place_food(self):
        occupied = {cell for s in self.snakes.values() for cell in s["body"]}
        free = [(x, y) for x in range(self.W) for y in range(self.H)
                if (x, y) not in occupied]
        self.food = random.choice(free) if free else (0, 0)

    def handle_action(self, player_id, action, data):
        if action != "turn":
            return
        snake = self.snakes.get(player_id)
        if snake is None or not snake["alive"]:
            return
        vector = DIRECTIONS.get(data.get("direction"))
        if vector is None:
            return
        # Reversing straight into your own neck is an instant loss, so ignore it.
        if (vector[0] == -snake["dir"][0] and vector[1] == -snake["dir"][1]):
            return
        snake["pending"] = vector

    def tick(self, dt):
        if self._finished:
            return
        for snake in self.snakes.values():
            if not snake["alive"]:
                continue
            snake["dir"] = snake["pending"]
            head = snake["body"][0]
            nxt = (head[0] + snake["dir"][0], head[1] + snake["dir"][1])

            if not (0 <= nxt[0] < self.W and 0 <= nxt[1] < self.H):
                snake["alive"] = False
                continue
            if any(nxt in s["body"] for s in self.snakes.values()):
                snake["alive"] = False
                continue

            snake["body"].insert(0, nxt)
            if nxt == self.food:
                snake["score"] += 10
                self._place_food()
            else:
                snake["body"].pop()

        for pid, snake in self.snakes.items():
            player = self.room.player(pid)
            if player is not None:
                player.score = snake["score"]

        if not any(s["alive"] for s in self.snakes.values()):
            self._finished = True

    def public_state(self):
        return {
            "width": self.W, "height": self.H,
            "food": {"x": self.food[0], "y": self.food[1]},
            "snakes": [
                {"playerID": pid, "name": self.player_name(pid),
                 "body": [{"x": x, "y": y} for x, y in s["body"]],
                 "alive": s["alive"], "score": s["score"]}
                for pid, s in self.snakes.items()
            ],
            "finished": self._finished,
        }

    def private_state(self, player_id):
        snake = self.snakes.get(player_id, {})
        return {
            "alive": snake.get("alive", False),
            "score": snake.get("score", 0),
            "finished": self._finished,
            "controls": "dpad",
        }

    def is_over(self):
        return self._finished

    def results(self):
        return self.ranked_results({pid: s["score"] for pid, s in self.snakes.items()})


class Twenty48Engine(NativeGameEngine):
    """2048. The remote's touch surface swipes the tiles."""

    game_id = "twenty48"
    min_players = 1
    max_players = 4

    N = 4

    def __init__(self, room, broadcaster):
        super().__init__(room, broadcaster)
        self.boards: dict[str, list[int]] = {}
        self.scores: dict[str, int] = {}
        self.done: set[str] = set()
        self.best_tile: dict[str, int] = {}

    def start(self, players):
        for player in players:
            board = [0] * (self.N * self.N)
            self._spawn(board)
            self._spawn(board)
            self.boards[player.id] = board
            self.scores[player.id] = 0
            self.best_tile[player.id] = 2

    def _spawn(self, board):
        empty = [i for i, v in enumerate(board) if v == 0]
        if empty:
            board[random.choice(empty)] = 4 if random.random() < 0.1 else 2

    def _rows(self, board, direction):
        """Return the board as lists of indices, oriented so a merge is leftward."""
        n = self.N
        if direction == "left":
            return [[r * n + c for c in range(n)] for r in range(n)]
        if direction == "right":
            return [[r * n + c for c in reversed(range(n))] for r in range(n)]
        if direction == "up":
            return [[r * n + c for r in range(n)] for c in range(n)]
        return [[r * n + c for r in reversed(range(n))] for c in range(n)]

    def handle_action(self, player_id, action, data):
        if action != "swipe" or player_id in self.done:
            return
        direction = data.get("direction")
        if direction not in DIRECTIONS:
            return
        board = self.boards.get(player_id)
        if board is None:
            return

        moved = False
        gained = 0
        for line in self._rows(board, direction):
            values = [board[i] for i in line if board[i]]
            merged = []
            skip = False
            for i, value in enumerate(values):
                if skip:
                    skip = False
                    continue
                if i + 1 < len(values) and values[i + 1] == value:
                    merged.append(value * 2)
                    gained += value * 2
                    skip = True
                else:
                    merged.append(value)
            merged += [0] * (self.N - len(merged))
            for slot, cell in enumerate(line):
                if board[cell] != merged[slot]:
                    moved = True
                board[cell] = merged[slot]

        if not moved:
            return

        self.scores[player_id] += gained
        self.best_tile[player_id] = max(board) if board else 0
        player = self.room.player(player_id)
        if player is not None:
            player.score = self.scores[player_id]
        self._spawn(board)

        if not self._has_move(board):
            self.done.add(player_id)

    def _has_move(self, board):
        if any(v == 0 for v in board):
            return True
        n = self.N
        for r in range(n):
            for c in range(n):
                v = board[r * n + c]
                if c + 1 < n and board[r * n + c + 1] == v:
                    return True
                if r + 1 < n and board[(r + 1) * n + c] == v:
                    return True
        return False

    def public_state(self):
        return {
            "size": self.N,
            "boards": [
                {"playerID": pid, "name": self.player_name(pid), "tiles": board,
                 "score": self.scores.get(pid, 0), "best": self.best_tile.get(pid, 0),
                 "done": pid in self.done}
                for pid, board in self.boards.items()
            ],
            "finished": self.is_over(),
        }

    def private_state(self, player_id):
        return {
            "size": self.N,
            "tiles": self.boards.get(player_id, []),
            "score": self.scores.get(player_id, 0),
            "done": player_id in self.done,
            "controls": "swipe",
        }

    def is_over(self):
        return bool(self.boards) and len(self.done) >= len(self.boards)

    def results(self):
        return self.ranked_results(self.scores)


class BrickBreakerEngine(NativeGameEngine):
    """Paddle and bricks. Swipe the remote, or tilt a phone if one is connected."""

    game_id = "brick_breaker"
    min_players = 1
    max_players = 2
    tick_hz = 30.0
    heavy_state = True

    W, H = 100.0, 140.0
    PADDLE_W = 20.0
    COLS, ROWS = 8, 5
    LIVES = 3

    def __init__(self, room, broadcaster):
        super().__init__(room, broadcaster)
        self.bricks: list[dict] = []
        self.paddle = 50.0
        self.bx, self.by = 50.0, 100.0
        self.vx, self.vy = 30.0, -45.0
        self.lives = self.LIVES
        self.score = 0
        self._finished = False
        self.serve_at = 0.0

    def start(self, players):
        self.bricks = [
            {"id": r * self.COLS + c,
             "x": 4 + c * (self.W - 8) / self.COLS,
             "y": 12 + r * 7,
             "w": (self.W - 8) / self.COLS - 1.5,
             "h": 5.0,
             "alive": True}
            for r in range(self.ROWS) for c in range(self.COLS)
        ]
        self._serve()

    def _serve(self):
        self.bx, self.by = self.paddle, self.H - 16
        self.vx = random.uniform(-25, 25)
        self.vy = -45.0
        self.serve_at = time.time() + 1.0

    def handle_action(self, player_id, action, data):
        if action == "paddle":
            x = data.get("x")
            if isinstance(x, (int, float)):
                self.paddle = max(self.PADDLE_W / 2,
                                  min(self.W - self.PADDLE_W / 2, float(x)))

    def tick(self, dt):
        if self._finished or time.time() < self.serve_at:
            return
        dt = min(dt, 0.05)
        self.bx += self.vx * dt
        self.by += self.vy * dt

        if self.bx <= 1.5:
            self.bx, self.vx = 1.5, abs(self.vx)
        elif self.bx >= self.W - 1.5:
            self.bx, self.vx = self.W - 1.5, -abs(self.vx)
        if self.by <= 1.5:
            self.by, self.vy = 1.5, abs(self.vy)

        # Paddle
        if self.H - 12 <= self.by <= self.H - 8 and self.vy > 0:
            if abs(self.bx - self.paddle) <= self.PADDLE_W / 2:
                offset = (self.bx - self.paddle) / (self.PADDLE_W / 2)
                self.vx = offset * 45.0
                self.vy = -abs(self.vy)

        # Bricks
        for brick in self.bricks:
            if not brick["alive"]:
                continue
            if (brick["x"] <= self.bx <= brick["x"] + brick["w"]
                    and brick["y"] <= self.by <= brick["y"] + brick["h"]):
                brick["alive"] = False
                self.vy = -self.vy
                self.score += 10
                break

        if self.by > self.H:
            self.lives -= 1
            if self.lives <= 0:
                self._finished = True
            else:
                self._serve()

        if not any(b["alive"] for b in self.bricks):
            self.score += 200
            self._finished = True

        for player in self.room.players:
            player.score = self.score

    def public_state(self):
        return {
            "width": self.W, "height": self.H,
            "ball": {"x": round(self.bx, 1), "y": round(self.by, 1)},
            "paddle": round(self.paddle, 1),
            "paddleWidth": self.PADDLE_W,
            "bricks": [
                {"id": b["id"], "x": round(b["x"], 1), "y": round(b["y"], 1),
                 "w": round(b["w"], 1), "h": b["h"]}
                for b in self.bricks if b["alive"]
            ],
            "lives": self.lives, "score": self.score,
            "finished": self._finished,
        }

    def private_state(self, player_id):
        return {
            "score": self.score, "lives": self.lives,
            "finished": self._finished, "controls": "swipe",
            "width": self.W,
        }

    def is_over(self):
        return self._finished

    def results(self):
        return self.ranked_results({p.id: self.score for p in self.room.players})


class SimonSaysEngine(NativeGameEngine):
    """Repeat a growing four-colour sequence with the remote's D-pad."""

    game_id = "simon_says"
    min_players = 1
    max_players = 4

    PADS = ["up", "right", "down", "left"]
    SHOW_MS_PER_STEP = 700

    def __init__(self, room, broadcaster):
        super().__init__(room, broadcaster)
        self.sequence: list[str] = []
        self.order: list[str] = []
        self.turn_index = 0
        self.progress = 0
        self.phase = "show"
        self.phase_until = 0.0
        self.round = 0
        self._finished = False
        self.last_wrong: str | None = None

    def start(self, players):
        self.order = [p.id for p in players]
        self._next_round()

    def _next_round(self):
        self.sequence.append(random.choice(self.PADS))
        self.round = len(self.sequence)
        self.progress = 0
        self.phase = "show"
        self.phase_until = time.time() + len(self.sequence) * self.SHOW_MS_PER_STEP / 1000 + 0.5

    def current_player(self):
        return self.order[self.turn_index % len(self.order)] if self.order else None

    def handle_action(self, player_id, action, data):
        if self._finished or self.phase != "input":
            return
        if player_id != self.current_player():
            return
        if action != "pad":
            return
        pad = data.get("pad")
        if pad not in self.PADS:
            return

        if pad == self.sequence[self.progress]:
            self.progress += 1
            if self.progress >= len(self.sequence):
                player = self.room.player(player_id)
                if player is not None:
                    player.score += len(self.sequence) * 10
                # Pass the remote on in a group game.
                self.turn_index += 1
                self._next_round()
        else:
            self.last_wrong = player_id
            if len(self.order) <= 1:
                self._finished = True
            else:
                self.order.remove(player_id)
                if not self.order:
                    self._finished = True
                else:
                    self.turn_index %= len(self.order)
                    self.sequence = []
                    self._next_round()

    def tick(self, dt):
        if self._finished:
            return
        if self.phase == "show" and time.time() >= self.phase_until:
            self.phase = "input"
            self.phase_until = 0.0

    def public_state(self):
        return {
            "pads": self.PADS,
            "phase": self.phase,
            "round": self.round,
            # The sequence is only shown during the show phase -- it must not be
            # readable off the TV while the player is being tested.
            "sequence": self.sequence if self.phase == "show" else [],
            "progress": self.progress,
            "currentPlayerID": self.current_player(),
            "currentName": self.player_name(self.current_player()) if self.current_player() else "",
            "finished": self._finished,
            "players": [
                {"id": p.id, "name": p.name, "score": p.score,
                 "isOut": p.id not in self.order}
                for p in self.room.players
            ],
        }

    def private_state(self, player_id):
        return {
            "isMyTurn": player_id == self.current_player(),
            "phase": self.phase,
            "round": self.round,
            "progress": self.progress,
            "pads": self.PADS,
            "isOut": player_id not in self.order,
            "controls": "dpad",
        }

    def is_over(self):
        return self._finished

    def results(self):
        return self.ranked_results({p.id: p.score for p in self.room.players})


class AtlasEngine(NativeGameEngine):
    """Place-name chain: each answer starts with the last letter of the previous.

    Solo it is a race against the clock; with a group it passes around the room.
    """

    game_id = "atlas"
    min_players = 1
    max_players = 8

    TURN_SECONDS = 20

    def __init__(self, room, broadcaster):
        super().__init__(room, broadcaster)
        from games.native_hub.engines import _content as C
        self._content = C
        self.chain: list[dict] = []
        self.used: set[str] = set()
        self.letter = ""
        self.order: list[str] = []
        self.turn_index = 0
        self.deadline = 0.0
        self.alive: list[str] = []
        self._finished = False
        self.last_error = ""

    def start(self, players):
        seed = random.choice(self._content.ATLAS_SEEDS)
        self.chain = [{"place": seed, "playerID": None, "name": "Start"}]
        self.used = {seed.lower()}
        self.letter = seed[-1].upper()
        self.order = [p.id for p in players]
        self.alive = list(self.order)
        self.deadline = time.time() + self.TURN_SECONDS

    def current_player(self):
        if not self.alive:
            return None
        return self.alive[self.turn_index % len(self.alive)]

    def seconds_left(self):
        return max(0, int(round(self.deadline - time.time()))) if self.deadline else 0

    def handle_action(self, player_id, action, data):
        if self._finished or action != "answer":
            return
        if player_id != self.current_player():
            return
        place = str(data.get("place", "")).strip()
        key = place.lower()

        if not place:
            return
        if not place.upper().startswith(self.letter):
            self.last_error = f"Must start with {self.letter}"
            return
        if key in self.used:
            self.last_error = "Already used"
            return
        if key not in self._content.ATLAS_PLACES:
            self.last_error = "Not a known place"
            return

        self.used.add(key)
        self.chain.append({"place": place, "playerID": player_id,
                           "name": self.player_name(player_id)})
        self.letter = place[-1].upper()
        self.last_error = ""
        player = self.room.player(player_id)
        if player is not None:
            player.score += 10
        self._advance()

    def _advance(self):
        if self.alive:
            self.turn_index = (self.turn_index + 1) % len(self.alive)
        self.deadline = time.time() + self.TURN_SECONDS

    def tick(self, dt):
        if self._finished or not self.deadline:
            return
        if time.time() < self.deadline:
            return
        # Ran out of time: solo ends the run, group eliminates the player.
        loser = self.current_player()
        if len(self.alive) <= 1:
            self._finished = True
            return
        if loser in self.alive:
            self.alive.remove(loser)
        if len(self.alive) <= 1:
            self._finished = True
        else:
            self.turn_index %= len(self.alive)
            self.deadline = time.time() + self.TURN_SECONDS

    def public_state(self):
        return {
            "letter": self.letter,
            "chain": self.chain[-10:],
            "chainLength": len(self.chain) - 1,
            "secondsLeft": self.seconds_left(),
            "currentPlayerID": self.current_player(),
            "currentName": self.player_name(self.current_player()) if self.current_player() else "",
            "finished": self._finished,
            "players": [
                {"id": p.id, "name": p.name, "score": p.score,
                 "isOut": p.id not in self.alive}
                for p in self.room.players
            ],
        }

    def private_state(self, player_id):
        return {
            "letter": self.letter,
            "isMyTurn": player_id == self.current_player(),
            "secondsLeft": self.seconds_left(),
            "isOut": player_id not in self.alive,
            "error": self.last_error if player_id == self.current_player() else "",
            "lastPlace": self.chain[-1]["place"] if self.chain else "",
        }

    def is_over(self):
        return self._finished

    def results(self):
        return self.ranked_results({p.id: p.score for p in self.room.players})


ENGINES = {
    "neon_snake": NeonSnakeEngine,
    "twenty48": Twenty48Engine,
    "brick_breaker": BrickBreakerEngine,
    "simon_says": SimonSaysEngine,
    "atlas": AtlasEngine,
}
