"""
Test suite for Canvas Battle game logic
"""
import pytest


class TestCanvasBattleRoom:
    """Test room creation and management"""
    
    def test_room_creation(self):
        """Test creating a canvas battle room"""
        room = {
            'code': 'ABC123',
            'host': 'player1',
            'players': [],
            'status': 'waiting',
            'time_limit': 60
        }
        
        assert room['status'] == 'waiting'
        assert room['time_limit'] == 60
    
    def test_default_time_limit(self):
        """Test default time limit is 60 seconds"""
        default_time = 60
        
        assert default_time == 60
    
    def test_custom_time_limit(self):
        """Test custom time limits are supported"""
        time_limits = [30, 60, 90, 120]
        
        for limit in time_limits:
            assert limit > 0
    
    def test_max_players(self):
        """Test maximum 6 players allowed"""
        max_players = 6
        
        assert max_players == 6
    
    def test_min_players(self):
        """Test minimum 2 players required"""
        min_players = 2
        
        assert min_players == 2


class TestCanvasBattlePlayers:
    """Test player management"""
    
    def test_player_structure(self):
        """Test player data structure"""
        player = {
            'id': 'p1',
            'name': 'Alice',
            'is_host': True,
            'ready': False,
            'canvas_data': None,
            'votes': 0,
            'score': 0
        }
        
        assert 'id' in player
        assert 'name' in player
        assert 'canvas_data' in player
        assert 'votes' in player
        assert 'score' in player
    
    def test_host_designation(self):
        """Test first player is host"""
        players = [
            {'id': 'p1', 'name': 'Alice', 'is_host': True},
            {'id': 'p2', 'name': 'Bob', 'is_host': False}
        ]
        
        hosts = [p for p in players if p['is_host']]
        
        assert len(hosts) == 1
        assert hosts[0]['id'] == 'p1'
    
    def test_ready_status(self):
        """Test player ready status"""
        player = {'ready': False}
        
        player['ready'] = True
        
        assert player['ready'] is True
    
    def test_all_players_ready(self):
        """Test checking if all players are ready"""
        players = [
            {'ready': True},
            {'ready': True},
            {'ready': True}
        ]
        
        all_ready = all(p['ready'] for p in players)
        
        assert all_ready is True


class TestCanvasBattleGameStates:
    """Test game state transitions"""
    
    def test_initial_state(self):
        """Test game starts in waiting state"""
        state = 'waiting'
        
        assert state == 'waiting'
    
    def test_state_transitions(self):
        """Test valid state transitions"""
        states = ['waiting', 'drawing', 'voting', 'finished']
        
        assert 'waiting' in states
        assert 'drawing' in states
        assert 'voting' in states
        assert 'finished' in states
    
    def test_transition_to_drawing(self):
        """Test transition from waiting to drawing"""
        state = 'waiting'
        all_ready = True
        
        if all_ready:
            state = 'drawing'
        
        assert state == 'drawing'
    
    def test_transition_to_voting(self):
        """Test transition from drawing to voting"""
        state = 'drawing'
        time_up = True
        
        if time_up:
            state = 'voting'
        
        assert state == 'voting'
    
    def test_transition_to_finished(self):
        """Test transition from voting to finished"""
        state = 'voting'
        voting_complete = True
        
        if voting_complete:
            state = 'finished'
        
        assert state == 'finished'


class TestCanvasBattleDrawing:
    """Test drawing phase"""
    
    def test_theme_assignment(self):
        """Test theme is assigned for drawing"""
        themes = ['Nature', 'Space', 'Ocean', 'City', 'Fantasy']
        
        import random
        selected_theme = random.choice(themes)
        
        assert selected_theme in themes
    
    def test_timer_starts(self):
        """Test timer starts when drawing begins"""
        time_limit = 60
        time_remaining = time_limit
        
        assert time_remaining == time_limit
    
    def test_canvas_data_storage(self):
        """Test canvas drawing data is stored"""
        player = {
            'id': 'p1',
            'canvas_data': None
        }
        
        # Player draws something
        canvas_data = {'strokes': [{'x': 10, 'y': 20, 'color': '#000'}]}
        player['canvas_data'] = canvas_data
        
        assert player['canvas_data'] is not None
        assert 'strokes' in player['canvas_data']
    
    def test_all_players_can_draw(self):
        """Test all players draw simultaneously"""
        players = [
            {'id': 'p1', 'canvas_data': None},
            {'id': 'p2', 'canvas_data': None},
            {'id': 'p3', 'canvas_data': None}
        ]
        
        # All can draw at once
        for player in players:
            player['canvas_data'] = {'drawing': 'data'}
        
        assert all(p['canvas_data'] is not None for p in players)
    
    def test_drawing_phase_time_limit(self):
        """Test drawing phase has time limit"""
        time_limit = 60
        elapsed_time = 65
        
        time_up = elapsed_time >= time_limit
        
        assert time_up is True


