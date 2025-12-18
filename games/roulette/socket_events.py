from flask_socketio import emit, join_room, leave_room
from flask import request
import random
import string

# Store active roulette rooms
roulette_rooms = {}


def generate_room_code():
    """Generate a unique 6-character room code"""
    while True:
        code = ''.join(
            random.choices(
                string.ascii_uppercase +
                string.digits,
                k=6))
        if code not in roulette_rooms:
            return code


def register_roulette_events(socketio):
    """Register all Roulette socket events"""

    @socketio.on('create_roulette_room')
    def handle_create_room(data):
        """Create a new roulette room"""
        room_code = generate_room_code()
        player_name = data.get('player_name', 'Player')
        player_id = request.sid

        roulette_rooms[room_code] = {
            'code': room_code,
            'host': player_id,
            'players': [{
                'id': player_id,
                'name': player_name,
                'chips': 1000,
                'is_host': True
            }],
            'status': 'waiting',
            'current_bets': {},
            'last_result': None
        }

        join_room(room_code)

        emit('roulette_room_created', {
            'room_code': room_code,
            'player_id': player_id,
            'players': roulette_rooms[room_code]['players']
        })

    @socketio.on('join_roulette_room')
    def handle_join_room(data):
        """Join an existing roulette room"""
        room_code = data.get('room_code', '').upper().strip()
        player_name = data.get('player_name', 'Player')
        player_id = request.sid

        if room_code not in roulette_rooms:
            emit('roulette_error', {'message': 'Room not found!'})
            return

        room = roulette_rooms[room_code]

        room['players'].append({
            'id': player_id,
            'name': player_name,
            'chips': 1000,
            'is_host': False
        })

        join_room(room_code)

        emit('roulette_room_joined', {
            'room_code': room_code,
            'player_id': player_id,
            'players': room['players']
        }, to=request.sid)

        emit('roulette_player_joined', {
            'player_name': player_name,
            'players': room['players']
        }, room=room_code, include_self=True)

    @socketio.on('place_bet')
    def handle_place_bet(data):
        """Handle player bet"""
        room_code = data.get('room_code', '').upper()
        player_id = request.sid
        bet_type = data.get('bet_type')
        bet_amount = data.get('bet_amount', 0)

        if room_code not in roulette_rooms:
            return

        room = roulette_rooms[room_code]

        if player_id not in room['current_bets']:
            room['current_bets'][player_id] = []

        room['current_bets'][player_id].append({
            'type': bet_type,
            'amount': bet_amount
        })

        emit('bet_placed', {
            'player_id': player_id,
            'bet_type': bet_type,
            'bet_amount': bet_amount
        }, room=room_code, include_self=True)

    @socketio.on('spin_wheel')
    def handle_spin_wheel(data):
        """Spin the roulette wheel"""
        room_code = data.get('room_code', '').upper()

        if room_code not in roulette_rooms:
            return

        room = roulette_rooms[room_code]

        # Generate random number (0-36)
        result = random.randint(0, 36)
        room['last_result'] = result

        # Determine color
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16,
                       18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        color = 'red' if result in red_numbers else 'black' if result != 0 else 'green'

        emit('wheel_spinning', {
            'result': result,
            'color': color
        }, room=room_code, include_self=True)

    print("✅ Roulette socket events registered")
