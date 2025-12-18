from dataclasses import dataclass
from typing import Dict, List, Optional
from datetime import datetime


@dataclass
class Player:
    """Player model for Tic Tac Toe"""
    id: str
    username: Optional[str] = None
    symbol: str = ''  # 'X' or 'O'
    wins: int = 0
    losses: int = 0
    draws: int = 0

    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'symbol': self.symbol,
            'wins': self.wins,
            'losses': self.losses,
            'draws': self.draws
        }


@dataclass
class GameMove:
    """Represents a single move in the game"""
    player_id: str
    position: int
    symbol: str
    timestamp: datetime

    def to_dict(self):
        return {
            'player_id': self.player_id,
            'position': self.position,
            'symbol': self.symbol,
            'timestamp': self.timestamp.isoformat()
        }


@dataclass
class GameSession:
    """Complete game session data"""
    room_code: str
    players: Dict[str, Player]
    moves: List[GameMove]
    winner: Optional[str] = None
    is_draw: bool = False
    created_at: datetime = None
    finished_at: Optional[datetime] = None

    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now()

    def to_dict(self):
        return {
            'room_code': self.room_code,
            'players': {pid: p.to_dict() for pid, p in self.players.items()},
            'moves': [m.to_dict() for m in self.moves],
            'winner': self.winner,
            'is_draw': self.is_draw,
            'created_at': self.created_at.isoformat(),
            'finished_at': self.finished_at.isoformat() if self.finished_at else None
        }


@dataclass
class RoomInfo:
    """Room information for lobby display"""
    room_code: str
    player_count: int
    max_players: int
    status: str  # 'WAITING', 'PLAYING', 'FINISHED'
    created_at: datetime

    @property
    def is_full(self) -> bool:
        return self.player_count >= self.max_players

    @property
    def is_joinable(self) -> bool:
        return not self.is_full and self.status == 'WAITING'

    def to_dict(self):
        return {
            'room_code': self.room_code,
            'player_count': self.player_count,
            'max_players': self.max_players,
            'status': self.status,
            'is_full': self.is_full,
            'is_joinable': self.is_joinable,
            'created_at': self.created_at.isoformat()
        }
