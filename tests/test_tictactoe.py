"""
Test suite for TicTacToe game logic
"""
import pytest
from games.tictactoe.game_logic import TicTacToeGame


class TestTicTacToeInitialization:
    """Test game initialization"""
    
    def test_game_initialization(self):
        """Test that game initializes correctly"""
        game = TicTacToeGame('TEST123')
        
        assert game.room_code == 'TEST123'
        assert game.board == [''] * 9
        assert game.current_turn == '⭕'
        assert game.winner is None
        assert game.is_draw is False
        assert game.state == "WAITING"
        assert game.players == {}
    
    def test_initialize_game_resets_state(self):
        """Test that initialize_game resets state"""
        game = TicTacToeGame('TEST123')
        game.board[0] = '⭕'
        game.winner = '⭕'
        game.is_draw = True
        
        game.initialize_game()
        
        assert game.board == [''] * 9
        assert game.winner is None
        assert game.is_draw is False


class TestTicTacToePlayerManagement:
    """Test player management"""
    
    def test_add_first_player(self):
        """Test adding first player gets circle"""
        game = TicTacToeGame('TEST123')
        
        symbol = game.add_player('player1')
        
        assert symbol == '⭕'
        assert game.players['player1'] == '⭕'
        assert game.state == "WAITING"
    
    def test_add_second_player(self):
        """Test adding second player gets X and starts game"""
        game = TicTacToeGame('TEST123')
        
        game.add_player('player1')
        symbol = game.add_player('player2')
        
        assert symbol == '❌'
        assert game.players['player2'] == '❌'
        assert game.state == "PLAYING"
    
    def test_add_third_player_returns_none(self):
        """Test adding third player returns None"""
        game = TicTacToeGame('TEST123')
        
        game.add_player('player1')
        game.add_player('player2')
        symbol = game.add_player('player3')
        
        assert symbol is None


