from flask import Blueprint, render_template, session

roulette_bp = Blueprint('roulette', __name__)


@roulette_bp.route('/')
def index():
    """Roulette game page"""
    user = session.get('user')
    print("🎰 Roulette route accessed!")
    print(f"🎰 Roulette - User: {user}")
    return render_template('games/roulette.html', user=user)
