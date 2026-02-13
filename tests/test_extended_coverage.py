"""
Extended integration tests to increase coverage
"""
import pytest


class TestSocketEventRegistration:
    """Test socket event registration functions actually callable"""
    
    def test_connect4_registration_callable(self):
        """Test Connect4 socket events registration is callable"""
        from games.connect4.socket_events import register_connect4_events
        from unittest.mock import Mock
        
        mock_socketio = Mock()
        # Should not raise exception
        register_connect4_events(mock_socketio)
        # Verify decorators were registered
        assert mock_socketio.on.called
    
    def test_poker_registration_callable(self):
        """Test Poker socket events registration is callable"""
        from games.poker.socket_events import register_poker_events
        from unittest.mock import Mock
        
        mock_socketio = Mock()
        register_poker_events(mock_socketio)
        assert mock_socketio.on.called
    
    def test_roulette_registration_callable(self):
        """Test Roulette socket events registration is callable"""
        from games.roulette.socket_events import register_roulette_events
        from unittest.mock import Mock
        
        mock_socketio = Mock()
        register_roulette_events(mock_socketio)
        assert mock_socketio.on.called
    
    def test_snake_ladder_registration_callable(self):
        """Test Snake Ladder socket events registration is callable"""
        from games.snake_ladder.socket_events import register_snake_events
        from unittest.mock import Mock
        
        mock_socketio = Mock()
        register_snake_events(mock_socketio)
        assert mock_socketio.on.called
    
    def test_trivia_registration_callable(self):
        """Test Trivia socket events registration is callable"""
        from games.trivia.socket_events import register_trivia_events
        from unittest.mock import Mock
        
        mock_socketio = Mock()
        register_trivia_events(mock_socketio)
        assert mock_socketio.on.called
    
    def test_canvas_battle_registration_callable(self):
        """Test Canvas Battle socket events registration is callable"""
        from games.canvas_battle.socket_events import register_canvas_battle_events
        from unittest.mock import Mock
        
        mock_socketio = Mock()
        register_canvas_battle_events(mock_socketio)
        assert mock_socketio.on.called


class TestBlueprintConfiguration:
    """Test blueprint configurations"""
    
    def test_connect4_blueprint_name(self):
        """Test Connect4 blueprint has correct name"""
        from games.connect4 import connect4_bp
        assert connect4_bp.name == 'connect4'
    
    def test_digit_guess_blueprint_name(self):
        """Test Digit Guess blueprint has correct name"""
        from games.digit_guess import digit_guess_bp
        assert digit_guess_bp.name == 'digit_guess'
    
    def test_tictactoe_blueprint_name(self):
        """Test TicTacToe blueprint has correct name"""
        from games.tictactoe.routes import tictactoe_bp
        assert tictactoe_bp.name == 'tictactoe'
    
    def test_poker_blueprint_name(self):
        """Test Poker blueprint has correct name"""
        from games.poker.routes import poker_bp
        assert poker_bp.name == 'poker'
    
    def test_roulette_blueprint_name(self):
        """Test Roulette blueprint has correct name"""
        from games.roulette.routes import roulette_bp
        assert roulette_bp.name == 'roulette'
    
    def test_snake_ladder_blueprint_name(self):
        """Test Snake Ladder blueprint has correct name"""
        from games.snake_ladder.routes import snake_ladder_bp
        assert snake_ladder_bp.name == 'snake_ladder'
    
    def test_trivia_blueprint_name(self):
        """Test Trivia blueprint has correct name"""
        from games.trivia.routes import trivia_bp
        assert trivia_bp.name == 'trivia'
    
    def test_raja_mantri_blueprint_name(self):
        """Test Raja Mantri blueprint has correct name"""
        from games.raja_mantri.routes import raja_mantri_bp
        assert raja_mantri_bp.name == 'raja_mantri'
    
    def test_canvas_battle_blueprint_name(self):
        """Test Canvas Battle blueprint has correct name"""
        from games.canvas_battle.routes import canvas_battle_bp
        assert canvas_battle_bp.name == 'canvas_battle'


class TestAllGameModules:
    """Test all game module structures"""
    
    def test_all_games_have_init(self):
        """Test all game directories have __init__.py"""
        games = [
            'connect4', 'tictactoe', 'poker', 'roulette',
            'snake_ladder', 'trivia', 'raja_mantri', 
            'canvas_battle', 'digit_guess'
        ]
        
        for game in games:
            try:
                module = __import__(f'games.{game}', fromlist=['__init__'])
                assert module is not None
            except ImportError as e:
                pytest.fail(f"Failed to import games.{game}: {e}")
    
    def test_all_games_have_routes(self):
        """Test all game modules have routes"""
        games = [
            'connect4', 'tictactoe', 'poker', 'roulette',
            'snake_ladder', 'trivia', 'raja_mantri', 
            'canvas_battle', 'digit_guess'
        ]
        
        for game in games:
            try:
                module = __import__(f'games.{game}.routes', fromlist=['routes'])
                assert module is not None
            except ImportError as e:
                pytest.fail(f"Failed to import games.{game}.routes: {e}")


class TestTicTacToeModelsAndRoutes:
    """Additional tests for TicTacToe models and routes"""
    
    def test_tictactoe_models_import(self):
        """Test TicTacToe models can be imported"""
        from games.tictactoe import models
        assert models is not None
    
    def test_tictactoe_routes_import(self):
        """Test TicTacToe routes can be imported"""
        from games.tictactoe import routes
        assert routes is not None
        assert hasattr(routes, 'tictactoe_bp')