class TestTicTacToeMoves:
    """Test move validation and execution"""
    
    def test_valid_move(self):
        """Test making a valid move"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        result = game.make_move('player1', 0)
        
        assert result['success'] is True
        assert game.board[0] == '⭕'
        assert game.current_turn == '❌'
    
    def test_invalid_move_not_players_turn(self):
        """Test move by player when not their turn"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        result = game.make_move('player2', 0)
        
        assert result['success'] is False
        assert 'Not your turn' in result['error']
    
    def test_invalid_move_position_taken(self):
        """Test move to already occupied position"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 0)
        result = game.make_move('player2', 0)
        
        assert result['success'] is False
        assert 'Position already taken' in result['error']
    
    def test_invalid_move_game_over(self):
        """Test move after game is over"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.winner = '⭕'
        result = game.make_move('player1', 0)
        
        assert result['success'] is False
        assert 'Game over' in result['error']
    
    def test_turn_alternation(self):
        """Test that turns alternate between players"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        assert game.current_turn == '⭕'
        game.make_move('player1', 0)
        assert game.current_turn == '❌'
        game.make_move('player2', 1)
        assert game.current_turn == '⭕'


class TestTicTacToeWinConditions:
    """Test all win conditions"""
    
    def test_horizontal_win_top_row(self):
        """Test win on top row (positions 0, 1, 2)"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 0)  # ⭕
        game.make_move('player2', 3)  # ❌
        game.make_move('player1', 1)  # ⭕
        game.make_move('player2', 4)  # ❌
        result = game.make_move('player1', 2)  # ⭕ wins
        
        assert game.winner == '⭕'
        assert game.state == "FINISHED"
        assert result['success'] is True
    
    def test_horizontal_win_middle_row(self):
        """Test win on middle row (positions 3, 4, 5)"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 3)  # ⭕
        game.make_move('player2', 0)  # ❌
        game.make_move('player1', 4)  # ⭕
        game.make_move('player2', 1)  # ❌
        result = game.make_move('player1', 5)  # ⭕ wins
        
        assert game.winner == '⭕'
        assert game.state == "FINISHED"
    
    def test_horizontal_win_bottom_row(self):
        """Test win on bottom row (positions 6, 7, 8)"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 6)  # ⭕
        game.make_move('player2', 0)  # ❌
        game.make_move('player1', 7)  # ⭕
        game.make_move('player2', 1)  # ❌
        result = game.make_move('player1', 8)  # ⭕ wins
        
        assert game.winner == '⭕'
    
    def test_vertical_win_left_column(self):
        """Test win on left column (positions 0, 3, 6)"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 0)  # ⭕
        game.make_move('player2', 1)  # ❌
        game.make_move('player1', 3)  # ⭕
        game.make_move('player2', 2)  # ❌
        result = game.make_move('player1', 6)  # ⭕ wins
        
        assert game.winner == '⭕'
        assert game.state == "FINISHED"
    
    def test_vertical_win_middle_column(self):
        """Test win on middle column (positions 1, 4, 7)"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 1)  # ⭕
        game.make_move('player2', 0)  # ❌
        game.make_move('player1', 4)  # ⭕
        game.make_move('player2', 2)  # ❌
        result = game.make_move('player1', 7)  # ⭕ wins
        
        assert game.winner == '⭕'
    
    def test_vertical_win_right_column(self):
        """Test win on right column (positions 2, 5, 8)"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 2)  # ⭕
        game.make_move('player2', 0)  # ❌
        game.make_move('player1', 5)  # ⭕
        game.make_move('player2', 1)  # ❌
        result = game.make_move('player1', 8)  # ⭕ wins
        
        assert game.winner == '⭕'
    
    def test_diagonal_win_top_left_to_bottom_right(self):
        """Test win on diagonal (positions 0, 4, 8)"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 0)  # ⭕
        game.make_move('player2', 1)  # ❌
        game.make_move('player1', 4)  # ⭕
        game.make_move('player2', 2)  # ❌
        result = game.make_move('player1', 8)  # ⭕ wins
        
        assert game.winner == '⭕'
        assert game.state == "FINISHED"
    
    def test_diagonal_win_top_right_to_bottom_left(self):
        """Test win on diagonal (positions 2, 4, 6)"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 2)  # ⭕
        game.make_move('player2', 0)  # ❌
        game.make_move('player1', 4)  # ⭕
        game.make_move('player2', 1)  # ❌
        result = game.make_move('player1', 6)  # ⭕ wins
        
        assert game.winner == '⭕'
    
    def test_player2_win(self):
        """Test that player 2 (X) can also win"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 0)  # ⭕
        game.make_move('player2', 3)  # ❌
        game.make_move('player1', 1)  # ⭕
        game.make_move('player2', 4)  # ❌
        game.make_move('player1', 6)  # ⭕
        result = game.make_move('player2', 5)  # ❌ wins
        
        assert game.winner == '❌'
        assert game.state == "FINISHED"


class TestTicTacToeDraw:
    """Test draw conditions"""
    
    def test_draw_game(self):
        """Test that game detects draw when board is full"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        # Create a draw scenario
        # ⭕ ❌ ⭕
        # ❌ ❌ ⭕
        # ⭕ ⭕ ❌
        moves = [
            ('player1', 0),  # ⭕
            ('player2', 1),  # ❌
            ('player1', 2),  # ⭕
            ('player2', 3),  # ❌
            ('player1', 5),  # ⭕
            ('player2', 4),  # ❌
            ('player1', 6),  # ⭕
            ('player2', 8),  # ❌
            ('player1', 7),  # ⭕ - draw
        ]
        
        for player, position in moves[:-1]:
            game.make_move(player, position)
        
        result = game.make_move('player1', 7)
        
        assert game.is_draw is True
        assert game.winner is None
        assert game.state == "FINISHED"
        assert result['success'] is True


class TestTicTacToeGameState:
    """Test game state retrieval"""
    
    def test_get_game_state(self):
        """Test that game state is correctly retrieved"""
        game = TicTacToeGame('TEST123')
        game.add_player('player1')
        game.add_player('player2')
        
        game.make_move('player1', 0)
        state = game.get_game_state()
        
        assert state['board'][0] == '⭕'
        assert state['current_turn'] == '❌'
        assert state['winner'] is None
        assert state['is_draw'] is False
        assert state['state'] == "PLAYING"
        assert 'player1' in state['players']
        assert 'player2' in state['players']
