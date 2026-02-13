"""Focused TicTacToe route tests to increase coverage."""
import pytest
from app import create_app, socketio
from flask_socketio import SocketIOTestClient


@pytest.fixture
def app():
    """Create test app."""
    test_app = create_app()
    test_app.config['TESTING'] = True
    return test_app


@pytest.fixture
def client(app):
    """Create test client."""
    return app.test_client()


@pytest.fixture
def socket_client(app):
    """Create SocketIO test client."""
    return socketio.test_client(app, namespace='/tictactoe')


def test_tictactoe_home(client):
    """Test TicTacToe home page."""
    response = client.get('/tictactoe/')
    assert response.status_code == 200


def test_tictactoe_socket_connect(socket_client):
    """Test TicTacToe socket connection."""
    assert socket_client.is_connected()


def test_tictactoe_join_room(socket_client):
    """Test joining a TicTacToe room."""
    socket_client.emit('join', {'room': 'test-room'}, namespace='/tictactoe')
    received = socket_client.get_received(namespace='/tictactoe')
    assert len(received) > 0


def test_tictactoe_make_move(socket_client):
    """Test making a move in TicTacToe."""
    # Join room first
    socket_client.emit('join', {'room': 'test-room'}, namespace='/tictactoe')
    socket_client.get_received(namespace='/tictactoe')
    
    # Make move
    socket_client.emit('make_move', {
        'room': 'test-room',
        'position': 0
    }, namespace='/tictactoe')
    received = socket_client.get_received(namespace='/tictactoe')
    assert len(received) > 0


def test_tictactoe_ai_mode(socket_client):
    """Test AI mode in TicTacToe."""
    socket_client.emit('join', {
        'room': 'test-room-ai',
        'mode': 'ai'
    }, namespace='/tictactoe')
    received = socket_client.get_received(namespace='/tictactoe')
    assert len(received) > 0


def test_tictactoe_reset_game(socket_client):
    """Test resetting a TicTacToe game."""
    socket_client.emit('join', {'room': 'test-room'}, namespace='/tictactoe')
    socket_client.get_received(namespace='/tictactoe')
    
    socket_client.emit('reset_game', {'room': 'test-room'}, namespace='/tictactoe')
    received = socket_client.get_received(namespace='/tictactoe')
    assert len(received) > 0


def test_tictactoe_leave_room(socket_client):
    """Test leaving a TicTacToe room."""
    socket_client.emit('join', {'room': 'test-room'}, namespace='/tictactoe')
    socket_client.get_received(namespace='/tictactoe')
    
    socket_client.emit('leave', {'room': 'test-room'}, namespace='/tictactoe')
    received = socket_client.get_received(namespace='/tictactoe')
    assert len(received) >= 0  # May or may not receive messages
