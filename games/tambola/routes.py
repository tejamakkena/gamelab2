"""Tambola game HTTP routes."""

from flask import render_template, jsonify, request, session
from . import tambola_bp
from .game_logic import generate_ticket, call_next_number, verify_win
from .models import TambolaGame, WinType

# In-memory game storage (TODO: move to database)
active_games = {}


@tambola_bp.route('/')
def index():
    """Render the Tambola game page."""
    return render_template('tambola/game.html')


@tambola_bp.route('/create', methods=['POST'])
def create_game():
    """Create a new Tambola game."""
    # TODO: Implement game creation
    return jsonify({'status': 'pending', 'message': 'Not implemented yet'}), 501


@tambola_bp.route('/join/<game_id>', methods=['POST'])
def join_game(game_id):
    """Join an existing Tambola game."""
    # TODO: Implement game joining
    return jsonify({'status': 'pending', 'message': 'Not implemented yet'}), 501


@tambola_bp.route('/claim', methods=['POST'])
def claim_win():
    """Claim a win (Early 5, Line, Full House)."""
    # TODO: Implement win claiming
    return jsonify({'status': 'pending', 'message': 'Not implemented yet'}), 501