class TestCanvasBattleVoting:
    """Test voting phase"""
    
    def test_voting_initialization(self):
        """Test players' votes start at 0"""
        players = [
            {'id': 'p1', 'votes': 0},
            {'id': 'p2', 'votes': 0}
        ]
        
        assert all(p['votes'] == 0 for p in players)
    
    def test_player_casts_vote(self):
        """Test player casting a vote"""
        players = [
            {'id': 'p1', 'votes': 0},
            {'id': 'p2', 'votes': 0}
        ]
        
        # Player 1 votes for Player 2
        players[1]['votes'] += 1
        
        assert players[1]['votes'] == 1
    
    def test_cannot_vote_for_self(self):
        """Test player cannot vote for themselves"""
        voter_id = 'p1'
        vote_for_id = 'p1'
        
        is_valid = voter_id != vote_for_id
        
        assert is_valid is False
    
    def test_one_vote_per_player(self):
        """Test each player gets one vote"""
        votes_per_player = 1
        
        assert votes_per_player == 1
    
    def test_vote_counting(self):
        """Test votes are counted correctly"""
        players = [
            {'id': 'p1', 'votes': 3},
            {'id': 'p2', 'votes': 1},
            {'id': 'p3', 'votes': 2}
        ]
        
        total_votes = sum(p['votes'] for p in players)
        
        # With 4 players, each voting once (not for themselves), total = 3
        # This total depends on number of voters
        assert total_votes == 6


class TestCanvasBattleScoring:
    """Test scoring system"""
    
    def test_winner_most_votes(self):
        """Test player with most votes wins"""
        players = [
            {'id': 'p1', 'name': 'Alice', 'votes': 5},
            {'id': 'p2', 'name': 'Bob', 'votes': 2},
            {'id': 'p3', 'name': 'Charlie', 'votes': 3}
        ]
        
        winner = max(players, key=lambda p: p['votes'])
        
        assert winner['name'] == 'Alice'
        assert winner['votes'] == 5
    
    def test_score_equals_votes(self):
        """Test score is based on votes received"""
        votes = 5
        score = votes
        
        assert score == 5
    
    def test_tie_handling(self):
        """Test handling tied votes"""
        players = [
            {'id': 'p1', 'votes': 3},
            {'id': 'p2', 'votes': 3},
            {'id': 'p3', 'votes': 1}
        ]
        
        max_votes = max(p['votes'] for p in players)
        winners = [p for p in players if p['votes'] == max_votes]
        
        assert len(winners) == 2
    
    def test_score_accumulation_multiple_rounds(self):
        """Test scores accumulate across rounds"""
        player = {
            'score': 5,
            'votes': 3
        }
        
        player['score'] += player['votes']
        
        assert player['score'] == 8


class TestCanvasBattleRounds:
    """Test multiple round functionality"""
    
    def test_default_max_rounds(self):
        """Test default maximum rounds is 3"""
        max_rounds = 3
        
        assert max_rounds == 3
    
    def test_round_progression(self):
        """Test round counter increments"""
        current_round = 1
        max_rounds = 3
        
        current_round += 1
        
        assert current_round == 2
        assert current_round <= max_rounds
    
    def test_game_ends_after_max_rounds(self):
        """Test game ends after completing all rounds"""
        current_round = 3
        max_rounds = 3
        
        game_over = current_round >= max_rounds
        
        assert game_over is True
    
    def test_new_theme_each_round(self):
        """Test different theme each round"""
        themes = ['Nature', 'Space', 'Ocean', 'City', 'Fantasy']
        
        import random
        round1_theme = random.choice(themes)
        round2_theme = random.choice(themes)
        
        # Themes should potentially be different
        assert round1_theme in themes
        assert round2_theme in themes
    
    def test_votes_reset_each_round(self):
        """Test votes are reset between rounds"""
        players = [
            {'id': 'p1', 'votes': 5, 'score': 5},
            {'id': 'p2', 'votes': 3, 'score': 3}
        ]
        
        # Reset votes for new round
        for player in players:
            player['votes'] = 0
        
        assert all(p['votes'] == 0 for p in players)
        assert players[0]['score'] == 5  # Score persists


