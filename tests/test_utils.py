"""Comprehensive tests for utility modules"""
import pytest
from unittest.mock import Mock, patch, MagicMock
import logging
from io import StringIO


class TestAuthModule:
    """Tests for utils/auth.py"""
    
    @pytest.mark.skip(reason="flask_login not installed in test environment")
    def test_user_creation(self):
        """Test User class instantiation"""
        from utils.auth import User
        user = User('testuser', 'password123')
        assert user.id == 'testuser'
        assert user.password_hash is not None
        assert user.password_hash != 'password123'  # Should be hashed
        
    @pytest.mark.skip(reason="flask_login not installed in test environment")
    def test_user_password_hashing(self):
        """Test that password is properly hashed"""
        from utils.auth import User
        user = User('testuser', 'mypassword')
        assert len(user.password_hash) > 20  # Hashed password should be long
        
    @pytest.mark.skip(reason="flask_login not installed in test environment")
    def test_user_check_password_correct(self):
        """Test password verification with correct password"""
        from utils.auth import User
        user = User('testuser', 'correct_password')
        assert user.check_password('correct_password') is True
        
    @pytest.mark.skip(reason="flask_login not installed in test environment")
    def test_user_check_password_incorrect(self):
        """Test password verification with incorrect password"""
        from utils.auth import User
        user = User('testuser', 'correct_password')
        assert user.check_password('wrong_password') is False
        
    @pytest.mark.skip(reason="flask_login not installed in test environment")
    def test_user_is_instance_of_usermixin(self):
        """Test that User inherits from UserMixin"""
        from utils.auth import User
        from flask_login import UserMixin
        user = User('testuser', 'password')
        assert isinstance(user, UserMixin)
        
    @pytest.mark.skip(reason="flask_login not installed in test environment")
    def test_init_login_manager(self):
        """Test login manager initialization"""
        from utils.auth import init_login_manager
        from flask import Flask
        
        app = Flask(__name__)
        app.config['SECRET_KEY'] = 'test-secret'
        
        login_manager = init_login_manager(app)
        assert login_manager is not None
        assert login_manager.login_view == 'login'
        
    @pytest.mark.skip(reason="flask_login not installed in test environment")
    def test_user_loader_function_exists(self):
        """Test that user_loader function is registered"""
        from utils.auth import init_login_manager
        from flask import Flask
        
        app = Flask(__name__)
        app.config['SECRET_KEY'] = 'test-secret'
        
        login_manager = init_login_manager(app)
        # User loader should be registered
        assert login_manager.user_loader is not None
        
    @pytest.mark.skip(reason="flask_login not installed in test environment")
    def test_load_user_returns_none(self):
        """Test that load_user returns None (not implemented)"""
        from utils.auth import init_login_manager
        from flask import Flask
        
        app = Flask(__name__)
        app.config['SECRET_KEY'] = 'test-secret'
        
        with app.app_context():
            login_manager = init_login_manager(app)
            # Call the user_loader callback
            result = login_manager.user_callback('test_user_id')
            assert result is None  # Currently not implemented


class TestLoggingConfig:
    """Tests for utils/logging_config.py"""
    
    def test_setup_logging_adds_handler(self):
        """Test that setup_logging adds handler to app"""
        from utils.logging_config import setup_logging
        from flask import Flask
        
        app = Flask(__name__)
        initial_handlers = len(app.logger.handlers)
        
        setup_logging(app)
        
        # Should have added at least one handler
        assert len(app.logger.handlers) > initial_handlers
        
    def test_setup_logging_sets_log_level(self):
        """Test that setup_logging sets INFO log level"""
        from utils.logging_config import setup_logging
        from flask import Flask
        
        app = Flask(__name__)
        setup_logging(app)
        
        assert app.logger.level == logging.INFO
        
    def test_setup_logging_adds_rotating_file_handler(self):
        """Test that setup_logging adds RotatingFileHandler"""
        from utils.logging_config import setup_logging
        from flask import Flask
        from logging.handlers import RotatingFileHandler
        
        app = Flask(__name__)
        setup_logging(app)
        
        # Check if any handler is a RotatingFileHandler
        has_rotating_handler = any(
            isinstance(h, RotatingFileHandler) for h in app.logger.handlers
        )
        assert has_rotating_handler
        
    def test_logging_handler_format(self):
        """Test that logging handler has correct format"""
        from utils.logging_config import setup_logging
        from flask import Flask
        from logging.handlers import RotatingFileHandler
        
        app = Flask(__name__)
        setup_logging(app)
        
        # Find the RotatingFileHandler
        rotating_handler = None
        for handler in app.logger.handlers:
            if isinstance(handler, RotatingFileHandler):
                rotating_handler = handler
                break
        
        assert rotating_handler is not None
        assert rotating_handler.formatter is not None
        
    def test_logging_handler_level(self):
        """Test that logging handler has INFO level"""
        from utils.logging_config import setup_logging
        from flask import Flask
        from logging.handlers import RotatingFileHandler
        
        app = Flask(__name__)
        setup_logging(app)
        
        # Find the RotatingFileHandler
        for handler in app.logger.handlers:
            if isinstance(handler, RotatingFileHandler):
                assert handler.level == logging.INFO
                break


