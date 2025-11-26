from flask import Blueprint, render_template, session, jsonify, request
from flask_socketio import emit, join_room
import uuid

snake_ladder_bp = Blueprint('snake_ladder', __name__)

@snake_ladder_bp.route('/')
def index():
    """Snake and Ladder game page"""
    user = session.get('user')
    print("🐍 Snake & Ladder route accessed!")
    print(f"🎮 Snake & Ladder - User: {user}")
    return render_template('games/snake.html', user=user)

@snake_ladder_bp.route('/create', methods=['POST'])
def create_game():
    """Create a new game room"""
    room_code = str(uuid.uuid4())[:6].upper()
    player_id = str(uuid.uuid4())
    # Store game state in database or session
    return jsonify({
        'success': True,
        'room_code': room_code,
        'player_id': player_id
    })

@snake_ladder_bp.route('/join/<room_code>', methods=['POST'])
def join_game(room_code):
    """Join an existing game"""
    player_id = str(uuid.uuid4())
    # Add player to game room
    return jsonify({
        'success': True,
        'player_id': player_id,
        'room_code': room_code
    })

@snake_ladder_bp.route('/roll/<room_code>', methods=['POST'])
def roll_dice(room_code):
    """Handle dice roll"""
    # Implement dice roll logic
    pass