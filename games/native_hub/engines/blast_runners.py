"""Blast Runners -- a 25-level co-op grid dungeon-crawler, no browser backend
to port from (a brand-new original concept, unlike most of this hub's other
engines). Built directly from the design brief:

* Top-down grid dungeon: every interior tile is either open floor or
  breakable rock -- never a permanent interior obstacle -- so every level is
  solvable by construction (worst case: blast through everything). Only the
  outer border is permanent wall.
* 25 escalating levels: five hand-authored "landmark" levels (5, 10, 15, 20,
  25) plus twenty procedurally generated ones, each level's procedural layout
  seeded deterministically off its own level number so replays and tests see
  the exact same grid every time.
* A shared team life pool, not per-player lives -- the whole point of this
  game existing. A hit costs the room one shared life and puts that specific
  player into a short "respawning" state; nobody is ever ejected from the
  room, and the group is never sent back past the start of its *current*
  level, let alone back to level 1.

See ``games/native_hub/engines/legacy_new.py``'s ``HeistEngine`` (grid
movement, phases) and ``games/native_hub/engines/solo.py``'s
``NeonSnakeEngine`` (tick-based stepping) for this hub's house style; this
engine borrows the "move is an instant action, tick only advances
time-driven state" split from Heist rather than Neon Snake's buffered-turn
model, since a dungeon crawl has no "instant death by reversing into
yourself" rule to guard against.
"""

import copy
import random
import time

from games.native_hub.engine import NativeGameEngine

# ---------------------------------------------------------------------------
# Tile alphabet
# ---------------------------------------------------------------------------
#
# '#' permanent border wall (outer ring only -- never appears in the interior)
# 'R' breakable rock (a `blast` turns this into '.')
# '.' open floor

WALL = "#"
ROCK = "R"
FLOOR = "."

DIRECTIONS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}
REVERSE_DIRECTIONS = {v: k for k, v in DIRECTIONS.items()}

MAX_LEVEL = 25

# Timings. All in seconds -- kept as named constants so the numbers in
# handle_action/tick read as intentional rather than magic.
BLAST_COOLDOWN = 0.4
RESPAWN_SECONDS = 2.0
INVULN_SECONDS = 1.5
BANNER_SECONDS = 2.5             # levelComplete / levelFailed beat before advancing/resetting
TURRET_FIRE_INTERVAL = 2.5
ENEMY_STEP_INTERVAL = 0.45       # one patroller/chaser step every ~0.45s
PROJECTILE_STEP_INTERVAL = 0.15  # projectiles travel faster than enemies walk
LIVES_PER_PLAYER = 3


# ---------------------------------------------------------------------------
# Level generation
# ---------------------------------------------------------------------------


def _level_size(level: int) -> int:
    """8x8 at level 1 growing to 14x14 at level 25, smoothly and deterministically."""
    return 8 + ((level - 1) * 6) // (MAX_LEVEL - 1)


def _gem_count_for(size: int, available: int) -> int:
    target = max(3, 4 + (size - 8))
    return max(1, min(target, available)) if available else 0


def _enemy_count_for(level: int) -> int:
    return 1 + ((level - 1) * 5) // (MAX_LEVEL - 1)


def _enemy_type_for(level: int, rng: random.Random) -> str:
    """Patrollers-only early on; chasers join mid-game; turrets join late.

    No real pathfinding for any of these -- see the engine's `_step_*`
    helpers for the actual (deliberately simple) movement rules.
    """
    if level <= 8:
        return "patroller"
    if level <= 16:
        return rng.choices(["patroller", "chaser"], weights=[60, 40])[0]
    return rng.choices(["patroller", "chaser", "turret"], weights=[40, 35, 25])[0]


