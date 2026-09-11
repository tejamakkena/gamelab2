"""Blast Runners -- a dedicated test file rather than an extension of
``tests/test_native_engines.py``: that file's ``make()``/``ACTIONS`` harness
assumes a fixed-shape board that a short scripted play loop can exercise, but
this engine's whole identity is a 25-level generator plus a shared life pool
whose behavior only shows up across level transitions and hand-poked
collisions -- exactly the kind of setup the generic harness isn't built for.
"""

import time

import pytest

from games.native_hub.engines import blast_runners as br
from games.native_hub.registry import ENGINES
from utils.room_manager import RoomRegistry, RoomState


class _NullBroadcaster:
    def state(self): pass
    def room_update(self): pass
    def error(self, *args, **kwargs): pass


def make(num_players=1):
    cls = ENGINES["blast_runners"]
    registry = RoomRegistry()
    room = registry.create("blast_runners")
    players = [room.add_player(f"p{i}", f"P{i}", f"s{i}") for i in range(num_players)]
    engine = cls(room, _NullBroadcaster())
    room.engine = engine
    room.state = RoomState.PLAYING
    engine.start(players)
    return engine, room, players


# ---------------------------------------------------------------------------
# Level generation
# ---------------------------------------------------------------------------


class TestLevelGeneration:
    @pytest.mark.parametrize("level", range(1, 26))
    def test_every_level_is_valid(self, level):
        spec = br.generate_level(level)
        tiles = spec["tiles"]
        h, w = len(tiles), len(tiles[0])

        assert all(len(row) == w for row in tiles)
        assert 8 <= w <= 14 and 8 <= h <= 14

        # Only the outer ring is permanent wall.
        for c in range(w):
            assert tiles[0][c] == br.WALL
            assert tiles[h - 1][c] == br.WALL
        for r in range(h):
            assert tiles[r][0] == br.WALL
            assert tiles[r][w - 1] == br.WALL
        for r in range(1, h - 1):
            for c in range(1, w - 1):
                assert tiles[r][c] in (br.FLOOR, br.ROCK)

        assert len(spec["gems"]) > 0

        sc, sr = spec["spawn_pos"]
        ec, er = spec["exit_pos"]
        assert tiles[sr][sc] == br.FLOOR
        assert tiles[er][ec] == br.FLOOR
        assert (sc, sr) != (ec, er)

        # A gem is only ever collected by moving *onto* its tile (see
        # handle_action's "move" case) -- one sitting exactly on the spawn
        # tile could never be picked up through ordinary play (a player
        # starts standing on it already), and one sitting on the exit tile
        # meant the exit could never be reached "clean" without it
        # happening to be the last pickup. Two of the hand-authored
        # landmark levels (10 and 25) originally shipped with exactly this
        # bug -- a gem placed directly on that level's own spawn_pos, and
        # in level 25's case another directly on exit_pos too.
        gem_set = {tuple(g) for g in spec["gems"]}
        assert (sc, sr) not in gem_set
        assert (ec, er) not in gem_set

        for gc, gr in spec["gems"]:
            assert tiles[gr][gc] == br.FLOOR

        enemy_positions = [(enemy["col"], enemy["row"]) for enemy in spec["enemies"]]
        for pos in enemy_positions:
            assert pos != (sc, sr)
            assert pos != (ec, er)
            assert pos not in gem_set
        assert len(enemy_positions) == len(set(enemy_positions))

        for enemy in spec["enemies"]:
            assert tiles[enemy["row"]][enemy["col"]] != br.WALL

    def test_landmark_levels_are_hand_authored(self):
        for level in (5, 10, 15, 20, 25):
            assert level in br.AUTHORED_LEVELS

    def test_procedural_levels_are_deterministic(self):
        for level in (1, 2, 6, 13, 21, 24):
            first = br.generate_level(level)
            second = br.generate_level(level)
            assert first == second

    def test_grid_grows_with_level(self):
        assert len(br.generate_level(1)["tiles"]) == 8
        assert len(br.generate_level(25)["tiles"]) == 14

    def test_enemy_mix_shifts_over_levels(self):
        early_types = {e["type"] for e in br.generate_level(1)["enemies"]}
        assert early_types == {"patroller"}
        # Some level in the back half of the run should have introduced a
        # turret -- the exact level is an implementation detail of the mix
        # weighting, so scan the procedural range for confirmation.
        assert any(
            any(e["type"] == "turret" for e in br.generate_level(lvl)["enemies"])
            for lvl in range(17, 25)
        )