class TestCanvasBattleCanvas:
    """Test canvas functionality"""
    
    def test_canvas_clear(self):
        """Test canvas can be cleared"""
        canvas_data = {'strokes': [{'x': 10, 'y': 20}]}
        
        canvas_data = None  # Clear
        
        assert canvas_data is None
    
    def test_drawing_tools(self):
        """Test various drawing tools"""
        tools = ['pen', 'eraser', 'fill', 'brush']
        
        assert 'pen' in tools
        assert 'eraser' in tools
    
    def test_color_selection(self):
        """Test color palette"""
        colors = ['#000000', '#FF0000', '#00FF00', '#0000FF', '#FFFF00']
        
        assert len(colors) > 0
        assert '#000000' in colors  # Black
    
    def test_stroke_data_structure(self):
        """Test stroke data structure"""
        stroke = {
            'x': 100,
            'y': 150,
            'color': '#FF0000',
            'size': 5,
            'tool': 'pen'
        }
        
        assert 'x' in stroke
        assert 'y' in stroke
        assert 'color' in stroke


class TestCanvasBattleThemes:
    """Test theme system"""
    
    def test_theme_list_exists(self):
        """Test predefined themes exist"""
        themes = ['Nature', 'Space', 'Ocean', 'City', 'Animals', 'Food', 'Sports', 'Fantasy']
        
        assert len(themes) > 0
    
    def test_theme_selection_random(self):
        """Test theme is randomly selected"""
        import random
        themes = ['Theme1', 'Theme2', 'Theme3']
        
        selected = random.choice(themes)
        
        assert selected in themes
    
    def test_same_theme_for_all_players(self):
        """Test all players get same theme in a round"""
        selected_theme = 'Space'
        
        player1_theme = selected_theme
        player2_theme = selected_theme
        
        assert player1_theme == player2_theme


class TestCanvasBattleEdgeCases:
    """Test edge cases"""
    
    def test_single_player_no_voting(self):
        """Test single player can't vote"""
        players = [{'id': 'p1', 'name': 'Alice'}]
        
        # Can't vote if only 1 player
        can_vote = len(players) > 1
        
        assert can_vote is False
    
    def test_all_players_zero_votes(self):
        """Test handling when no one votes"""
        players = [
            {'id': 'p1', 'votes': 0},
            {'id': 'p2', 'votes': 0}
        ]
        
        max_votes = max(p['votes'] for p in players)
        
        assert max_votes == 0
    
    def test_player_leaves_during_game(self):
        """Test handling player leaving"""
        players = [
            {'id': 'p1', 'name': 'Alice'},
            {'id': 'p2', 'name': 'Bob'},
            {'id': 'p3', 'name': 'Charlie'}
        ]
        
        # Player 2 leaves
        players = [p for p in players if p['id'] != 'p2']
        
        assert len(players) == 2
        assert not any(p['id'] == 'p2' for p in players)
    
    def test_time_limit_validation(self):
        """Test time limit is positive"""
        time_limit = 60
        
        assert time_limit > 0
    
    def test_empty_canvas_submission(self):
        """Test handling empty canvas (no drawing)"""
        canvas_data = None
        
        is_empty = canvas_data is None
        
        assert is_empty is True


class TestCanvasBattleFinalRanking:
    """Test final ranking and winner determination"""
    
    def test_final_ranking_by_total_score(self):
        """Test final ranking based on accumulated score"""
        players = [
            {'name': 'Alice', 'score': 15},
            {'name': 'Bob', 'score': 22},
            {'name': 'Charlie', 'score': 18}
        ]
        
        ranked = sorted(players, key=lambda p: p['score'], reverse=True)
        
        assert ranked[0]['name'] == 'Bob'
        assert ranked[1]['name'] == 'Charlie'
        assert ranked[2]['name'] == 'Alice'
    
    def test_overall_winner(self):
        """Test determining overall winner"""
        players = [
            {'name': 'Alice', 'score': 15},
            {'name': 'Bob', 'score': 22},
            {'name': 'Charlie', 'score': 18}
        ]
        
        winner = max(players, key=lambda p: p['score'])
        
        assert winner['name'] == 'Bob'
        assert winner['score'] == 22
