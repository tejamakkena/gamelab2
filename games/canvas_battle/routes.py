from flask import Blueprint, render_template, session, redirect, url_for
from functools import wraps

canvas_battle_bp = Blueprint(
    'canvas_battle',
    __name__,
    template_folder='../../templates')


def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('home'))
        return f(*args, **kwargs)
    return decorated_function


@canvas_battle_bp.route('/')
@login_required
def index():
    """Canvas Battle game page"""
    return render_template(
        'games/canvas_battle.html',
        user=session.get('user'))
