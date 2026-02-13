from flask import Blueprint, render_template, session, redirect, url_for
from functools import wraps

digit_guess_bp = Blueprint(
    'digit_guess',
    __name__,
    template_folder='../../templates')


def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('home'))
        return f(*args, **kwargs)
    return decorated_function


@digit_guess_bp.route('/')
@login_required
def index():
    """Digit Guess game page"""
    return render_template('games/digit_guess.html', user=session.get('user'))