def _generate_procedural_level(level: int) -> dict:
    """A level whose interior is random but reproducible -- ``random.Random(level)``
    means the exact same grid/gems/enemies come back for this level number on
    every call, in this process or any other.
    """
    rng = random.Random(level)
    size = _level_size(level)
    w = h = size

    tiles = [[WALL] * w for _ in range(h)]
    density = min(0.5, 0.28 + 0.008 * (level - 1))
    for r in range(1, h - 1):
        for c in range(1, w - 1):
            tiles[r][c] = ROCK if rng.random() < density else FLOOR

    spawn = (1, 1)
    exit_pos = (w - 2, h - 2)
    tiles[spawn[1]][spawn[0]] = FLOOR
    tiles[exit_pos[1]][exit_pos[0]] = FLOOR
    # A little breathing room around spawn so a fresh respawn doesn't land
    # face-first into a rock wall.
    for dc, dr in DIRECTIONS.values():
        nc, nr = spawn[0] + dc, spawn[1] + dr
        if 0 < nc < w - 1 and 0 < nr < h - 1:
            tiles[nr][nc] = FLOOR

    floor_cells = [
        (c, r) for r in range(1, h - 1) for c in range(1, w - 1)
        if tiles[r][c] == FLOOR and (c, r) not in (spawn, exit_pos)
    ]
    rng.shuffle(floor_cells)

    gem_count = _gem_count_for(size, len(floor_cells))
    gems = floor_cells[:gem_count]
    remaining = floor_cells[gem_count:]

    enemy_count = min(_enemy_count_for(level), len(remaining))
    enemies = []
    for c, r in remaining[:enemy_count]:
        etype = _enemy_type_for(level, rng)
        edef = {"type": etype, "col": c, "row": r}
        if etype == "patroller":
            edef["dir"] = rng.choice(["up", "down", "left", "right"])
        enemies.append(edef)

    return {
        "tiles": ["".join(row) for row in tiles],
        "gems": [list(g) for g in gems],
        "exit_pos": list(exit_pos),
        "spawn_pos": list(spawn),
        "enemies": enemies,
    }


# ---------------------------------------------------------------------------
# Hand-authored landmark levels -- 5, 10, 15, 20, 25.
#
# Every interior tile is still only 'R' or '.' (the "no permanent interior
# obstacle" rule applies here too), but these are laid out by hand as real
# little dungeons -- corridors, chokepoint doorways, distinct rooms -- rather
# than random noise, since these five are this run's pacing beats.
# ---------------------------------------------------------------------------

# Level 5 (9x9) -- "The Pinwheel": four rock-walled corner chambers around a
# plus-shaped corridor, each chamber gem-baited and reachable either by
# walking the corridor around it or blasting straight through its wall.
_LEVEL_5_TILES = [
    "#########",
    "#...R...#",
    "#.R...R.#",
    "#.RR.RR.#",
    "#R.R.R.R#",
    "#.RR.RR.#",
    "#.R...R.#",
    "#...R...#",
    "#########",
]
LEVEL_5 = {
    "tiles": _LEVEL_5_TILES,
    "gems": [[3, 1], [5, 1], [4, 3], [4, 5], [3, 7], [5, 7]],
    "exit_pos": [7, 7],
    "spawn_pos": [1, 1],
    "enemies": [
        {"type": "patroller", "col": 2, "row": 1, "dir": "right"},
        {"type": "patroller", "col": 6, "row": 7, "dir": "left"},
    ],
}

# Level 10 (10x10) -- "The Vault": a rock-ringed central chamber (the level's
# gem hoard) with four single-tile doorways, orbited by an open ring
# corridor. Patrollers walk the ring; the vault itself must be earned by
# blasting a doorway or walking one of the four gaps.
_LEVEL_10_TILES = [
    "##########",
    "#........#",
    "#.RRRRRR.#",
    "#.R....R.#",
    "#.R.RR.R.#",
    "#.R.RR.R.#",
    "#.R....R.#",
    "#.RRRRRR.#",
    "#........#",
    "##########",
]
LEVEL_10 = {
    "tiles": _LEVEL_10_TILES,
    # The original list here put a gem on [1, 1] and another on [8, 8] --
    # exactly the spawn and exit tiles. A gem only gets collected by moving
    # *onto* its tile, so a gem sitting under a player's own starting
    # position could never be picked up through ordinary play (you'd have
    # to realize you should step off your own spawn and back onto it),
    # and one squatting on the exit meant the exit could never be reached
    # "clean" without it happening to double as the last pickup. Moved
    # both to distinct floor tiles in the ring corridor instead.
    "gems": [[4, 3], [5, 3], [4, 6], [5, 6], [8, 1], [2, 8]],
    "exit_pos": [8, 8],
    "spawn_pos": [1, 1],
    "enemies": [
        {"type": "patroller", "col": 2, "row": 1, "dir": "right"},
        {"type": "patroller", "col": 7, "row": 8, "dir": "left"},
        {"type": "chaser", "col": 5, "row": 1, "dir": "down"},
    ],
}

