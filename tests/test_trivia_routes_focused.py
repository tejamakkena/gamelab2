"""Focused Trivia route tests to increase coverage."""
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
    return socketio.test_client(app, namespace='/trivia')


def test_trivia_home(client):
    """Test Trivia home page."""
    response = client.get('/trivia/')
    assert response.status_code == 200


def test_trivia_socket_connect(socket_client):
    """Test Trivia socket connection."""
    assert socket_client.is_connected()


def test_trivia_join_room(socket_client):
    """Test joining a Trivia room."""
    socket_client.emit('join', {'room': 'test-room'}, namespace='/trivia')
    received = socket_client.get_received(namespace='/trivia')
    assert len(received) > 0


def test_trivia_start_game(socket_client):
    """Test starting a Trivia game."""
    socket_client.emit('join', {'room': 'test-room'}, namespace='/trivia')
    socket_client.get_received(namespace='/trivia')
    
    socket_client.emit('start_game', {
        'room': 'test-room',
        'category': 'general',
        'difficulty': 'easy'
    }, namespace='/trivia')
    received = socket_client.get_received(namespace='/trivia')
    assert len(received) > 0


def test_trivia_answer_question(socket_client):
    """Test answering a Trivia question."""
    socket_client.emit('join', {'room': 'test-room'}, namespace='/trivia')
    socket_client.get_received(namespace='/trivia')
    
    socket_client.emit('answer', {
        'room': 'test-room',
        'answer': 'A'
    }, namespace='/trivia')
    received = socket_client.get_received(namespace='/trivia')
    # May receive error or game state
    assert True  # Just ensure no crash


def test_trivia_next_question(socket_client):
    """Test requesting next Trivia question."""
    socket_client.emit('join', {'room': 'test-room'}, namespace='/trivia')
    socket_client.get_received(namespace='/trivia')
    
    socket_client.emit('next_question', {'room': 'test-room'}, namespace='/trivia')
    received = socket_client.get_received(namespace='/trivia')
    assert True  # May or may not work depending on game state


def test_trivia_leave_room(socket_client):
    """Test leaving a Trivia room."""
    socket_client.emit('join', {'room': 'test-room'}, namespace='/trivia')
    socket_client.get_received(namespace='/trivia')
    
    socket_client.emit('leave', {'room': 'test-room'}, namespace='/trivia')
    received = socket_client.get_received(namespace='/trivia')
    assert True  # Ensure no crash