# ---------------------------------------------------------------------------
# Movement & blast
# ---------------------------------------------------------------------------


class TestMovementAndBlast:
    def test_move_into_open_floor_succeeds(self):
        engine, room, players = make()
        state = engine.players["p0"]
        col, row = state["col"], state["row"]
        # Spawn always has forced-clear neighbours -- see _generate_procedural_level.
        engine.handle_action("p0", "move", {"direction": "right"})
        assert (state["col"], state["row"]) != (col, row) or engine.tiles[row][col + 1] != br.FLOOR

    def test_move_into_wall_is_rejected(self):
        engine, room, players = make()
        state = engine.players["p0"]
        before = (state["col"], state["row"])
        # Spawn sits at (1, 1); "up"/"left" walks straight into the border.
        engine.handle_action("p0", "move", {"direction": "up"})
        assert (state["col"], state["row"]) == before

    def test_move_into_rock_is_rejected(self):
        engine, room, players = make()
        state = engine.players["p0"]
        # Hunt for any rock tile anywhere on the level, then place the
        # player directly beside it facing in.
        rock = None
        for r in range(1, engine.height - 1):
            for c in range(1, engine.width - 1):
                if engine.tiles[r][c] == br.ROCK and engine.tiles[r][c - 1] == br.FLOOR:
                    rock = (c, r)
                    break
            if rock:
                break
        assert rock is not None, "expected at least one rock tile with a floor neighbour"
        rc, rr = rock
        state["col"], state["row"] = rc - 1, rr
        engine.handle_action("p0", "move", {"direction": "right"})
        assert (state["col"], state["row"]) == (rc - 1, rr)

    def test_blast_turns_rock_to_floor(self):
        engine, room, players = make()
        state = engine.players["p0"]
        rock = None
        for r in range(1, engine.height - 1):
            for c in range(1, engine.width - 1):
                if engine.tiles[r][c] == br.ROCK and engine.tiles[r][c - 1] == br.FLOOR:
                    rock = (c, r)
                    break
            if rock:
                break
        assert rock is not None
        rc, rr = rock
        state["col"], state["row"], state["facing"] = rc - 1, rr, "right"
        engine.handle_action("p0", "blast", {})
        assert engine.tiles[rr][rc] == br.FLOOR

    def test_blast_removes_enemy(self):
        engine, room, players = make()
        state = engine.players["p0"]
        state["facing"] = "right"
        eid = "test_enemy"
        engine.enemies[eid] = {"type": "patroller", "col": state["col"] + 1,
                                "row": state["row"], "dir": (1, 0)}
        engine.handle_action("p0", "blast", {})
        assert eid not in engine.enemies

    def test_blast_has_a_cooldown(self):
        engine, room, players = make()
        state = engine.players["p0"]
        state["facing"] = "right"
        engine.enemies["e1"] = {"type": "patroller", "col": state["col"] + 1,
                                 "row": state["row"], "dir": (1, 0)}
        engine.handle_action("p0", "blast", {})
        assert "e1" not in engine.enemies
        # A second enemy placed immediately after should survive: the
        # cooldown blocks another blast this instant.
        engine.enemies["e2"] = {"type": "patroller", "col": state["col"] + 1,
                                 "row": state["row"], "dir": (1, 0)}
        engine.handle_action("p0", "blast", {})
        assert "e2" in engine.enemies


# ---------------------------------------------------------------------------
# Shared life pool
# ---------------------------------------------------------------------------


