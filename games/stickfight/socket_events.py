from flask_socketio import emit, join_room, leave_room
from flask import request
import random
import string

stickfight_rooms = {}

COLORS = ['#00f5ff', '#ff00cc', '#ffcc00', '#00ff88']


def generate_room_code():
    while True:
        code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        if code not in stickfight_rooms:
            return code


def register_stickfight_events(socketio):

    @socketio.on('create_room')
    def handle_create_room(data):
        if data.get('game_type') != 'stickfight':
            return
        room_code = generate_room_code()
        player_name = data.get('player_name', 'Fighter 1')
        player_id = request.sid

        stickfight_rooms[room_code] = {
            'code': room_code,
            'host': player_id,
            'players': [{
                'id': player_id,
                'name': player_name,
                'color': COLORS[0],
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
            'players': stickfight_rooms[room_code]['players'],
            'your_color': COLORS[0],
            'your_index': 0,
            'is_host': True
        })

    @socketio.on('join_room')
    def handle_join_room(data):
        if data.get('game_type') != 'stickfight':
            return
        room_code = data.get('room_code', '').upper().strip()
        player_name = data.get('player_name', 'Fighter')
        player_id = request.sid

        if room_code not in stickfight_rooms:
            emit('error', {'message': 'Room not found!'})
            return
        room = stickfight_rooms[room_code]
        if room['status'] != 'waiting':
            emit('error', {'message': 'Game already in progress!'})
            return
        if len(room['players']) >= room['max_players']:
            emit('error', {'message': 'Room is full!'})
            return

        idx = len(room['players'])
        room['players'].append({
            'id': player_id,
            'name': player_name,
            'color': COLORS[idx % len(COLORS)],
            'index': idx,
            'is_host': False
        })
        join_room(room_code)

        emit('room_joined', {
            'room_code': room_code,
            'player_id': player_id,
            'players': room['players'],
            'your_color': COLORS[idx % len(COLORS)],
            'your_index': idx,
            'is_host': False
        }, to=player_id)
        emit('player_joined', {'players': room['players']}, room=room_code, include_self=False)

    @socketio.on('start_game')
    def handle_start_game(data):
        if data.get('game_type') != 'stickfight':
            return
        room_code = data.get('room_code', '').upper()
        if room_code not in stickfight_rooms:
            emit('error', {'message': 'Room not found'})
            return
        room = stickfight_rooms[room_code]
        if request.sid != room['host']:
            emit('error', {'message': 'Only host can start!'})
            return
        if len(room['players']) < 2:
            emit('error', {'message': 'Need at least 2 players!'})
            return
        room['status'] = 'playing'
        socketio.emit('game_started', {'players': room['players']}, room=room_code)

    @socketio.on('sf_player_state')
    def handle_player_state(data):
        """Relay player position/animation state to everyone else."""
        room_code = data.get('room_code', '').upper()
        if room_code not in stickfight_rooms:
            return
        socketio.emit('sf_player_state', {
            'player_id': request.sid,
            'x': data.get('x'),
            'y': data.get('y'),
            'vx': data.get('vx'),
            'vy': data.get('vy'),
            'facing': data.get('facing'),
            'state': data.get('state'),  # 'idle','run','jump','attack','hurt','dead'
            'health': data.get('health'),
            'attacking': data.get('attacking'),
        }, room=room_code, include_self=False)

    @socketio.on('sf_attack_hit')
    def handle_attack_hit(data):
        """Host broadcasts an attack hit (damage dealt to a player)."""
        room_code = data.get('room_code', '').upper()
        if room_code not in stickfight_rooms:
            return
        room = stickfight_rooms[room_code]
        if request.sid != room['host']:
            return
        socketio.emit('sf_attack_hit', {
            'attacker_id': data.get('attacker_id'),
            'victim_id': data.get('victim_id'),
            'damage': data.get('damage'),
            'victim_health': data.get('victim_health')
        }, room=room_code)

    @socketio.on('sf_game_over')
    def handle_game_over(data):
        room_code = data.get('room_code', '').upper()
        if room_code not in stickfight_rooms:
            return
        room = stickfight_rooms[room_code]
        if request.sid != room['host']:
            return
        room['status'] = 'finished'
        socketio.emit('sf_game_over', {
            'winner_id': data.get('winner_id'),
            'winner_name': data.get('winner_name'),
            'scores': data.get('scores')
        }, room=room_code)

    @socketio.on('leave_room')
    def handle_leave_room(data):
        if data.get('game_type') != 'stickfight':
            return
        room_code = data.get('room_code', '').upper()
        player_id = request.sid
        if room_code not in stickfight_rooms:
            return
        room = stickfight_rooms[room_code]
        room['players'] = [p for p in room['players'] if p['id'] != player_id]
        leave_room(room_code)
        if len(room['players']) == 0:
            del stickfight_rooms[room_code]
        else:
            socketio.emit('player_left', {'players': room['players']}, room=room_code)

    print('✅ Stick Fight socket events registered')
