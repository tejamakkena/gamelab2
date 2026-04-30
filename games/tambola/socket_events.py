"""Tambola game Socket.IO events for real-time gameplay."""

from flask_socketio import emit, join_room, leave_room
from flask import request
from .game_logic import call_next_number, verify_win
from .models import WinType


def register_tambola_events(socketio):
    """Register all Tambola Socket.IO event handlers."""
    from .routes import active_games

    @socketio.on('tambola_join')
    def handle_join(data):
        game_id = data.get('game_id', '').upper()
        player_id = data.get('player_id')

        if game_id not in active_games:
            emit('tambola_error', {'message': 'Game not found'})
            return

        join_room(f'tambola_{game_id}')
        game = active_games[game_id]

        emit('tambola_joined', {
            'game_id': game_id,
            'player_count': len(game.players),
            'called_numbers': game.called_numbers,
            'status': game.status
        })

        emit('tambola_player_count', {
            'player_count': len(game.players)
        }, room=f'tambola_{game_id}', include_self=False)

    @socketio.on('tambola_start')
    def handle_start(data):
        game_id = data.get('game_id', '').upper()
        player_id = data.get('player_id')

        if game_id not in active_games:
            emit('tambola_error', {'message': 'Game not found'})
            return

        game = active_games[game_id]

        if player_id != game.host_id:
            emit('tambola_error', {'message': 'Only the host can start the game'})
            return

        if len(game.players) < 2:
            emit('tambola_error', {'message': 'Need at least 2 players to start'})
            return

        game.status = 'active'

        emit('tambola_started', {
            'player_count': len(game.players)
        }, room=f'tambola_{game_id}', include_self=True)

    @socketio.on('tambola_call_number')
    def handle_call_number(data):
        game_id = data.get('game_id', '').upper()
        player_id = data.get('player_id')

        if game_id not in active_games:
            emit('tambola_error', {'message': 'Game not found'})
            return

        game = active_games[game_id]

        if player_id != game.host_id:
            emit('tambola_error', {'message': 'Only the host can call numbers'})
            return

        if game.status != 'active':
            emit('tambola_error', {'message': 'Game is not active'})
            return

        number = call_next_number(game)

        if number is None:
            game.status = 'finished'
            emit('tambola_game_over', {
                'message': 'All 90 numbers have been called!',
                'wins': {k.value: v for k, v in game.wins_claimed.items()}
            }, room=f'tambola_{game_id}', include_self=True)
            return

        # Auto-mark the number on every player's ticket
        for ticket in game.players.values():
            ticket.mark_number(number)

        emit('tambola_number_called', {
            'number': number,
            'called_numbers': game.called_numbers,
            'remaining': len(game.available_numbers)
        }, room=f'tambola_{game_id}', include_self=True)

    @socketio.on('tambola_mark_number')
    def handle_mark_number(data):
        game_id = data.get('game_id', '').upper()
        player_id = data.get('player_id')
        number = data.get('number')

        if game_id not in active_games:
            return

        game = active_games[game_id]

        if player_id not in game.players:
            return

        marked = game.players[player_id].mark_number(number)
        if marked:
            emit('tambola_mark_confirmed', {'number': number})

    @socketio.on('tambola_claim_win')
    def handle_claim_win(data):
        game_id = data.get('game_id', '').upper()
        player_id = data.get('player_id')
        win_type_str = data.get('win_type')

        if game_id not in active_games:
            emit('tambola_error', {'message': 'Game not found'})
            return

        game = active_games[game_id]

        try:
            win_type = WinType(win_type_str)
        except ValueError:
            emit('tambola_error', {'message': 'Invalid win type'})
            return

        if win_type in game.wins_claimed:
            emit('tambola_error', {'message': 'This prize has already been claimed!'})
            return

        verified = verify_win(game, player_id, win_type)

        if verified:
            game.wins_claimed[win_type] = player_id

            # Look up player name if available
            emit('tambola_win_announced', {
                'player_id': player_id,
                'win_type': win_type_str,
                'verified': True
            }, room=f'tambola_{game_id}', include_self=True)

            # End game once all line prizes and full house are claimed
            terminal_wins = {WinType.TOP_LINE, WinType.MIDDLE_LINE, WinType.BOTTOM_LINE, WinType.FULL_HOUSE}
            if terminal_wins.issubset(set(game.wins_claimed.keys())):
                game.status = 'finished'
                emit('tambola_game_over', {
                    'message': 'All prizes claimed! Game over!',
                    'wins': {k.value: v for k, v in game.wins_claimed.items()}
                }, room=f'tambola_{game_id}', include_self=True)
        else:
            emit('tambola_win_rejected', {
                'win_type': win_type_str,
                'message': 'Invalid claim — your marked numbers do not satisfy this prize'
            })

    @socketio.on('tambola_leave')
    def handle_leave(data):
        game_id = data.get('game_id', '').upper()
        player_id = data.get('player_id')

        if game_id not in active_games:
            return

        leave_room(f'tambola_{game_id}')
        game = active_games[game_id]

        if player_id in game.players:
            del game.players[player_id]

        if not game.players:
            del active_games[game_id]

    print("✅ Tambola socket events registered")
