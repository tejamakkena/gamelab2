from abc import ABC, abstractmethod

class BaseGame(ABC):
    """Base class for all games"""

    def __init__(self, room_code):
        self.room_code = room_code
        self.players = {}
        self.state = "WAITING"

    @abstractmethod
    def initialize_game(self):
        """Initialize game state"""
        pass

    @abstractmethod
    def make_move(self, player_id, move_data):
        """Process a player's move"""
        pass

    @abstractmethod
    def check_winner(self):
        """Check if there's a winner"""
        pass

    @abstractmethod
    def get_game_state(self):
        """Get current game state"""
        pass
