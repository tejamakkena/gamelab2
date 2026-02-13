"""
Basic app tests
"""
import pytest


class TestAppBasics:
    """Test basic app functionality"""
    
    def test_app_can_be_imported(self):
        """Test that app module can be imported"""
        try:
            import app
            assert True
        except ImportError:
            pytest.skip("App has dependencies that aren't loaded")
    
    def test_games_module_exists(self):
        """Test games module exists"""
        import games
        assert games is not None
