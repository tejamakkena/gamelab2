"""
Integration tests for game modules imports and basic functionality
"""
import pytest


class TestGameModuleImports:
    """Test that all game modules can be imported"""
    
    def test_import_connect4_socket_events(self):
        """Test Connect4 socket events can be imported"""
        from games.connect4 import socket_events
        assert hasattr(socket_events, 'register_connect4_events')
        assert hasattr(socket_events, 'check_winner')
        assert hasattr(socket_events, 'generate_room_code')
    
    def test_import_tictactoe_game_logic(self):
        """Test TicTacToe game logic can be imported"""
        from games.tictactoe.game_logic import TicTacToeGame
        game = TicTacToeGame('TEST')
        assert game is not None
    
    def test_import_poker_socket_events(self):
        """Test Poker socket events can be imported"""
        from games.poker import socket_events
        assert hasattr(socket_events, 'register_poker_events')
        assert hasattr(socket_events, 'create_deck')
    
    def test_import_digit_guess_logic(self):
        """Test Digit Guess logic can be imported"""
        from games.digit_guess.game_logic import validate_number, calculate_feedback
        assert callable(validate_number)
        assert callable(calculate_feedback)
    
    def test_import_roulette_socket_events(self):
        """Test Roulette socket events can be imported"""
        from games.roulette import socket_events
        assert hasattr(socket_events, 'register_roulette_events')
    
    def test_import_snake_ladder_socket_events(self):
        """Test Snake Ladder socket events can be imported"""
        from games.snake_ladder import socket_events
        assert hasattr(socket_events, 'register_snake_events')
    
    def test_import_trivia_socket_events(self):
        """Test Trivia socket events can be imported"""
        from games.trivia import socket_events
        assert hasattr(socket_events, 'register_trivia_events')
    
    def test_import_canvas_battle_socket_events(self):
        """Test Canvas Battle socket events can be imported"""
        from games.canvas_battle import socket_events
        assert hasattr(socket_events, 'register_canvas_battle_events')
    
    def test_import_raja_mantri_routes(self):
        """Test Raja Mantri routes can be imported"""
        from games.raja_mantri import routes
        assert hasattr(routes, 'raja_mantri_bp')


class TestGameInitFiles:
    """Test game __init__.py files"""
    
    def test_connect4_init(self):
        """Test Connect4 __init__ exports blueprint"""
        from games.connect4 import connect4_bp
        assert connect4_bp is not None
    
    def test_digit_guess_init(self):
        """Test Digit Guess __init__ exports blueprint"""
        from games.digit_guess import digit_guess_bp
        assert digit_guess_bp is not None


class TestUtilityFunctions:
    """Test utility and helper functions across modules"""
    
    def test_connect4_room_code_format(self):
        """Test Connect4 room code generation format"""
        from games.connect4.socket_events import generate_room_code
        code = generate_room_code()
        assert isinstance(code, str)
        assert len(code) == 6
        assert code.isalnum()
    
    def test_poker_deck_creation(self):
        """Test poker deck is properly created"""
        from games.poker.socket_events import create_deck
        deck = create_deck()
        assert isinstance(deck, list)
        assert len(deck) == 52
        # Verify deck has cards with value and suit
        assert all('value' in card and 'suit' in card for card in deck)
    
    def test_poker_player_data_filtering(self):
        """Test poker public player data hides private info"""
        from games.poker.socket_events import get_public_player_data
        
        players = [{
            'id': 'p1',
            'name': 'Alice',
            'chips': 1000,
            'bet': 50,
            'folded': False,
            'position': 0,
            'hand': [{'value': 'A', 'suit': '♠'}]  # Should be hidden
        }]
        
        public = get_public_player_data(players)
        assert 'hand' not in public[0]
        assert 'name' in public[0]
        assert 'chips' in public[0]
    
    def test_tictactoe_game_state_after_moves(self):
        """Test TicTacToe game state after making moves"""
        from games.tictactoe.game_logic import TicTacToeGame
        
        game = TicTacToeGame('TEST')
        game.add_player('p1')
        game.add_player('p2')
        
        result = game.make_move('p1', 4)  # Center
        assert result['success'] is True
        
        state = game.get_game_state()
        assert state['board'][4] == '⭕'
        assert state['current_turn'] == '❌'
    
    def test_digit_guess_validation_edge_cases(self):
        """Test digit guess validation with edge cases"""
        from games.digit_guess.game_logic import validate_number
        
        # Test various inputs
        valid, _ = validate_number("0000")
        assert valid is True
        
        valid, _ = validate_number("9999")
        assert valid is True
        
        valid, error = validate_number("123")
        assert valid is False
        assert "4 digits" in error
        
        valid, error = validate_number("abcd")
        assert valid is False
        assert "only digits" in error
    
    def test_digit_guess_feedback_various_scenarios(self):
        """Test digit guess feedback in various scenarios"""
        from games.digit_guess.game_logic import calculate_feedback
        
        # Perfect match
        feedback = calculate_feedback("1234", "1234")
        assert feedback['correct_positions'] == 4
        assert feedback['correct_digits'] == 4
        
        # No match
        feedback = calculate_feedback("1234", "5678")
        assert feedback['correct_positions'] == 0
        assert feedback['correct_digits'] == 0
        
        # All digits wrong positions
        feedback = calculate_feedback("1234", "4321")
        assert feedback['correct_positions'] == 0
        assert feedback['correct_digits'] == 4