class TestSharedLifePool:
    def test_pool_scales_with_connected_players(self):
        engine, room, players = make(num_players=3)
        assert engine.lives_max == br.LIVES_PER_PLAYER * 3
        assert engine.lives_current == engine.lives_max

    def test_collision_costs_exactly_one_shared_life(self):
        engine, room, players = make(num_players=2)
        before = engine.lives_current
        state = engine.players["p0"]
        state["invuln_until"] = 0.0
        engine.enemies["hit"] = {"type": "patroller", "col": state["col"],
                                  "row": state["row"], "dir": (1, 0)}
        engine._apply_hit_if_colliding("p0")
        assert engine.lives_current == before - 1

    def test_collision_never_removes_the_player_from_the_room(self):
        engine, room, players = make()
        state = engine.players["p0"]
        state["invuln_until"] = 0.0
        engine.enemies["hit"] = {"type": "patroller", "col": state["col"],
                                  "row": state["row"], "dir": (1, 0)}
        engine._apply_hit_if_colliding("p0")
        assert room.player("p0") is not None
        assert "p0" in engine.players
        assert engine.players["p0"]["alive"] is False

    def test_hit_player_respawns_at_spawn_with_invulnerability(self):
        engine, room, players = make()
        state = engine.players["p0"]
        state["invuln_until"] = 0.0
        engine.enemies["hit"] = {"type": "patroller", "col": state["col"],
                                  "row": state["row"], "dir": (1, 0)}
        engine._apply_hit_if_colliding("p0")
        assert state["alive"] is False
        state["respawn_at"] = 0.0  # force the respawn timer to have elapsed
        engine._process_respawns(time.time())
        assert state["alive"] is True
        assert (state["col"], state["row"]) == engine.spawn_pos
        assert state["invuln_until"] > time.time()

    def test_pool_hitting_zero_resets_the_same_level(self):
        engine, room, players = make()
        level_before = engine.level
        engine.lives_current = 1
        state = engine.players["p0"]
        state["invuln_until"] = 0.0
        engine.enemies["hit"] = {"type": "patroller", "col": state["col"],
                                  "row": state["row"], "dir": (1, 0)}
        engine._apply_hit_if_colliding("p0")

        assert engine.lives_current == 0
        assert engine.phase == "levelFailed"
        assert not engine.is_over()
        assert room.player("p0") is not None

        engine.phase_until = 0.0  # banner already elapsed
        engine.tick(0.1)

        assert engine.level == level_before  # never sent back to level 1
        assert engine.phase == "playing"
        assert engine.lives_current == engine.lives_max
        assert not engine.is_over()
        assert room.player("p0") is not None


# ---------------------------------------------------------------------------
# Gems, exit and level progression
# ---------------------------------------------------------------------------


class TestLevelProgression:
    def test_collecting_every_gem_unlocks_the_exit(self):
        engine, room, players = make()
        assert engine.exit_unlocked is False
        for gem in list(engine.gems):
            engine._collect_gem_if_present(*gem)
        assert len(engine.gems) == 0
        assert engine.exit_unlocked is True

    def test_reaching_exit_advances_to_a_fresh_level_with_refilled_lives(self):
        engine, room, players = make()
        engine.lives_current = 1  # prove the pool gets refilled, not just left alone
        engine.gems.clear()
        engine.exit_unlocked = True
        state = engine.players["p0"]
        state["col"], state["row"] = engine.exit_pos
        engine._check_win()
        assert engine.phase == "levelComplete"

        engine.phase_until = 0.0
        engine.tick(0.1)

        assert engine.level == 2
        assert engine.phase == "playing"
        assert engine.lives_current == engine.lives_max
        assert len(engine.gems) > 0
        assert engine.exit_unlocked is False

    def test_win_requires_all_connected_players_at_exit(self):
        engine, room, players = make(num_players=2)
        engine.gems.clear()
        engine.exit_unlocked = True
        engine.players["p0"]["col"], engine.players["p0"]["row"] = engine.exit_pos
        # p1 is still elsewhere -- not a win yet.
        engine._check_win()
        assert engine.phase == "playing"

        engine.players["p1"]["col"], engine.players["p1"]["row"] = engine.exit_pos
        engine._check_win()
        assert engine.phase == "levelComplete"

    def test_completing_level_25_ends_the_game(self):
        engine, room, players = make()
        engine._start_level(25, refill_lives=True)
        engine.level = 25
        engine.gems.clear()
        engine.exit_unlocked = True
        engine.players["p0"]["col"], engine.players["p0"]["row"] = engine.exit_pos
        engine._check_win()
        assert engine.phase == "levelComplete"

        engine.phase_until = 0.0
        engine.tick(0.1)

        assert engine.phase == "gameComplete"
        assert engine.is_over() is True

        results = engine.results()
        assert len(results) == 1
        assert results[0]["playerID"] == "p0"
        assert results[0]["score"] == engine.levels_cleared