# Level 15 (11x11) -- "The Spiral": a single winding rock spiral corridor
# from the outer ring in to a central gem chamber, so the natural walking
# path is a corkscrew even though blasting can always cut it short.
_LEVEL_15_TILES = [
    "###########",
    "#.........#",
    "#.RRRRRRR.#",
    "#.R.....R.#",
    "#.R.RRR.R.#",
    "#.R.R.R.R.#",
    "#.R.R...R.#",
    "#.R.RRRRR.#",
    "#.R.......#",
    "#.RRRRRRR.#",
    "###########",
]
LEVEL_15 = {
    "tiles": _LEVEL_15_TILES,
    "gems": [[5, 5], [3, 3], [7, 3], [3, 8], [7, 6], [9, 1]],
    "exit_pos": [9, 8],
    "spawn_pos": [1, 1],
    "enemies": [
        {"type": "patroller", "col": 3, "row": 1, "dir": "right"},
        {"type": "patroller", "col": 8, "row": 8, "dir": "left"},
        {"type": "chaser", "col": 5, "row": 3, "dir": "down"},
        {"type": "chaser", "col": 3, "row": 6, "dir": "right"},
    ],
}

# Level 20 (12x12) -- "The Gauntlet": a long zigzag corridor with turret
# nooks covering its straightaways, plus two side chambers off the main run.
_LEVEL_20_TILES = [
    "############",
    "#..........#",
    "#.RRRRRRRR.#",
    "#.R......R.#",
    "#.R.RRRR.R.#",
    "#.R.R..R.R.#",
    "#.R.R..R.R.#",
    "#.R.RRRR.R.#",
    "#.R......R.#",
    "#.RRRRRRRR.#",
    "#..........#",
    "############",
]
LEVEL_20 = {
    "tiles": _LEVEL_20_TILES,
    "gems": [[5, 5], [6, 5], [5, 6], [6, 6], [1, 10], [10, 1], [3, 3], [8, 8]],
    "exit_pos": [10, 10],
    "spawn_pos": [1, 1],
    "enemies": [
        {"type": "patroller", "col": 3, "row": 1, "dir": "right"},
        {"type": "patroller", "col": 8, "row": 10, "dir": "left"},
        {"type": "chaser", "col": 3, "row": 8, "dir": "up"},
        {"type": "chaser", "col": 8, "row": 3, "dir": "down"},
        {"type": "turret", "col": 5, "row": 1, "dir": "down"},
        {"type": "turret", "col": 6, "row": 10, "dir": "up"},
    ],
}

# Level 25 (14x14) -- "The Last Vault": the finale. A grand ring corridor
# with turret watchtowers at the cardinal midpoints, guarding a large
# central rock fortress with the level's biggest gem hoard and the exit set
# just outside its far doorway -- reaching it means fighting all the way
# across the room, not sneaking around the edge.
_LEVEL_25_TILES = [
    "##############",
    "#............#",
    "#.RRRRRRRRRR.#",
    "#.R........R.#",
    "#.R.RRRRRR.R.#",
    "#.R.R....R.R.#",
    "#.R.R....R.R.#",
    "#.R.R....R.R.#",
    "#.R.R....R.R.#",
    "#.R.RRRRRR.R.#",
    "#.R........R.#",
    "#.RRRRRRRRRR.#",
    "#............#",
    "##############",
]
LEVEL_25 = {
    "tiles": _LEVEL_25_TILES,
    # Same fix as Level 10: this used to put a gem directly on the spawn
    # tile [1, 1] and another directly on the exit tile [12, 12], neither
    # of which can be collected by ordinary "walk onto a gem" play. Moved
    # both to distinct floor tiles in the outer ring.
    "gems": [
        [6, 6], [7, 6], [6, 7], [7, 7],
        [3, 3], [10, 3], [3, 10], [10, 10],
        [9, 1], [4, 12], [1, 12], [12, 1],
    ],
    "exit_pos": [12, 12],
    "spawn_pos": [1, 1],
    "enemies": [
        {"type": "patroller", "col": 3, "row": 1, "dir": "right"},
        {"type": "patroller", "col": 10, "row": 12, "dir": "left"},
        {"type": "patroller", "col": 1, "row": 7, "dir": "down"},
        {"type": "chaser", "col": 3, "row": 4, "dir": "down"},
        {"type": "chaser", "col": 10, "row": 9, "dir": "up"},
        {"type": "turret", "col": 7, "row": 1, "dir": "down"},
        {"type": "turret", "col": 6, "row": 12, "dir": "up"},
        {"type": "turret", "col": 12, "row": 7, "dir": "left"},
    ],
}

