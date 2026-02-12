
from abc import ABC, abstractmethod

class BaseGame(ABC):
    @abstractmethod
    def initialize_game(self):
        pass

    @abstractmethod
    def make_move(self, player, move):
        pass

    @abstractmethod
    def check_game_over(self):
        pass

    @abstractmethod
    def get_game_state(self):
        pass
