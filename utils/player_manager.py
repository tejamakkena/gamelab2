"""Socket-id bookkeeping and player-name hygiene for the native hub.

A Socket.IO ``sid`` is ephemeral -- it changes on every reconnect. The native
apps instead carry a stable per-device UUID (``AppConstants.deviceID``) as the
player id, which is what lets a phone drop off Wi-Fi mid-game and reclaim its
seat. This module owns the mapping between the two.
"""

import threading
from dataclasses import dataclass

# JoinRoomView caps the name field at 20 characters; match it server-side so a
# crafted client cannot push a 10k-char name into every other player's roster.
MAX_NAME_LEN = 20


@dataclass(frozen=True)
class Binding:
    """What a live socket is currently attached to."""

    sid: str
    room_code: str
    player_id: str | None  # None for a TV/board socket
    is_tv: bool = False


class SidIndex:
    """Thread-safe sid -> Binding map.

    Handlers run on real OS threads under async_mode='threading', so every
    mutation is guarded.
    """

    def __init__(self) -> None:
        self._bindings: dict[str, Binding] = {}
        self._lock = threading.RLock()

    def bind(self, sid: str, room_code: str, player_id: str | None = None,
             is_tv: bool = False) -> Binding:
        binding = Binding(sid=sid, room_code=room_code,
                          player_id=player_id, is_tv=is_tv)
        with self._lock:
            self._bindings[sid] = binding
        return binding

    def lookup(self, sid: str) -> Binding | None:
        with self._lock:
            return self._bindings.get(sid)

    def unbind(self, sid: str) -> Binding | None:
        with self._lock:
            return self._bindings.pop(sid, None)

    def sids_for_room(self, room_code: str) -> list[str]:
        with self._lock:
            return [s for s, b in self._bindings.items()
                    if b.room_code == room_code]

    def clear_room(self, room_code: str) -> None:
        with self._lock:
            for sid in [s for s, b in self._bindings.items()
                        if b.room_code == room_code]:
                del self._bindings[sid]

    def __len__(self) -> int:
        with self._lock:
            return len(self._bindings)


def sanitize_name(raw, fallback: str = "Player") -> str:
    """Collapse whitespace, strip control characters, cap at 20 chars."""
    if not isinstance(raw, str):
        return fallback
    cleaned = " ".join(raw.split())
    cleaned = "".join(ch for ch in cleaned if ch.isprintable())
    cleaned = cleaned[:MAX_NAME_LEN].strip()
    return cleaned or fallback
