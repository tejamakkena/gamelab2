"""Tambola game data models."""

from dataclasses import dataclass, field
from typing import List, Set, Optional
from enum import Enum


class WinType(Enum):
    """Types of wins in Tambola."""
    EARLY_5 = "early_5"
    TOP_LINE = "top_line"
    MIDDLE_LINE = "middle_line"
    BOTTOM_LINE = "bottom_line"
    FULL_HOUSE = "full_house"


@dataclass
class TambolaTicket:
    """Represents a Tambola ticket (3x9 grid with 15 numbers)."""
    ticket_id: str
    player_id: str
    grid: List[List[Optional[int]]]  # 3x9 grid, None for empty cells
    marked: Set[int] = field(default_factory=set)
    
    def mark_number(self, number: int) -> bool:
        """Mark a number on the ticket if it exists."""
        for row in self.grid:
            if number in row:
                self.marked.add(number)
                return True
        return False
    
    def check_win(self, win_type: WinType) -> bool:
        """Check if ticket has achieved the specified win condition."""
        # TODO: Implement win checking logic
        pass


@dataclass
class TambolaGame:
    """Represents a Tambola game session."""
    game_id: str
    host_id: str
    players: dict = field(default_factory=dict)  # player_id -> TambolaTicket
    called_numbers: List[int] = field(default_factory=list)
    available_numbers: Set[int] = field(default_factory=lambda: set(range(1, 91)))
    wins_claimed: dict = field(default_factory=dict)  # WinType -> player_id
    status: str = "waiting"  # waiting, active, finished
