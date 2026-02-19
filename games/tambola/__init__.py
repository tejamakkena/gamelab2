"""Tambola (Indian Bingo/Housie) game module."""

from flask import Blueprint

tambola_bp = Blueprint('tambola', __name__, url_prefix='/games/tambola')

from . import routes, socket_events
