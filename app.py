from flask import Flask, render_template, redirect, url_for, session, request, jsonify
from flask_socketio import SocketIO, emit, join_room, leave_room
from config import config
import os
from functools import wraps
from google.oauth2 import id_token
from google.auth.transport import requests
import json

def create_app(config_name='default'):
    app = Flask(__name__)
    app.config.from_object(config[config_name])
    
    # Initialize Socket.IO
    socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')
    
    # Debug: Print Google Client ID (first 20 chars only for security)
    client_id = app.config.get('GOOGLE_CLIENT_ID', 'NOT SET')
    print(f"Google Client ID configured: {client_id[:20] if client_id else 'NOT SET'}...")
    
    # Register blueprints
    from games.tictactoe.routes import tictactoe_bp
    from games.trivia.routes import trivia_bp
    from games.snake_ladder.routes import snake_ladder_bp
    from games.roulette.routes import roulette_bp
    
    app.register_blueprint(tictactoe_bp, url_prefix='/tictactoe')
    app.register_blueprint(trivia_bp, url_prefix='/trivia')
    app.register_blueprint(snake_ladder_bp, url_prefix='/snake')
    app.register_blueprint(roulette_bp, url_prefix='/roulette')
    
    # Import Socket.IO event handlers
    from games.trivia.socket_events import register_trivia_events
    from games.snake_ladder.socket_events import register_snake_events
    from games.roulette.socket_events import register_roulette_events
    
    register_trivia_events(socketio)
    register_snake_events(socketio)
    register_roulette_events(socketio)
    
    # Login required decorator
    def login_required(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'user' not in session:
                return redirect(url_for('home'))
            return f(*args, **kwargs)
        return decorated_function
    
    # Main routes
    @app.route("/")
    def home():
        games_list = [
            {
                'name': 'Tic Tac Toe', 
                'url': '/tictactoe', 
                'icon': '⭕❌', 
                'players': '2',
                'description': 'Classic 2-player strategy game. Test your tactical skills!'
            },
            {
                'name': 'Connect 4', 
                'url': '/connect4', 
                'icon': '🔴🟡', 
                'players': '2',
                'description': 'Strategic dropping game. Connect four to win!'
            },
            {
                'name': 'Snake & Ladder', 
                'url': '/snake', 
                'icon': '🐍🪜', 
                'players': '2-4',
                'description': 'Multiplayer board game. Climb ladders, avoid snakes!'
            },
            {
                'name': 'Memory Game', 
                'url': '/memory', 
                'icon': '🧠💭', 
                'players': '1-4',
                'description': 'Test your memory with matching cards!'
            },
            {
                'name': 'Pictionary', 
                'url': '/pictionary', 
                'icon': '🎨✏️', 
                'players': '2+',
                'description': 'Draw and guess! Creative multiplayer fun!'
            },
            {
                'name': 'Trivia', 
                'url': '/trivia', 
                'icon': '❓🏆', 
                'players': '1+',
                'description': 'Challenge your knowledge across categories!'
            },
            {
                'name': 'Mafia', 
                'url': '/mafia', 
                'icon': '🕵️🔪', 
                'players': '4+',
                'description': 'Social deduction game. Find the mafia members!'
            },
            {
                'name': 'Tambola', 
                'url': '/tambola', 
                'icon': '🎲🎟️', 
                'players': '2+',
                'description': 'Indian bingo game. Mark your numbers and win!'
            },
            {
                'name': 'Raja Mantri', 
                'url': '/raja-mantri', 
                'icon': '👑🗡️', 
                'players': '4',
                'description': 'Classic 4-player guessing game!'
            },
            {
                'name': 'Roulette', 
                'url': '/roulette', 
                'icon': '🎰🎲', 
                'players': '1+',
                'description': 'Place your bets and spin the wheel! Try your luck!'
            }
        ]
        
        user = session.get('user')
        return render_template("home.html", games=games_list, user=user, 
                             google_client_id=app.config.get('GOOGLE_CLIENT_ID'))
    
    @app.route("/connect4")
    @login_required
    def connect4():
        return render_template("games/connect4.html")
    
    @app.route("/snake")
    @login_required
    def snake_ladder():
        return render_template("games/snake.html")
    
    @app.route("/memory")
    @login_required
    def memory():
        return render_template("games/memory.html")
    
    @app.route("/pictionary")
    @login_required
    def pictionary():
        return render_template("games/pictionary.html")
    
    @app.route("/trivia")
    @login_required
    def trivia():
        return render_template("games/trivia.html")
    
    @app.route("/mafia")
    @login_required
    def mafia():
        return render_template("games/mafia.html")
    
    @app.route("/tambola")
    @login_required
    def tambola():
        return render_template("games/tambola.html")
    
    @app.route("/raja-mantri")
    @login_required
    def raja_mantri():
        return render_template("games/raja-mantri.html")
    
    @app.route("/login", methods=['POST'])
    def login():
        """Google OAuth login"""
        token = request.json.get('credential')
        
        try:
            idinfo = id_token.verify_oauth2_token(
                token, 
                requests.Request(), 
                app.config['GOOGLE_CLIENT_ID']
            )
            
            session['user'] = {
                'email': idinfo['email'],
                'first_name': idinfo.get('given_name', ''),
                'last_name': idinfo.get('family_name', ''),
                'picture': idinfo.get('picture', ''),
                'name': idinfo.get('name', ''),
                'login_type': 'google'
            }
            
            print(f"✅ Google login successful: {session['user']['email']}")
            return jsonify({'success': True, 'user': session['user']})
        except ValueError as e:
            print(f"❌ Google login error: {e}")
            return jsonify({'success': False, 'error': str(e)}), 400
    
    @app.route("/login/manual", methods=['POST'])
    def manual_login():
        """Manual name-based login"""
        data = request.json
        player_name = data.get('player_name', '').strip()
        
        if not player_name or len(player_name) < 2:
            return jsonify({'success': False, 'error': 'Name must be at least 2 characters'}), 400
        
        session['user'] = {
            'name': player_name,
            'first_name': player_name.split()[0] if ' ' in player_name else player_name,
            'last_name': player_name.split()[-1] if ' ' in player_name else '',
            'email': None,
            'picture': None,
            'login_type': 'manual'
        }
        
        return jsonify({'success': True, 'user': session['user']})
    
    @app.route("/logout")
    def logout():
        user = session.get('user', {})
        print(f"👋 Logout: {user.get('name', 'Unknown user')}")
        session.pop('user', None)
        return redirect(url_for('home'))
    
    @app.route("/about")
    def about():
        return render_template("about.html")
    
    # Error handlers
    @app.errorhandler(404)
    def not_found(error):
        try:
            return render_template('404.html'), 404
        except:
            return '<h1>404 - Page Not Found</h1><a href="/">Go Home</a>', 404
    
    @app.errorhandler(500)
    def internal_error(error):
        try:
            return render_template('500.html'), 500
        except:
            return '<h1>500 - Internal Server Error</h1><a href="/">Go Home</a>', 500
    
    return app, socketio

if __name__ == "__main__":
    app, socketio = create_app('development')
    print("\n🚀 Starting Futuristic Games Hub...")
    print(f"📍 Server running at: http://localhost:5000")
    print(f"🎮 Games loaded: Tic-Tac-Toe ✅, Trivia ✅, Snake & Ladder ✅, Roulette ✅\n")
    socketio.run(app, debug=True, host='0.0.0.0', port=5000)