class TestRouteBlueprints:
    """Test that route blueprints are properly configured"""
    
    def test_connect4_routes_exist(self):
        """Test Connect4 routes module exists"""
        from games.connect4 import routes
        assert hasattr(routes, 'connect4_bp')
    
    def test_digit_guess_routes_exist(self):
        """Test Digit Guess routes module exists"""
        from games.digit_guess import routes
        assert hasattr(routes, 'digit_guess_bp')
    
    def test_tictactoe_routes_exist(self):
        """Test TicTacToe routes module exists"""
        from games.tictactoe import routes
        assert hasattr(routes, 'tictactoe_bp')
    
    def test_poker_routes_exist(self):
        """Test Poker routes module exists"""
        from games.poker import routes
        assert hasattr(routes, 'poker_bp')
    
    def test_roulette_routes_exist(self):
        """Test Roulette routes module exists"""
        from games.roulette import routes
        assert hasattr(routes, 'roulette_bp')
    
    def test_snake_ladder_routes_exist(self):
        """Test Snake Ladder routes module exists"""
        from games.snake_ladder import routes
        assert hasattr(routes, 'snake_ladder_bp')
    
    def test_trivia_routes_exist(self):
        """Test Trivia routes module exists"""
        from games.trivia import routes
        assert hasattr(routes, 'trivia_bp')
    
    def test_raja_mantri_routes_exist(self):
        """Test Raja Mantri routes module exists"""
        from games.raja_mantri import routes
        assert hasattr(routes, 'raja_mantri_bp')
    
    def test_canvas_battle_routes_exist(self):
        """Test Canvas Battle routes module exists"""
        from games.canvas_battle import routes
        assert hasattr(routes, 'canvas_battle_bp')


class TestGameLogicConsistency:
    """Test consistency across game modules"""
    
    def test_all_socket_event_modules_have_register_function(self):
        """Test all socket event modules have register functions"""
        modules_and_functions = [
            ('games.connect4.socket_events', 'register_connect4_events'),
            ('games.poker.socket_events', 'register_poker_events'),
            ('games.roulette.socket_events', 'register_roulette_events'),
            ('games.snake_ladder.socket_events', 'register_snake_events'),
            ('games.trivia.socket_events', 'register_trivia_events'),
            ('games.canvas_battle.socket_events', 'register_canvas_battle_events'),
        ]
        
        for module_name, function_name in modules_and_functions:
            module = __import__(module_name, fromlist=[function_name])
            assert hasattr(module, function_name), f"{module_name} missing {function_name}"
            assert callable(getattr(module, function_name))
    
    def test_tictactoe_complete_game_flow(self):
        """Test a complete TicTacToe game from start to finish"""
        from games.tictactoe.game_logic import TicTacToeGame
        
        game = TicTacToeGame('TEST')
        
        # Add players
        game.add_player('player1')
        game.add_player('player2')
        assert game.state == "PLAYING"
        
        # Play a winning game
        # ⭕ wins with diagonal
        game.make_move('player1', 0)  # ⭕
        game.make_move('player2', 1)  # ❌
        game.make_move('player1', 4)  # ⭕
        game.make_move('player2', 2)  # ❌
        result = game.make_move('player1', 8)  # ⭕ wins diagonal
        
        assert game.winner == '⭕'
        assert game.state == "FINISHED"
    
    def test_connect4_win_detection_all_directions(self):
        """Test Connect4 detects wins in all directions"""
        from games.connect4.socket_events import check_winner
        
        # Test horizontal
        board_h = [[None for _ in range(7)] for _ in range(6)]
        for i in range(4):
            board_h[5][i] = 'red'
        winner, _ = check_winner(board_h)
        assert winner == 'red'
        
        # Test vertical
        board_v = [[None for _ in range(7)] for _ in range(6)]
        for i in range(4):
            board_v[i+2][3] = 'yellow'
        winner, _ = check_winner(board_v)
        assert winner == 'yellow'
        
        # Test diagonal
        board_d = [[None for _ in range(7)] for _ in range(6)]
        for i in range(4):
            board_d[i+2][i] = 'red'
        winner, _ = check_winner(board_d)
        assert winner == 'red'
