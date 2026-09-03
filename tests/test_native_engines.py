"""Every game engine, driven through real play.

The privacy tests are the important ones. `public_state()` goes to the whole
room and the TV renders it on a screen everyone can see, so a secret leaking
into it breaks the game regardless of what the phone UI chooses to draw.
"""

import json
import random

import pytest

from games.native_hub.engine import NativeGameEngine
from games.native_hub.engines._placeholder import PlaceholderEngine
from games.native_hub.registry import ENGINES, engine_for
from utils.room_manager import RoomRegistry, RoomState


class _NullBroadcaster:
    def state(self): pass
    def room_update(self): pass
    def error(self, *args, **kwargs): pass


def make(game_id, players=4, seed=7):
    """Start a game with a plausible number of players."""
    random.seed(seed)
    cls = ENGINES[game_id]
    registry = RoomRegistry()
    room = registry.create(game_id)
    count = min(max(cls.min_players, players), cls.max_players)
    roster = [room.add_player(f"p{i}", f"P{i}", f"s{i}") for i in range(count)]
    engine = cls(room, _NullBroadcaster())
    room.engine = engine
    room.state = RoomState.PLAYING
    engine.start(roster)
    return engine, roster


# Plausible actions per game, so the play loop exercises real code paths.
ACTIONS = {
    "bluff_it": [("submit_lie", {"text": "banana"}), ("pick", {"index": 0})],
    "last_tap": [("tap", {})],
    "herd": [("answer", {"text": "idli"})],
    "emoji_movie": [("submit_emoji", {"emoji": "\U0001F981\U0001F451"}),
                    ("guess", {"index": 0, "text": "Frozen"})],
    "npat": [("submit", {"name": "Amit", "place": "Agra",
                         "animal": "Ant", "thing": "Axe"})],
    "antakshari": [("submit_song", {"song": "Anything"})],
    "cipher_grid": [("give_clue", {"word": "animal", "count": 2}),
                    ("guess", {"index": 0}), ("end_turn", {})],
    "odd_one_out": [("call_vote", {}), ("vote", {"targetID": "p1"})],
    "sealed_auction": [("bid", {"amount": 20})],
    "wavelength": [("give_clue", {"clue": "tea"}), ("set_dial", {"value": 60})],
    "kbc": [("lifeline_fifty", {}), ("poll_vote", {"index": 0}), ("answer", {"index": 0})],
    "bollywood_charades": [("guess", {"text": "Sholay"})],
    "defuse": [("cut", {"index": 0}), ("button", {"press": "tap"}),
               ("symbol", {"index": 0})],
    "battleship": [("fire", {"cell": 5}), ("fire", {"cell": 12})],
    "air_hockey": [("paddle", {"x": 40})],
    "heist_escape": [("move", {"direction": "right"}), ("move", {"direction": "down"})],
    "ludo": [("roll", {}), ("move", {"token": 0})],
    "carrom": [("position", {"x": 50}), ("flick", {"angle": 0.1, "power": 0.8})],
    "teen_patti": [("see", {}), ("call", {}), ("bet", {}), ("fold", {})],
    "neon_snake": [("turn", {"direction": "down"}), ("turn", {"direction": "left"})],
    "twenty48": [("swipe", {"direction": "left"}), ("swipe", {"direction": "up"})],
    "brick_breaker": [("paddle", {"x": 55})],
    "simon_says": [("pad", {"pad": "up"}), ("pad", {"pad": "down"})],
    "atlas": [("answer", {"place": "Agra"}), ("answer", {"place": "Nepal"})],
}

ALL_GAMES = sorted(ENGINES)


class TestRegistry:
    def test_every_engine_declares_its_own_id(self):
        for gid, cls in ENGINES.items():
            assert cls.game_id == gid

    def test_unknown_ids_fall_back_to_the_placeholder(self):
        # Lets an id the Swift app knows about still be startable end to end.
        assert engine_for("not_a_game") is PlaceholderEngine
        assert engine_for("trivia") is PlaceholderEngine

    def test_player_bounds_are_sane(self):
        for gid, cls in ENGINES.items():
            assert 1 <= cls.min_players <= cls.max_players, gid

    def test_all_engines_implement_the_contract(self):
        for cls in ENGINES.values():
            assert issubclass(cls, NativeGameEngine)