class TestBaseGame:
    """Tests for games/base_game.py"""
    
    def test_base_game_is_abstract(self):
        """Test that BaseGame is an abstract base class"""
        from games.base_game import BaseGame
        from abc import ABC
        
        assert issubclass(BaseGame, ABC)
        
    def test_base_game_cannot_be_instantiated(self):
        """Test that BaseGame cannot be instantiated directly"""
        from games.base_game import BaseGame
        
        with pytest.raises(TypeError):
            BaseGame()
            
    def test_base_game_requires_initialize_game(self):
        """Test that BaseGame requires initialize_game implementation"""
        from games.base_game import BaseGame
        
        class IncompleteGame(BaseGame):
            def make_move(self, player, move):
                pass
            def check_game_over(self):
                pass
            def get_game_state(self):
                pass
        
        with pytest.raises(TypeError):
            IncompleteGame()
            
    def test_base_game_requires_make_move(self):
        """Test that BaseGame requires make_move implementation"""
        from games.base_game import BaseGame
        
        class IncompleteGame(BaseGame):
            def initialize_game(self):
                pass
            def check_game_over(self):
                pass
            def get_game_state(self):
                pass
        
        with pytest.raises(TypeError):
            IncompleteGame()
            
    def test_base_game_requires_check_game_over(self):
        """Test that BaseGame requires check_game_over implementation"""
        from games.base_game import BaseGame
        
        class IncompleteGame(BaseGame):
            def initialize_game(self):
                pass
            def make_move(self, player, move):
                pass
            def get_game_state(self):
                pass
        
        with pytest.raises(TypeError):
            IncompleteGame()
            
    def test_base_game_requires_get_game_state(self):
        """Test that BaseGame requires get_game_state implementation"""
        from games.base_game import BaseGame
        
        class IncompleteGame(BaseGame):
            def initialize_game(self):
                pass
            def make_move(self, player, move):
                pass
            def check_game_over(self):
                pass
        
        with pytest.raises(TypeError):
            IncompleteGame()
            
    def test_base_game_complete_implementation(self):
        """Test that complete implementation can be instantiated"""
        from games.base_game import BaseGame
        
        class CompleteGame(BaseGame):
            def initialize_game(self):
                return "initialized"
            
            def make_move(self, player, move):
                return True
            
            def check_game_over(self):
                return False
            
            def get_game_state(self):
                return {"state": "playing"}
        
        game = CompleteGame()
        assert game.initialize_game() == "initialized"
        assert game.make_move("player1", "move1") is True
        assert game.check_game_over() is False
        assert game.get_game_state() == {"state": "playing"}
        
    def test_base_game_methods_are_abstract(self):
        """Test that all required methods are marked as abstract"""
        from games.base_game import BaseGame
        import inspect
        
        abstract_methods = BaseGame.__abstractmethods__
        assert 'initialize_game' in abstract_methods
        assert 'make_move' in abstract_methods
        assert 'check_game_over' in abstract_methods
        assert 'get_game_state' in abstract_methods


class TestUtilityModulesIntegration:
    """Integration tests for utility modules"""
    
    def test_logging_and_base_game_modules_importable(self):
        """Test that utility modules can be imported"""
        import utils.logging_config
        from games import base_game
        
        assert utils.logging_config is not None
        assert base_game is not None


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
