from flask_socketio import emit, join_room, leave_room
from flask import request
import random
import string

pong_rooms = {}


def generate_room_code():
    while True:
        code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        if code not in pong_rooms:
            return code


def register_pong_events(socketio):

    @socketio.on('create_room')
    def handle_create_room(data):
        if data.get('game_type') != 'pong':
            return
        room_code = generate_room_code()
        player_name = data.get('player_name', 'Player 1')
        player_id = request.sid

        pong_rooms[room_code] = {
            'code': room_code,
            'host': player_id,
            'players': [{'id': player_id, 'name': player_name, 'side': 'left', 'is_host': True}],
            'status': 'waiting',
            'score': {'left': 0, 'right': 0}
        }
        join_room(room_code)
        emit('room_created', {
            'room_code': room_code,
            'player_id': player_id,
            'players': pong_rooms[room_code]['players'],
            'your_side': 'left',
            'is_host': True
        })

    @socketio.on('join_room')
    def handle_join_room(data):
        if data.get('game_type') != 'pong':
            return
        room_code = data.get('room_code', '').upper().strip()
        player_name = data.get('player_name', 'Player 2')
        player_id = request.sid

        if room_code not in pong_rooms:
            emit('error', {'message': 'Room not found!'})
            return
        room = pong_rooms[room_code]
        if room['status'] != 'waiting':
            emit('error', {'message': 'Game already in progress!'})
            return
        if len(room['players']) >= 2:
            emit('error', {'message': 'Room is full!'})
            return

        room['players'].append({'id': player_id, 'name': player_name, 'side': 'right', 'is_host': False})
        join_room(room_code)

        emit('room_joined', {
            'room_code': room_code,
            'player_id': player_id,
            'players': room['players'],
            'your_side': 'right',
            'is_host': False
        }, to=player_id)
        emit('player_joined', {'players': room['players']}, room=room_code, include_self=False)

    @socketio.on('start_game')
    def handle_start_game(data):
        if data.get('game_type') != 'pong':
            return
        room_code = data.get('room_code', '').upper()
        if room_code not in pong_rooms:
            emit('error', {'message': 'Room not found'})
            return
        room = pong_rooms[room_code]
        if request.sid != room['host']:
            emit('error', {'message': 'Only host can start!'})
            return
        if len(room['players']) != 2:
            emit('error', {'message': 'Need exactly 2 players!'})
            return
        room['status'] = 'playing'
        socketio.emit('game_started', {
            'players': room['players']
        }, room=room_code)

    @socketio.on('pong_paddle_update')
    def handle_paddle_update(data):
        room_code = data.get('room_code', '').upper()
        if room_code not in pong_rooms:
            return
        # Relay paddle position to everyone else in the room
        socketio.emit('pong_paddle_update', {
            'side': data.get('side'),
            'y': data.get('y')
        }, room=room_code, include_self=False)

    @socketio.on('pong_ball_update')
    def handle_ball_update(data):
        room_code = data.get('room_code', '').upper()
        if room_code not in pong_rooms:
            return
        room = pong_rooms[room_code]
        # Only host (left paddle) sends authoritative ball state
        if request.sid != room['host']:
            return
        socketio.emit('pong_ball_update', {
            'ball': data.get('ball'),
            'score': data.get('score'),
            'paddles': data.get('paddles')
        }, room=room_code, include_self=False)

    @socketio.on('pong_game_over')
    def handle_game_over(data):
        room_code = data.get('room_code', '').upper()
        if room_code not in pong_rooms:
            return
        room = pong_rooms[room_code]
        if request.sid != room['host']:
            return
        room['status'] = 'finished'
        socketio.emit('pong_game_over', {
            'winner': data.get('winner'),
            'score': data.get('score')
        }, room=room_code)

    @socketio.on('leave_room')
    def handle_leave_room(data):
        if data.get('game_type') != 'pong':
            return
        room_code = data.get('room_code', '').upper()
        player_id = request.sid
        if room_code not in pong_rooms:
            return
        room = pong_rooms[room_code]
        room['players'] = [p for p in room['players'] if p['id'] != player_id]
        leave_room(room_code)
        if len(room['players']) == 0:
            del pong_rooms[room_code]
        else:
            socketio.emit('player_left', {'players': room['players']}, room=room_code)

    print('✅ Pong socket events registered')
