"""Tambola game HTTP routes."""

from flask import render_template, jsonify, request
from . import tambola_bp
from .game_logic import generate_ticket, verify_win
from .models import TambolaGame, WinType
import uuid

# In-memory game storage shared with socket_events
active_games = {}


@tambola_bp.route('/')
def index():
    """Render the Tambola game page."""
    return render_template('tambola/game.html')


@tambola_bp.route('/create', methods=['POST'])
def create_game():
    """Create a new Tambola game."""
    data = request.get_json() or {}
    player_name = data.get('player_name', 'Host')

    game_id = uuid.uuid4().hex[:6].upper()
    player_id = uuid.uuid4().hex[:8]

    ticket = generate_ticket(ticket_id=uuid.uuid4().hex[:8], player_id=player_id)
    game = TambolaGame(game_id=game_id, host_id=player_id)
    game.players[player_id] = ticket
    active_games[game_id] = game

    return jsonify({
        'status': 'ok',
        'game_id': game_id,
        'player_id': player_id,
        'ticket': {'grid': ticket.grid},
        'is_host': True
    })


@tambola_bp.route('/join/<game_id>', methods=['POST'])
def join_game(game_id):
    """Join an existing Tambola game."""
    data = request.get_json() or {}
    game_id = game_id.upper()

    if game_id not in active_games:
        return jsonify({'status': 'error', 'message': 'Game not found'}), 404

    game = active_games[game_id]

    if game.status != 'waiting':
        return jsonify({'status': 'error', 'message': 'Game already started'}), 400

    player_id = uuid.uuid4().hex[:8]
    ticket = generate_ticket(ticket_id=uuid.uuid4().hex[:8], player_id=player_id)
    game.players[player_id] = ticket

    return jsonify({
        'status': 'ok',
        'game_id': game_id,
        'player_id': player_id,
        'ticket': {'grid': ticket.grid},
        'is_host': False
    })


@tambola_bp.route('/claim', methods=['POST'])
def claim_win():
    """Claim a win (Early 5, Line, Full House)."""
    data = request.get_json() or {}
    game_id = data.get('game_id', '').upper()
    player_id = data.get('player_id')
    win_type_str = data.get('win_type')

    if game_id not in active_games:
        return jsonify({'status': 'error', 'message': 'Game not found'}), 404

    game = active_games[game_id]

    try:
        win_type = WinType(win_type_str)
    except ValueError:
        return jsonify({'status': 'error', 'message': 'Invalid win type'}), 400

    verified = verify_win(game, player_id, win_type)
    return jsonify({'status': 'ok', 'verified': verified, 'win_type': win_type_str})
