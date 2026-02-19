from flask import Blueprint, render_template, session, redirect, url_for
from functools import wraps

pictionary_bp = Blueprint(
    'pictionary',
    __name__,
    template_folder='../../templates')


def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('home'))
        return f(*args, **kwargs)
    return decorated_function


@pictionary_bp.route('/')
@login_required
def index():
    """Pictionary game page"""
    return render_template(
        'games/pictionary.html',
        user=session.get('user'))
