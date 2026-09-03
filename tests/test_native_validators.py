"""Input validation for the native hub.

`game_id` is the load-bearing one: `Room.gameID` is a non-optional enum on the
Swift side, so an unrecognised string makes the entire room payload fail to
decode -- and the client swallows decode failures.
"""

import pytest

from utils import validators as v
from utils.player_manager import SidIndex, sanitize_name


class TestRoomCode:
    @pytest.mark.parametrize("raw,expected", [
        ("ABC123", "ABC123"),
        (" abc123 ", "ABC123"),
        ("abc123", "ABC123"),
    ])
    def test_normalises(self, raw, expected):
        assert v.room_code(raw) == expected

    @pytest.mark.parametrize("bad", ["", "SHORT", "TOOLONG7", "AB-123", None, 12345, []])
    def test_rejects_malformed(self, bad):
        assert v.room_code(bad) is None


class TestGameID:
    def test_accepts_known_ids(self):
        for gid in ("trivia", "cipher_grid", "teen_patti", "neon_snake"):
            assert v.game_id(gid) == gid

    @pytest.mark.parametrize("bad", ["nope", "", None, 7, "TRIVIA"])
    def test_rejects_unknown(self, bad):
        assert v.game_id(bad) is None

    def test_allowlist_covers_every_registered_engine(self):
        from games.native_hub.registry import ENGINES
        assert set(ENGINES) <= v.GAME_IDS


class TestAction:
    @pytest.mark.parametrize("good", ["tap", "submit_lie", "give_clue", "a"])
    def test_accepts_snake_case(self, good):
        assert v.action(good) == good

    @pytest.mark.parametrize("bad", ["Tap", "drop!", "", "9lives", "x" * 40, None])
    def test_rejects_anything_else(self, bad):
        assert v.action(bad) is None


class TestActionData:
    def test_passes_dicts_through(self):
        assert v.action_data({"column": 3}) == {"column": 3}

    @pytest.mark.parametrize("bad", ["x", None, 7, []])
    def test_coerces_non_dicts_to_empty(self, bad):
        assert v.action_data(bad) == {}

    def test_rejects_oversized_payloads(self):
        assert v.action_data({"blob": "x" * 40_000}) == {}

    def test_rejects_unserialisable_payloads(self):
        assert v.action_data({"fn": object()}) == {}


class TestPlayerID:
    def test_accepts_a_device_uuid(self):
        assert v.player_id(" dev-1 ") == "dev-1"

    @pytest.mark.parametrize("bad", ["", "  ", None, 5, "x" * 65])
    def test_rejects_malformed(self, bad):
        assert v.player_id(bad) is None


class TestNameHygiene:
    def test_collapses_whitespace(self):
        assert sanitize_name("  Teja   M  ") == "Teja M"

    def test_caps_at_the_field_length(self):
        # JoinRoomView caps input at 20; match it so a crafted client cannot
        # push a huge name into everyone else's roster.
        assert len(sanitize_name("x" * 200)) == 20

    @pytest.mark.parametrize("bad", [None, 5, "", "   "])
    def test_falls_back(self, bad):
        assert sanitize_name(bad) == "Player"

    def test_strips_control_characters(self):
        assert sanitize_name("Te\x07ja\x00") == "Teja"


class TestSidIndex:
    def test_bind_lookup_unbind(self):
        idx = SidIndex()
        idx.bind("s1", "ABC123", "dev-1")
        assert idx.lookup("s1").player_id == "dev-1"
        assert idx.unbind("s1").room_code == "ABC123"
        assert idx.lookup("s1") is None

    def test_clear_room_removes_every_binding(self):
        idx = SidIndex()
        idx.bind("s1", "AAA111", "a")
        idx.bind("s2", "AAA111", "b")
        idx.bind("s3", "BBB222", "c")
        idx.clear_room("AAA111")
        assert len(idx) == 1 and idx.lookup("s3") is not None