AUTHORED_LEVELS = {5: LEVEL_5, 10: LEVEL_10, 15: LEVEL_15, 20: LEVEL_20, 25: LEVEL_25}


def generate_level(level: int) -> dict:
    """Full level spec for any level number 1-25.

    ``{tiles, gems, exit_pos, spawn_pos, enemies}`` -- a deep copy every time,
    so the engine is always free to mutate the returned tiles/gems without
    corrupting the hand-authored template for the next time this level loads.
    """
    if level in AUTHORED_LEVELS:
        return copy.deepcopy(AUTHORED_LEVELS[level])
    return _generate_procedural_level(level)


# ---------------------------------------------------------------------------
# Engine
# ---------------------------------------------------------------------------


class BlastRunnersEngine(NativeGameEngine):
    """25-level co-op dungeon crawl with one shared team life pool.

    Movement is an instant reaction to a ``move`` action (like Heist's thief
    movement), not buffered to a tick boundary (like Neon Snake's turning) --
    there is no "can't reverse into yourself" rule here to protect against,
    so there is nothing to gain from delaying a move to the next tick.
    ``tick()`` only advances time-driven state: enemy/projectile stepping,
    turret firing, respawn timers, and the levelComplete/levelFailed banner
    beats.
    """

    game_id = "blast_runners"
    min_players = 1
    max_players = 4
    tick_hz = 8.0

    def __init__(self, room, broadcaster):
        super().__init__(room, broadcaster)
        self.level = 1
        self.levels_cleared = 0
        self.width = 0
        self.height = 0
        self.tiles: list[list[str]] = []
        self.gems: set[tuple[int, int]] = set()
        self.total_gems = 0
        self.exit_pos: tuple[int, int] = (0, 0)
        self.exit_unlocked = False
        self.spawn_pos: tuple[int, int] = (0, 0)
        self.enemies: dict[str, dict] = {}
        self.projectiles: list[dict] = []
        self.players: dict[str, dict] = {}
        self.last_blast: dict[str, float] = {}
        self.lives_current = 0
        self.lives_max = 0
        self.phase = "playing"
        self.phase_until = 0.0
        self._enemy_accum = 0.0
        self._proj_accum = 0.0
        self._finished = False
        # Set on every `blast` action regardless of what it hit (rock, an
        # enemy, or nothing) so the TV can trigger a one-shot visual burst at
        # that tile purely by noticing this timestamp changed, without the
        # client having to infer "a blast just happened here" from a tile
        # diff (which says nothing when a blast only removes an enemy).
        self.last_blast_fx: dict | None = None

    # ---- lifecycle ----------------------------------------------------

    def start(self, players):
        self.players = {
            p.id: {"col": 0, "row": 0, "facing": "down", "alive": True,
                   "invuln_until": 0.0, "respawn_at": 0.0}
            for p in players
        }
        self.last_blast = {}
        self.level = 1
        self.levels_cleared = 0
        self._finished = False
        self._start_level(self.level, refill_lives=True)

    def on_player_join(self, player):
        if player.id in self.players:
            return
        now = time.time()
        self.players[player.id] = {
            "col": self.spawn_pos[0], "row": self.spawn_pos[1], "facing": "down",
            "alive": True, "invuln_until": now + INVULN_SECONDS, "respawn_at": 0.0,
        }

    def _start_level(self, level_number: int, refill_lives: bool) -> None:
        spec = generate_level(level_number)
        self.tiles = [list(row) for row in spec["tiles"]]
        self.height = len(self.tiles)
        self.width = len(self.tiles[0]) if self.tiles else 0
        self.gems = {tuple(g) for g in spec["gems"]}
        self.total_gems = len(self.gems)
        self.exit_pos = tuple(spec["exit_pos"])
        self.exit_unlocked = False
        self.spawn_pos = tuple(spec["spawn_pos"])

        self.enemies = {}
        for i, edef in enumerate(spec["enemies"]):
            entry = {"type": edef["type"], "col": edef["col"], "row": edef["row"]}
            if edef["type"] == "patroller":
                entry["dir"] = DIRECTIONS[edef.get("dir", "right")]
            elif edef["type"] == "turret":
                entry["next_fire_at"] = time.time() + random.uniform(0.5, TURRET_FIRE_INTERVAL)
            self.enemies[f"e{i}"] = entry
        self.projectiles = []
        self._enemy_accum = 0.0
        self._proj_accum = 0.0

        if refill_lives:
            connected = max(1, len(self.room.connected_players()))
            self.lives_max = LIVES_PER_PLAYER * connected
            self.lives_current = self.lives_max

        now = time.time()
        for state in self.players.values():
            state["col"], state["row"] = self.spawn_pos
            state["alive"] = True
            state["invuln_until"] = now + INVULN_SECONDS
            state["respawn_at"] = 0.0

        self.phase = "playing"
        self.phase_until = 0.0
        self.last_blast_fx = None

    # ---- actions --------------------------------------------------------

    def handle_action(self, player_id, action, data):
        if self._finished or self.phase != "playing":
            return
        state = self.players.get(player_id)
        if state is None or not state["alive"]:
            return

        if action == "move":
            vector = DIRECTIONS.get(data.get("direction"))
            if vector is None:
                return
            state["facing"] = data["direction"]
            nc, nr = state["col"] + vector[0], state["row"] + vector[1]
            if not self._is_floor(nc, nr):
                return
            state["col"], state["row"] = nc, nr
            self._collect_gem_if_present(nc, nr)
            self._apply_hit_if_colliding(player_id)

        elif action == "blast":
            now = time.time()
            if now - self.last_blast.get(player_id, 0.0) < BLAST_COOLDOWN:
                return
            self.last_blast[player_id] = now
            dc, dr = DIRECTIONS.get(state["facing"], (0, 1))
            tc, tr = state["col"] + dc, state["row"] + dr
            if not (0 <= tc < self.width and 0 <= tr < self.height):
                return
            self.last_blast_fx = {"col": tc, "row": tr, "at": now}
            if self.tiles[tr][tc] == ROCK:
                self.tiles[tr][tc] = FLOOR
            for eid in [eid for eid, e in self.enemies.items() if e["col"] == tc and e["row"] == tr]:
                del self.enemies[eid]

    def _is_floor(self, col: int, row: int) -> bool:
        return 0 <= col < self.width and 0 <= row < self.height and self.tiles[row][col] == FLOOR

    def _collect_gem_if_present(self, col: int, row: int) -> None:
        pos = (col, row)
        if pos in self.gems:
            self.gems.discard(pos)
            if not self.gems:
                self.exit_unlocked = True

    # ---- tick -------------------------------------------------------------

    def tick(self, dt):
        if self._finished:
            return
        now = time.time()

        if self.phase == "playing":
            self._step_enemies(dt)
            self._step_projectiles(dt)
            self._fire_turrets(now)
            self._process_respawns(now)
            for pid in list(self.players):
                self._apply_hit_if_colliding(pid)
            self._check_win()
        elif self.phase == "levelFailed":
            if now >= self.phase_until:
                self._start_level(self.level, refill_lives=True)
        elif self.phase == "levelComplete":
            if now >= self.phase_until:
                if self.level >= MAX_LEVEL:
                    self.phase = "gameComplete"
                    self._finished = True
                else:
                    self.level += 1
                    self._start_level(self.level, refill_lives=True)

    def _process_respawns(self, now: float) -> None:
        for state in self.players.values():
            if not state["alive"] and now >= state["respawn_at"]:
                state["col"], state["row"] = self.spawn_pos
                state["alive"] = True
                state["invuln_until"] = now + INVULN_SECONDS

    def _apply_hit_if_colliding(self, player_id: str) -> None:
        state = self.players.get(player_id)
        if state is None or not state["alive"] or self.phase != "playing":
            return
        if time.time() < state["invuln_until"]:
            return
        col, row = state["col"], state["row"]
        hit = (any(e["col"] == col and e["row"] == row for e in self.enemies.values())
               or any(p["col"] == col and p["row"] == row for p in self.projectiles))
        if hit:
            self._lose_life(player_id)

    def _lose_life(self, player_id: str) -> None:
        self.lives_current = max(0, self.lives_current - 1)
        state = self.players[player_id]
        state["alive"] = False
        state["respawn_at"] = time.time() + RESPAWN_SECONDS
        if self.lives_current <= 0:
            self.phase = "levelFailed"
            self.phase_until = time.time() + BANNER_SECONDS

    def _check_win(self) -> None:
        if self.phase != "playing" or not self.exit_unlocked:
            return
        connected = [p.id for p in self.room.connected_players() if p.id in self.players]
        if not connected:
            return
        if all(self.players[pid]["alive"]
               and (self.players[pid]["col"], self.players[pid]["row"]) == self.exit_pos
               for pid in connected):
            self.phase = "levelComplete"
            self.phase_until = time.time() + BANNER_SECONDS
            self.levels_cleared += 1
            for p in self.room.players:
                p.score = self.levels_cleared

    # ---- enemy / projectile stepping --------------------------------------

    def _enemy_can_enter(self, col: int, row: int) -> bool:
        return self._is_floor(col, row)

    def _step_enemies(self, dt: float) -> None:
        self._enemy_accum += dt
        while self._enemy_accum >= ENEMY_STEP_INTERVAL:
            self._enemy_accum -= ENEMY_STEP_INTERVAL
            self._step_enemies_once()

    def _step_enemies_once(self) -> None:
        for enemy in self.enemies.values():
            if enemy["type"] == "patroller":
                self._step_patroller(enemy)
            elif enemy["type"] == "chaser":
                self._step_chaser(enemy)
            # turrets are stationary -- see _fire_turrets

    def _step_patroller(self, enemy: dict) -> None:
        dc, dr = enemy["dir"]
        nc, nr = enemy["col"] + dc, enemy["row"] + dr
        if self._enemy_can_enter(nc, nr):
            enemy["col"], enemy["row"] = nc, nr
            return
        # Reverse and try the opposite way; if that's blocked too the
        # patroller simply stays put this step (e.g. a dead-end alcove).
        dc, dr = -dc, -dr
        enemy["dir"] = (dc, dr)
        nc, nr = enemy["col"] + dc, enemy["row"] + dr
        if self._enemy_can_enter(nc, nr):
            enemy["col"], enemy["row"] = nc, nr

    def _step_chaser(self, enemy: dict) -> None:
        target = self._nearest_player(enemy["col"], enemy["row"])
        if target is None:
            return
        tc, tr = target
        dc = tc - enemy["col"]
        dr = tr - enemy["row"]
        step_c = (1 if dc > 0 else -1 if dc < 0 else 0)
        step_r = (1 if dr > 0 else -1 if dr < 0 else 0)

        def try_move(sc, sr) -> bool:
            if sc == 0 and sr == 0:
                return False
            nc, nr = enemy["col"] + sc, enemy["row"] + sr
            if self._enemy_can_enter(nc, nr):
                enemy["col"], enemy["row"] = nc, nr
                return True
            return False

        # Greedy: prefer the axis with the larger distance, fall back to the
        # other one if that direction is blocked. No pathfinding at all.
        if abs(dc) >= abs(dr):
            if not try_move(step_c, 0):
                try_move(0, step_r)
        else:
            if not try_move(0, step_r):
                try_move(step_c, 0)

    def _nearest_player(self, col: int, row: int):
        best = None
        best_dist = None
        for state in self.players.values():
            if not state["alive"]:
                continue
            dist = abs(state["col"] - col) + abs(state["row"] - row)
            if best_dist is None or dist < best_dist:
                best_dist = dist
                best = (state["col"], state["row"])
        return best

    def _fire_turrets(self, now: float) -> None:
        for enemy in self.enemies.values():
            if enemy["type"] != "turret":
                continue
            if now < enemy.get("next_fire_at", 0.0):
                continue
            enemy["next_fire_at"] = now + TURRET_FIRE_INTERVAL
            dc, dr = random.choice(list(DIRECTIONS.values()))
            fc, fr = enemy["col"] + dc, enemy["row"] + dr
            if self._is_floor(fc, fr):
                self.projectiles.append({"col": fc, "row": fr, "dir": (dc, dr)})

    def _step_projectiles(self, dt: float) -> None:
        self._proj_accum += dt
        while self._proj_accum >= PROJECTILE_STEP_INTERVAL:
            self._proj_accum -= PROJECTILE_STEP_INTERVAL
            self._step_projectiles_once()

    def _step_projectiles_once(self) -> None:
        survivors = []
        for proj in self.projectiles:
            dc, dr = proj["dir"]
            nc, nr = proj["col"] + dc, proj["row"] + dr
            if not self._is_floor(nc, nr):
                continue  # hit a wall/rock -- disappears
            proj["col"], proj["row"] = nc, nr
            survivors.append(proj)
        self.projectiles = survivors

    # ---- wire format --------------------------------------------------

    def public_state(self):
        return {
            "level": self.level,
            "maxLevel": MAX_LEVEL,
            "gridWidth": self.width,
            "gridHeight": self.height,
            "tiles": ["".join(row) for row in self.tiles],
            "gems": [{"col": c, "row": r} for c, r in sorted(self.gems)],
            "gemsRemaining": len(self.gems),
            "gemsTotal": self.total_gems,
            "exitCol": self.exit_pos[0],
            "exitRow": self.exit_pos[1],
            "exitUnlocked": self.exit_unlocked,
            "players": [
                {
                    "playerID": pid,
                    "name": self.player_name(pid),
                    "col": state["col"],
                    "row": state["row"],
                    "facing": state["facing"],
                    "alive": state["alive"],
                    "invulnerable": time.time() < state["invuln_until"],
                }
                for pid, state in self.players.items()
            ],
            "enemies": [
                {"id": eid, "type": e["type"], "col": e["col"], "row": e["row"]}
                for eid, e in self.enemies.items()
            ],
            "projectiles": [
                {"col": p["col"], "row": p["row"],
                 "direction": REVERSE_DIRECTIONS.get(p["dir"], "down")}
                for p in self.projectiles
            ],
            "livesCurrent": self.lives_current,
            "livesMax": self.lives_max,
            "phase": self.phase,
            "finished": self._finished,
            "lastBlastCol": self.last_blast_fx["col"] if self.last_blast_fx else None,
            "lastBlastRow": self.last_blast_fx["row"] if self.last_blast_fx else None,
            "lastBlastAt": self.last_blast_fx["at"] if self.last_blast_fx else None,
        }

    def private_state(self, player_id):
        state = self.players.get(player_id, {})
        return {
            "level": self.level,
            "livesCurrent": self.lives_current,
            "livesMax": self.lives_max,
            "gemsRemaining": len(self.gems),
            "phase": self.phase,
            "alive": state.get("alive", True),
            "facing": state.get("facing", "down"),
        }

    def is_over(self):
        return self._finished

    def results(self):
        # Co-op, not competitive: every player who finished the run shares
        # the same completion score (levels cleared), and nobody outranks a
        # teammate for reaching the same exit tile they did.
        return [
            {"playerID": p.id, "name": p.name, "score": self.levels_cleared, "rank": 1}
            for p in self.room.players
        ]


ENGINES = {
    "blast_runners": BlastRunnersEngine,
}
