"""Tambola game Socket.IO events for real-time gameplay."""

from flask_socketio import emit, join_room, leave_room
from app import socketio


@socketio.on('tambola_join')
def handle_join(data):
    """Handle player joining a Tambola game room."""
    game_id = data.get('game_id')
    player_id = data.get('player_id')
    
    join_room(f'tambola_{game_id}')
    emit('player_joined', {
        'player_id': player_id
    }, room=f'tambola_{game_id}')


@socketio.on('tambola_call_number')
def handle_call_number(data):
    """Handle host calling a number."""
    game_id = data.get('game_id')
    # TODO: Implement number calling logic
    emit('number_called', {
        'number': 0,  # Placeholder
        'message': 'Not implemented yet'
    }, room=f'tambola_{game_id}')


@socketio.on('tambola_mark_number')
def handle_mark_number(data):
    """Handle player marking a number on their ticket."""
    # TODO: Implement number marking
    pass


@socketio.on('tambola_claim_win')
def handle_claim_win(data):
    """Handle player claiming a win."""
    game_id = data.get('game_id')
    player_id = data.get('player_id')
    win_type = data.get('win_type')
    
    # TODO: Verify win and broadcast result
    emit('win_claimed', {
        'player_id': player_id,
        'win_type': win_type,
        'verified': False,
        'message': 'Not implemented yet'
    }, room=f'tambola_{game_id}')