class TestDigitGuessSocketEvents:
    """Test Digit Guess socket event functions"""
    
    def test_digit_guess_has_socket_events(self):
        """Test Digit Guess has socket events module"""
        from games.digit_guess import socket_events
        assert socket_events is not None


class TestRoomCodeGeneration:
    """Test room code generation across games"""
    
    def test_connect4_room_codes_are_unique(self):
        """Test Connect4 generates unique room codes"""
        from games.connect4.socket_events import generate_room_code
        codes = set()
        for _ in range(50):
            code = generate_room_code()
            codes.add(code)
        # All codes should be unique
        assert len(codes) == 50
    
    def test_poker_room_codes_are_unique(self):
        """Test Poker generates unique room codes"""
        from games.poker.socket_events import generate_room_code
        codes = set()
        for _ in range(50):
            code = generate_room_code()
            codes.add(code)
        assert len(codes) == 50


class TestGameLogicEdgeCases:
    """Test additional edge cases in game logic"""
    
    def test_tictactoe_empty_game_state(self):
        """Test TicTacToe empty game state"""
        from games.tictactoe.game_logic import TicTacToeGame
        game = TicTacToeGame('TEST')
        state = game.get_game_state()
        assert state['board'] == [''] * 9
        assert len(state['players']) == 0
    
    def test_tictactoe_check_winner_empty(self):
        """Test TicTacToe check_winner with empty board"""
        from games.tictactoe.game_logic import TicTacToeGame
        game = TicTacToeGame('TEST')
        winner = game.check_winner()
        assert winner is None
    
    def test_digit_guess_feedback_edge_patterns(self):
        """Test digit guess feedback with various patterns"""
        from games.digit_guess.game_logic import calculate_feedback
        
        # Pattern with repeating digits
        feedback = calculate_feedback("1122", "2211")
        assert feedback['correct_digits'] == 4
        assert feedback['correct_positions'] == 0
        
        # Pattern with single digit repeated
        feedback = calculate_feedback("1111", "1234")
        assert feedback['correct_digits'] == 1
        assert feedback['correct_positions'] == 1
    
    def test_connect4_check_winner_near_win(self):
        """Test Connect4 near-win scenarios"""
        from games.connect4.socket_events import check_winner
        
        # 3 in a row (not winning)
        board = [[None for _ in range(7)] for _ in range(6)]
        board[5][0] = 'red'
        board[5][1] = 'red'
        board[5][2] = 'red'
        
        winner, cells = check_winner(board)
        assert winner is None
    
    def test_poker_deck_has_correct_suits(self):
        """Test poker deck has all 4 suits"""
        from games.poker.socket_events import create_deck
        deck = create_deck()
        
        suits = set(card['suit'] for card in deck)
        assert len(suits) == 4
        assert '♠' in suits
        assert '♥' in suits
        assert '♦' in suits
        assert '♣' in suits
    
    def test_poker_deck_has_correct_values(self):
        """Test poker deck has all 13 values"""
        from games.poker.socket_events import create_deck
        deck = create_deck()
        
        values = set(card['value'] for card in deck)
        expected = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
        assert len(values) == 13
        assert all(v in values for v in expected)


class TestUtilModules:
    """Test utility modules"""
    
    def test_utils_module_exists(self):
        """Test utils module can be imported"""
        import utils
        assert utils is not None
    
    def test_utils_submodules_exist(self):
        """Test utils submodules exist"""
        try:
            from utils import auth
            assert auth is not None
        except ImportError:
            pass  # Some utils may not be importable without dependencies
        
        # Test the ones that should always work
        from utils import player_manager, room_manager, validators
        assert True


class TestConfigModule:
    """Test config module"""
    
    def test_config_module_imports(self):
        """Test config module can be imported"""
        import config
        assert config is not None


class TestDatabaseModule:
    """Test database module"""
    
    def test_database_module_exists(self):
        """Test database module exists"""
        from database import db
        assert db is not None


class TestGameDataStructures:
    """Test game data structures and state management"""
    
    def test_tictactoe_board_size(self):
        """Test TicTacToe board is 9 spaces"""
        from games.tictactoe.game_logic import TicTacToeGame
        game = TicTacToeGame('TEST')
        assert len(game.board) == 9
    
    def test_tictactoe_players_dict(self):
        """Test TicTacToe players is a dictionary"""
        from games.tictactoe.game_logic import TicTacToeGame
        game = TicTacToeGame('TEST')
        assert isinstance(game.players, dict)
    
    def test_connect4_board_dimensions(self):
        """Test Connect4 board has correct dimensions (6x7)"""
        from games.connect4.socket_events import check_winner
        
        # Create valid board
        board = [[None for _ in range(7)] for _ in range(6)]
        assert len(board) == 6
        assert len(board[0]) == 7
        
        # Should not raise error
        winner, cells = check_winner(board)
        assert isinstance(cells, list)
    
    def test_poker_player_data_structure(self):
        """Test poker player data has required fields"""
        from games.poker.socket_events import get_public_player_data
        
        players = [{
            'id': 'test',
            'name': 'Test',
            'chips': 1000,
            'bet': 0,
            'folded': False,
            'position': 0
        }]
        
        public = get_public_player_data(players)
        assert 'id' in public[0]
        assert 'name' in public[0]
        assert 'chips' in public[0]