@pytest.mark.parametrize("game_id", ALL_GAMES)
class TestPlayLoop:
    def test_drives_to_completion_without_raising(self, game_id):
        engine, roster = make(game_id)
        for _ in range(60):
            for i, player in enumerate(roster):
                for verb, data in ACTIONS.get(game_id, []):
                    payload = dict(data)
                    if "targetID" in payload:
                        payload["targetID"] = roster[(i + 1) % len(roster)].id
                    engine.handle_action(player.id, verb, payload)
            engine.tick(0.2)
            if engine.is_over():
                break
        assert isinstance(engine.results(), list)

    def test_state_is_json_serialisable(self, game_id):
        # Anything that cannot be serialised never reaches a client.
        engine, roster = make(game_id)
        json.dumps(engine.public_state())
        for player in roster:
            json.dumps(engine.private_state(player.id))

    def test_every_player_gets_a_non_empty_private_state(self, game_id):
        # The phone leaves its waiting screen on the first private_state it
        # receives, not on game_started -- an empty dict would strand it there.
        engine, roster = make(game_id)
        for player in roster:
            state = engine.private_state(player.id)
            assert isinstance(state, dict) and state, game_id

    def test_results_rows_have_the_expected_shape(self, game_id):
        engine, _ = make(game_id)
        for row in engine.results():
            assert {"playerID", "name", "score", "rank"} <= set(row)

    def test_ignores_junk_actions(self, game_id):
        engine, roster = make(game_id)
        for verb in ("not_a_verb", "tap", "move"):
            engine.handle_action(roster[0].id, verb, {"garbage": object()})
            engine.handle_action("ghost-player", verb, {})

    def test_survives_a_player_leaving(self, game_id):
        engine, roster = make(game_id)
        engine.on_player_leave(roster[-1].id)
        engine.tick(0.2)
        json.dumps(engine.public_state())