# ---------------------------------------------------------------------------
# Enemies & projectiles
# ---------------------------------------------------------------------------


class TestEnemiesAndProjectiles:
    def test_patroller_reverses_at_a_wall(self):
        engine, room, players = make()
        # Column 0 is always the border; a patroller one step in, heading
        # left, must bounce back right on its very next step.
        engine.enemies = {"p": {"type": "patroller", "col": 1, "row": 1, "dir": (-1, 0)}}
        engine._step_enemies_once()
        assert engine.enemies["p"]["dir"] == (1, 0)

    def test_chaser_steps_toward_nearest_player(self):
        engine, room, players = make()
        state = engine.players["p0"]
        state["col"], state["row"] = 5, 5
        engine.enemies = {"c": {"type": "chaser", "col": 1, "row": 5}}
        engine.tiles[5] = list(br.FLOOR * engine.width)
        engine.tiles[5][0] = br.WALL
        engine.tiles[5][-1] = br.WALL
        engine._step_enemies_once()
        assert engine.enemies["c"]["col"] == 2

    def test_turret_fires_a_projectile_that_travels(self):
        engine, room, players = make()
        engine.enemies = {"t": {"type": "turret", "col": 3, "row": 3, "next_fire_at": 0.0}}
        for r in range(engine.height):
            for c in range(engine.width):
                if 0 < r < engine.height - 1 and 0 < c < engine.width - 1:
                    engine.tiles[r][c] = br.FLOOR
        engine._fire_turrets(time.time())
        assert len(engine.projectiles) == 1
        proj = engine.projectiles[0]
        pos_before = (proj["col"], proj["row"])
        engine._step_projectiles_once()
        assert (proj["col"], proj["row"]) != pos_before

    def test_projectile_disappears_on_hitting_a_wall(self):
        engine, room, players = make()
        engine.projectiles = [{"col": 1, "row": 1, "dir": (-1, 0)}]  # heading straight into the border
        engine._step_projectiles_once()
        assert engine.projectiles == []


# ---------------------------------------------------------------------------
# Wire format
# ---------------------------------------------------------------------------


class TestWireFormat:
    def test_public_state_has_the_documented_keys(self):
        engine, room, players = make(num_players=2)
        state = engine.public_state()
        for key in (
            "level", "maxLevel", "gridWidth", "gridHeight", "tiles", "gems",
            "gemsRemaining", "gemsTotal", "exitCol", "exitRow", "exitUnlocked",
            "players", "enemies", "projectiles", "livesCurrent", "livesMax",
            "phase", "finished",
        ):
            assert key in state
        assert len(state["players"]) == 2
        for p in state["players"]:
            for key in ("playerID", "name", "col", "row", "facing", "alive", "invulnerable"):
                assert key in p

    def test_private_state_returns_a_dict_for_every_player(self):
        engine, room, players = make(num_players=2)
        for p in players:
            assert isinstance(engine.private_state(p.id), dict)

    def test_blast_publishes_a_one_shot_fx_marker(self):
        engine, room, players = make()
        state = engine.players["p0"]
        state["facing"] = "right"
        assert engine.public_state()["lastBlastAt"] is None
        engine.handle_action("p0", "blast", {})
        pub = engine.public_state()
        assert pub["lastBlastAt"] is not None
        assert pub["lastBlastCol"] == state["col"] + 1
        assert pub["lastBlastRow"] == state["row"]
