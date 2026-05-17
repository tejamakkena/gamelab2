from flask_socketio import emit, join_room, leave_room
from flask import request
import random
import string

roadfighter_rooms = {}

CAR_COLORS = ['#00f5ff', '#ff00cc', '#ffcc00', '#00ff88']


def generate_room_code():
    while True:
        code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        if code not in roadfighter_rooms:
            return code


def register_roadfighter_events(socketio):

    @socketio.on('create_room')
    def handle_create_room(data):
        if data.get('game_type') != 'roadfighter':
            return
        room_code = generate_room_code()
        player_name = data.get('player_name', 'Racer 1')
        player_id = request.sid

        roadfighter_rooms[room_code] = {
            'code': room_code,
            'host': player_id,
            'players': [{
                'id': player_id,
                'name': player_name,
                'color': CAR_COLORS[0],
                'index': 0,
                'is_host': True
            }],
            'status': 'waiting',
            'max_players': 4
        }
        join_room(room_code)
        emit('room_created', {
            'room_code': room_code,
            'player_id': player_id,
            'players': roadfighter_rooms[room_code]['players'],
            'your_color': CAR_COLORS[0],
            'your_index': 0,
            'is_host': True
        })

    @socketio.on('join_room')
    def handle_join_room(data):
        if data.get('game_type') != 'roadfighter':
            return
        room_code = data.get('room_code', '').upper().strip()
        player_name = data.get('player_name', 'Racer')
        player_id = request.sid

        if room_code not in roadfighter_rooms:
            emit('error', {'message': 'Room not found!'})
            return
        room = roadfighter_rooms[room_code]
        if room['status'] != 'waiting':
            emit('error', {'message': 'Race already started!'})
            return
        if len(room['players']) >= room['max_players']:
            emit('error', {'message': 'Room is full!'})
            return

        idx = len(room['players'])
        room['players'].append({
            'id': player_id,
            'name': player_name,
            'color': CAR_COLORS[idx % len(CAR_COLORS)],
            'index': idx,
            'is_host': False
        })
        join_room(room_code)

        emit('room_joined', {
            'room_code': room_code,
            'player_id': player_id,
            'players': room['players'],
            'your_color': CAR_COLORS[idx % len(CAR_COLORS)],
            'your_index': idx,
            'is_host': False
        }, to=player_id)
        emit('player_joined', {'players': room['players']}, room=room_code, include_self=False)

    @socketio.on('start_game')
    def handle_start_game(data):
        if data.get('game_type') != 'roadfighter':
            return
        room_code = data.get('room_code', '').upper()
        if room_code not in roadfighter_rooms:
            emit('error', {'message': 'Room not found'})
            return
        room = roadfighter_rooms[room_code]
        if request.sid != room['host']:
            emit('error', {'message': 'Only host can start!'})
            return
        if len(room['players']) < 1:
            emit('error', {'message': 'Need at least 1 player!'})
            return
        room['status'] = 'playing'
        socketio.emit('game_started', {'players': room['players']}, room=room_code)

    @socketio.on('rf_player_update')
    def handle_player_update(data):
        """Relay car position to all other players."""
        room_code = data.get('room_code', '').upper()
        if room_code not in roadfighter_rooms:
            return
        socketio.emit('rf_player_update', {
            'player_id': request.sid,
            'x': data.get('x'),
            'lane': data.get('lane'),
            'health': data.get('health'),
            'score': data.get('score'),
            'alive': data.get('alive')
        }, room=room_code, include_self=False)

    @socketio.on('rf_obstacles')
    def handle_obstacles(data):
        """Host broadcasts obstacle list to all players (shared game state)."""
        room_code = data.get('room_code', '').upper()
        if room_code not in roadfighter_rooms:
            return
        room = roadfighter_rooms[room_code]
        if request.sid != room['host']:
            return
        socketio.emit('rf_obstacles', {
            'obstacles': data.get('obstacles'),
            'scroll_y': data.get('scroll_y')
        }, room=room_code, include_self=False)

    @socketio.on('rf_game_over')
    def handle_game_over(data):
        room_code = data.get('room_code', '').upper()
        if room_code not in roadfighter_rooms:
            return
        room = roadfighter_rooms[room_code]
        if request.sid != room['host']:
            return
        room['status'] = 'finished'
        socketio.emit('rf_game_over', {
            'results': data.get('results')
        }, room=room_code)

    @socketio.on('leave_room')
    def handle_leave_room(data):
        if data.get('game_type') != 'roadfighter':
            return
        room_code = data.get('room_code', '').upper()
        player_id = request.sid
        if room_code not in roadfighter_rooms:
            return
        room = roadfighter_rooms[room_code]
        room['players'] = [p for p in room['players'] if p['id'] != player_id]
        leave_room(room_code)
        if len(room['players']) == 0:
            del roadfighter_rooms[room_code]
        else:
            socketio.emit('player_left', {'players': room['players']}, room=room_code)

    print('✅ Road Fighter socket events registered')
