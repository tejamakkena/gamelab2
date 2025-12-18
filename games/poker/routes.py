from flask import Blueprint, render_template, session, redirect, url_for
from functools import wraps

poker_bp = Blueprint('poker', __name__, template_folder='../../templates')


def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function


@poker_bp.route('/')
@login_required
def index():
    """Poker game page"""
    return render_template('games/poker.html', user=session.get('user'))
