"""Fallback engine for game ids that have no implementation yet.

This is what makes an incremental rollout possible: every GameID the Swift app
knows about can be created, joined, readied and started end-to-end from day one.
The TV renders a "coming soon" card instead of an empty screen, and each real
engine later replaces one entry in the registry.
"""

from games.native_hub.engine import NativeGameEngine
from utils.room_manager import Player


class PlaceholderEngine(NativeGameEngine):
    game_id = "_placeholder"
    min_players = 1
    max_players = 20

    def __init__(self, room, broadcaster) -> None:
        super().__init__(room, broadcaster)
        self._players: list[Player] = []

    def start(self, players: list[Player]) -> None:
        self._players = list(players)

    def handle_action(self, player_id: str, action: str, data: dict) -> None:
        return

    def public_state(self) -> dict:
        return {
            "status": "coming_soon",
            "gameID": self.room.game_id,
            "message": "This game is not playable yet.",
            "players": [
                {"id": p.id, "name": p.name, "score": p.score, "isHost": p.is_host}
                for p in self.room.players
            ],
        }

    def private_state(self, player_id: str) -> dict:
        # Still returned for every player: the phone leaves its waiting screen
        # on the first private_state, so an empty dict here would strand it.
        return {"status": "coming_soon", "gameID": self.room.game_id}

    def is_over(self) -> bool:
        return False

    def results(self) -> list[dict]:
        return self.ranked_results({p.id: p.score for p in self.room.players})
