"""Tambola game logic and ticket generation."""

import random
from typing import List, Optional
from .models import TambolaTicket, TambolaGame, WinType


def generate_ticket(ticket_id: str, player_id: str) -> TambolaTicket:
    """
    Generate a valid Tambola ticket.
    - 3 rows x 9 columns
    - 15 numbers total (5 per row)
    - Column ranges: 0=1-9, 1=10-19, 2=20-29, ..., 8=80-90
    - Numbers sorted within columns
    """
    grid = [[None] * 9 for _ in range(3)]
    
    # Determine which cells get numbers (5 per row)
    for row in range(3):
        cols_with_numbers = random.sample(range(9), 5)
        for col in cols_with_numbers:
            # Generate number for this column range
            if col == 0:
                num_range = range(1, 10)
            elif col == 8:
                num_range = range(80, 91)
            else:
                num_range = range(col * 10, col * 10 + 10)
            
            # Pick a number not already used in this column
            available = [n for n in num_range if all(
                grid[r][col] != n for r in range(3)
            )]
            grid[row][col] = random.choice(available)
    
    # Sort numbers within each column
    for col in range(9):
        col_numbers = [grid[row][col] for row in range(3) if grid[row][col] is not None]
        col_numbers.sort()
        idx = 0
        for row in range(3):
            if grid[row][col] is not None:
                grid[row][col] = col_numbers[idx]
                idx += 1
    
    return TambolaTicket(ticket_id=ticket_id, player_id=player_id, grid=grid)


def call_next_number(game: TambolaGame) -> Optional[int]:
    """Call the next random number in the game."""
    if not game.available_numbers:
        return None
    
    number = random.choice(list(game.available_numbers))
    game.available_numbers.remove(number)
    game.called_numbers.append(number)
    return number


def verify_win(game: TambolaGame, player_id: str, win_type: WinType) -> bool:
    """Verify if a player's claim for a win type is valid."""
    if player_id not in game.players:
        return False
    
    ticket = game.players[player_id]
    
    if win_type == WinType.EARLY_5:
        return len(ticket.marked) >= 5
    
    elif win_type == WinType.TOP_LINE:
        return all(num in ticket.marked for num in ticket.grid[0] if num is not None)
    
    elif win_type == WinType.MIDDLE_LINE:
        return all(num in ticket.marked for num in ticket.grid[1] if num is not None)
    
    elif win_type == WinType.BOTTOM_LINE:
        return all(num in ticket.marked for num in ticket.grid[2] if num is not None)
    
    elif win_type == WinType.FULL_HOUSE:
        all_numbers = [num for row in ticket.grid for num in row if num is not None]
        return all(num in ticket.marked for num in all_numbers)
    
    return False