class TestPrivacy:
    """A secret must never appear in public_state."""

    def test_cipher_grid_key_is_spymaster_only(self):
        engine, roster = make("cipher_grid", players=4)
        assert "key" not in engine.public_state()
        spymasters = [p.id for p in roster
                      if engine.spymasters.get(engine.teams.get(p.id)) == p.id]
        others = [p.id for p in roster if p.id not in spymasters]
        assert len(engine.private_state(spymasters[0])["key"]) == 25
        assert engine.private_state(others[0])["key"] == []

    def test_spy_is_never_told_the_location(self):
        engine, roster = make("odd_one_out", players=5)
        assert engine.public_state()["location"] is None
        assert engine.private_state(engine.spy)["location"] is None
        innocent = next(p.id for p in roster if p.id != engine.spy)
        assert engine.private_state(innocent)["location"] == engine.location

    def test_bluff_it_truth_hidden_while_lies_are_written(self):
        engine, roster = make("bluff_it")
        assert engine.public_state()["truth"] is None
        for player in roster:
            blob = json.dumps(engine.private_state(player.id)).lower()
            assert engine.truth.lower() not in blob

    def test_wavelength_target_is_psychic_only(self):
        engine, roster = make("wavelength")
        assert engine.public_state()["target"] is None
        assert engine.private_state(engine.psychic)["target"] == engine.target
        guesser = next(p.id for p in roster if p.id != engine.psychic)
        assert engine.private_state(guesser)["target"] is None

    def test_kbc_answer_withheld_until_reveal(self):
        # The TV highlights correctIndex the moment the key is present.
        engine, _ = make("kbc")
        assert engine.public_state()["correctIndex"] is None

    def test_teen_patti_blind_players_are_not_sent_their_cards(self):
        engine, roster = make("teen_patti")
        assert engine.public_state()["showdown"] == []
        assert engine.private_state(roster[0].id)["cards"] == []
        actor = engine.current_player_id()
        engine.handle_action(actor, "see", {})
        assert len(engine.private_state(actor)["cards"]) == 3

    def test_teen_patti_never_reveals_another_hand(self):
        engine, roster = make("teen_patti")
        actor = engine.current_player_id()
        engine.handle_action(actor, "see", {})
        mine = json.dumps(engine.private_state(actor))
        for player in roster:
            if player.id != actor:
                assert json.dumps(engine.hands[player.id]) not in mine

    def test_battleship_fleets_stay_private(self):
        engine, roster = make("battleship", players=2)
        assert "ships" not in json.dumps(engine.public_state()).lower()
        mine = engine.private_state(roster[0].id)
        assert mine["myShips"] == engine.fleets[roster[0].id]
        assert "myShips" in mine and engine.fleets[roster[1].id] != mine["myShips"]

    def test_defuse_splits_the_bomb_from_the_manual(self):
        engine, roster = make("defuse", players=3)
        public = engine.public_state()
        assert "answer" not in public["module"]
        assert "manual" not in public["module"]

        defuser = engine.private_state(engine.defuser)
        assert defuser["manual"] == []          # sees the bomb, not the book
        helper_id = next(p.id for p in roster if p.id != engine.defuser)
        helper = engine.private_state(helper_id)
        assert helper["manual"] and helper["module"] == {}

        for player in roster:
            assert "answer" not in json.dumps(engine.private_state(player.id))

    def test_defuse_module_variants_stay_answer_free(self):
        engine, _ = make("defuse", players=3)
        for index, _ in enumerate(engine.modules):
            engine.module_index = index
            assert "answer" not in engine.public_state()["module"]

    def test_emoji_movie_titles_are_per_player(self):
        engine, roster = make("emoji_movie")
        assert engine.public_state()["entries"] == []
        mine = engine.private_state(roster[0].id)
        assert mine["myTitle"] == engine.assignments[roster[0].id]
        blob = json.dumps(mine).lower()
        for player in roster[1:]:
            other = engine.assignments[player.id]
            if other != mine["myTitle"]:
                assert other.lower() not in blob

    def test_charades_title_is_actor_only(self):
        engine, roster = make("bollywood_charades")
        assert engine.public_state()["title"] is None
        assert engine.private_state(engine.actor)["title"] == engine.title
        guesser = next(p.id for p in roster if p.id != engine.actor)
        assert engine.private_state(guesser)["title"] is None

    def test_heist_escape_map_is_split_not_shared(self):
        engine, roster = make("heist_escape", players=3)
        assert "walls" not in json.dumps(engine.public_state()).lower()
        sizes = [len(engine.private_state(p.id)["myWalls"]) for p in roster]
        assert all(size < len(engine.walls) for size in sizes)
        assert sum(sizes) == len(engine.walls)

    def test_simon_sequence_hidden_while_being_tested(self):
        engine, _ = make("simon_says", players=2)
        engine.phase = "input"
        assert engine.public_state()["sequence"] == []
        engine.phase = "show"
        assert engine.public_state()["sequence"]


