
import logging
from logging.handlers import RotatingFileHandler

def setup_logging(app):
    handler = RotatingFileHandler('gamelab.log', maxBytes=10000, backupCount=3)
    handler.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    
    # Add handler to app logger
    app.logger.addHandler(handler)
    app.logger.setLevel(logging.INFO)
