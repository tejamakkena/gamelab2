
import pytest
from app import create_app
from database.db import init_test_db

@pytest.fixture
def client():
    app = create_app('testing')
    with app.test_client() as client:
        with app.app_context():
            init_test_db()
        yield client

def test_index_route(client):
    response = client.get('/')
    assert response.status_code == 200

# Add more test cases for different games and routes