class TestGameRules:
    def test_heist_escape_maze_is_always_solvable(self):
        # Walls are added only where they cannot block the carved solution.
        for seed in range(20):
            engine, _ = make("heist_escape", players=2, seed=seed)
            path = engine.path
            assert path[0] == 0 and path[-1] == engine.exit_cell
            for a, b in zip(path, path[1:]):
                assert (min(a, b), max(a, b)) not in engine.walls

    def test_last_tap_never_eliminates_everyone(self):
        engine, roster = make("last_tap", players=5)
        engine.phase = "go"
        for player in roster:
            engine.handle_action(player.id, "tap", {})
        engine._resolve()
        assert len(engine.alive) >= 1

    def test_teen_patti_ranks_a_trail_above_a_pair(self):
        engine, _ = make("teen_patti", players=2)
        trail = [{"rank": 9, "suit": s} for s in ("♠", "♥", "♦")]
        pair = [{"rank": 9, "suit": "♠"}, {"rank": 9, "suit": "♥"},
                {"rank": 4, "suit": "♦"}]
        assert engine._hand_rank(trail) > engine._hand_rank(pair)

    def test_teen_patti_pure_sequence_beats_a_plain_sequence(self):
        engine, _ = make("teen_patti", players=2)
        pure = [{"rank": r, "suit": "♠"} for r in (5, 6, 7)]
        plain = [{"rank": 5, "suit": "♠"}, {"rank": 6, "suit": "♥"},
                 {"rank": 7, "suit": "♦"}]
        assert engine._hand_rank(pure) > engine._hand_rank(plain)

    def test_cipher_grid_assassin_hands_the_win_to_the_other_team(self):
        engine, _ = make("cipher_grid", players=4)
        assassin = engine.key.index("assassin")
        engine.turn = "red"
        engine._reveal(assassin, "red")
        assert engine.is_over() and engine.winner == "blue"

    def test_npat_scores_unique_answers_higher(self):
        engine, roster = make("npat", players=3)
        letter = engine.letter.lower()
        shared = {f: letter + "same" for f in ["name", "place", "animal", "thing"]}
        engine.submissions[roster[0].id] = dict(shared)
        engine.submissions[roster[1].id] = dict(shared)
        engine.submissions[roster[2].id] = {f: letter + "uniq"
                                            for f in ["name", "place", "animal", "thing"]}
        engine._score()
        assert engine.scores[roster[2].id] > engine.scores[roster[0].id]

    def test_antakshari_chains_to_the_last_letter(self):
        engine, roster = make("antakshari", players=2)
        song = engine.letter + "melody"
        engine.handle_action(roster[0].id, "submit_song", {"song": song})
        engine._score()
        assert engine.letter == song[-1].upper()

    def test_antakshari_rejects_a_wrong_starting_letter(self):
        engine, roster = make("antakshari", players=2)
        wrong = "Z" if engine.letter != "Z" else "A"
        engine.handle_action(roster[0].id, "submit_song", {"song": wrong + "song"})
        assert roster[0].id not in engine.submissions

    def test_sealed_auction_cannot_bid_beyond_budget(self):
        engine, roster = make("sealed_auction", players=3)
        engine.handle_action(roster[0].id, "bid", {"amount": 10_000})
        assert roster[0].id not in engine.submissions

    def test_atlas_rejects_reused_and_mismatched_places(self):
        engine, roster = make("atlas", players=2)
        actor = engine.current_player()
        engine.letter = "N"
        engine.handle_action(actor, "answer", {"place": "Agra"})   # wrong letter
        assert len(engine.chain) == 1
        engine.handle_action(actor, "answer", {"place": "Nepal"})
        assert len(engine.chain) == 2
        engine.letter = "N"
        engine.handle_action(engine.current_player(), "answer", {"place": "Nepal"})
        assert len(engine.chain) == 2                              # already used

    def test_twenty48_merges_equal_tiles(self):
        engine, roster = make("twenty48", players=1)
        board = engine.boards[roster[0].id]
        board[:] = [0] * 16
        board[0] = board[1] = 2
        engine.handle_action(roster[0].id, "swipe", {"direction": "left"})
        assert 4 in engine.boards[roster[0].id]
        assert engine.scores[roster[0].id] >= 4

    def test_battleship_hit_keeps_the_turn(self):
        engine, roster = make("battleship", players=2)
        shooter = engine.current_player_id()
        target = next(p for p in engine.order if p != shooter)
        cell = engine.fleets[target][0][0]
        engine.handle_action(shooter, "fire", {"cell": cell})
        assert engine.current_player_id() == shooter

    def test_battleship_cannot_fire_out_of_turn(self):
        engine, _ = make("battleship", players=2)
        waiting = next(p for p in engine.order if p != engine.current_player_id())
        engine.handle_action(waiting, "fire", {"cell": 0})
        assert engine.shots[waiting] == {}
