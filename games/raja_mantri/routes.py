from flask import Blueprint, render_template, session, redirect, url_for, request
import secrets

raja_mantri_bp = Blueprint('raja_mantri', __name__)

@raja_mantri_bp.route('/')
def index():
    """Raja Mantri game page"""
    user = session.get('user')
    if not user:
        return redirect(url_for('home'))
    
    # Generate or get room ID
    room_id = request.args.get('room')
    if not room_id:
        room_id = secrets.token_urlsafe(6)
    
    return render_template('games/raja_mantri.html', 
                         user=user, 
                         room_id=room_id)
