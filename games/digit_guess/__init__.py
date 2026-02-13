"""
Digit Guess Game - A 2-player number guessing game (Bulls & Cows / Mastermind)
"""

from .routes import digit_guess_bp
from .socket_events import register_digit_guess_events

__all__ = ['digit_guess_bp', 'register_digit_guess_events']
