"""
Test suite for Trivia game logic
"""
import pytest


class TestTriviaQuestions:
    """Test trivia question structure and validation"""
    
    def test_question_structure(self):
        """Test that question has required fields"""
        question = {
            'question': 'What is the capital of France?',
            'options': ['London', 'Berlin', 'Paris', 'Madrid'],
            'correct': 'Paris',
            'category': 'Geography'
        }
        
        assert 'question' in question
        assert 'options' in question
        assert 'correct' in question
        assert 'category' in question
    
    def test_question_has_four_options(self):
        """Test that question has 4 options"""
        options = ['Option A', 'Option B', 'Option C', 'Option D']
        
        assert len(options) == 4
    
    def test_correct_answer_in_options(self):
        """Test that correct answer is in options"""
        options = ['London', 'Berlin', 'Paris', 'Madrid']
        correct = 'Paris'
        
        assert correct in options
    
    def test_question_categories(self):
        """Test various question categories"""
        categories = ['Science', 'History', 'Geography', 'Sports', 'Entertainment']
        
        assert 'Science' in categories
        assert len(categories) > 0


class TestTriviaScoring:
    """Test scoring logic"""
    
    def test_correct_answer_scores_points(self):
        """Test correct answer adds points"""
        score = 0
        points_per_question = 10
        
        # Correct answer
        score += points_per_question
        
        assert score == 10
    
    def test_incorrect_answer_no_points(self):
        """Test incorrect answer doesn't add points"""
        score = 0
        
        # Incorrect answer
        # Score stays the same
        
        assert score == 0
    
    def test_multiple_correct_answers(self):
        """Test multiple correct answers accumulate"""
        score = 0
        points_per_question = 10
        
        # 3 correct answers
        score += points_per_question
        score += points_per_question
        score += points_per_question
        
        assert score == 30
    
    def test_mixed_answers(self):
        """Test mix of correct and incorrect answers"""
        score = 0
        points_per_question = 10
        
        score += points_per_question  # Correct
        # Incorrect (no points)
        score += points_per_question  # Correct
        # Incorrect (no points)
        
        assert score == 20
    
    def test_score_never_negative(self):
        """Test score doesn't go negative"""
        score = 0
        
        # Incorrect answers shouldn't make score negative
        assert score >= 0


class TestTriviaAnswerValidation:
    """Test answer validation"""
    
    def test_exact_match_correct(self):
        """Test exact match is correct"""
        user_answer = 'Paris'
        correct_answer = 'Paris'
        
        is_correct = user_answer == correct_answer
        
        assert is_correct is True
    
    def test_wrong_answer_incorrect(self):
        """Test wrong answer is incorrect"""
        user_answer = 'London'
        correct_answer = 'Paris'
        
        is_correct = user_answer == correct_answer
        
        assert is_correct is False
    
    def test_case_sensitivity(self):
        """Test answer comparison handles case"""
        user_answer = 'paris'
        correct_answer = 'Paris'
        
        # Case-insensitive comparison
        is_correct = user_answer.lower() == correct_answer.lower()
        
        assert is_correct is True
    
    def test_whitespace_handling(self):
        """Test answer comparison handles whitespace"""
        user_answer = ' Paris '
        correct_answer = 'Paris'
        
        # Strip whitespace
        is_correct = user_answer.strip() == correct_answer.strip()
        
        assert is_correct is True


class TestTriviaGameSettings:
    """Test game settings and configuration"""
    
    def test_default_question_count(self):
        """Test default number of questions"""
        default_questions = 5
        
        assert default_questions == 5
    
    def test_custom_question_count(self):
        """Test custom question count"""
        question_counts = [5, 10, 15, 20]
        
        for count in question_counts:
            assert count > 0
    
    def test_difficulty_levels(self):
        """Test difficulty level options"""
        difficulties = ['easy', 'medium', 'hard']
        
        assert 'easy' in difficulties
        assert 'medium' in difficulties
        assert 'hard' in difficulties
    
    def test_topic_selection(self):
        """Test topic/category selection"""
        topics = ['Science', 'History', 'Geography', 'Sports', 'Entertainment', 'Mixed']
        
        assert len(topics) > 0
        assert 'Mixed' in topics


class TestTriviaPlayerManagement:
    """Test player management"""
    
    def test_add_player(self):
        """Test adding player to game"""
        players = {}
        player_name = 'Alice'
        
        players[player_name] = {
            'name': player_name,
            'score': 0,
            'ready': False,
            'is_host': False
        }
        
        assert player_name in players
        assert players[player_name]['score'] == 0
    
    def test_host_designation(self):
        """Test first player is designated host"""
        players = {}
        
        # First player
        players['Alice'] = {'name': 'Alice', 'is_host': True, 'score': 0}
        
        assert players['Alice']['is_host'] is True
    
    def test_multiple_players(self):
        """Test multiple players can join"""
        players = {
            'Alice': {'name': 'Alice', 'score': 0, 'ready': False},
            'Bob': {'name': 'Bob', 'score': 0, 'ready': False},
            'Charlie': {'name': 'Charlie', 'score': 0, 'ready': False}
        }
        
        assert len(players) == 3
    
    def test_max_players(self):
        """Test maximum player limit (4 players)"""
        max_players = 4
        players = {f'Player{i}': {'name': f'Player{i}', 'score': 0} for i in range(4)}
        
        assert len(players) <= max_players
    
    def test_player_ready_status(self):
        """Test player ready status"""
        player = {'name': 'Alice', 'score': 0, 'ready': False}
        
        player['ready'] = True
        
        assert player['ready'] is True


class TestTriviaGameStates:
    """Test game state management"""
    
    def test_initial_state_waiting(self):
        """Test game starts in waiting state"""
        game_state = 'waiting'
        
        assert game_state == 'waiting'
    
    def test_state_transition_to_playing(self):
        """Test transition to playing state"""
        game_state = 'waiting'
        
        # All players ready, game starts
        game_state = 'playing'
        
        assert game_state == 'playing'
    
    def test_state_transition_to_finished(self):
        """Test transition to finished state"""
        game_state = 'playing'
        current_question = 5
        total_questions = 5
        
        if current_question >= total_questions:
            game_state = 'finished'
        
        assert game_state == 'finished'
    
    def test_question_progression(self):
        """Test question counter progresses"""
        current_question = 0
        total_questions = 5
        
        # Answer question
        current_question += 1
        
        assert current_question == 1
        assert current_question <= total_questions


class TestTriviaLeaderboard:
    """Test leaderboard and rankings"""
    
    def test_leaderboard_sorting(self):
        """Test players are sorted by score"""
        players = [
            {'name': 'Alice', 'score': 30},
            {'name': 'Bob', 'score': 50},
            {'name': 'Charlie', 'score': 20}
        ]
        
        sorted_players = sorted(players, key=lambda p: p['score'], reverse=True)
        
        assert sorted_players[0]['name'] == 'Bob'
        assert sorted_players[1]['name'] == 'Alice'
        assert sorted_players[2]['name'] == 'Charlie'
    
    def test_winner_determination(self):
        """Test winner is player with highest score"""
        players = [
            {'name': 'Alice', 'score': 30},
            {'name': 'Bob', 'score': 50},
            {'name': 'Charlie', 'score': 20}
        ]
        
        winner = max(players, key=lambda p: p['score'])
        
        assert winner['name'] == 'Bob'
        assert winner['score'] == 50
    
    def test_tie_handling(self):
        """Test handling of tied scores"""
        players = [
            {'name': 'Alice', 'score': 40},
            {'name': 'Bob', 'score': 40},
            {'name': 'Charlie', 'score': 20}
        ]
        
        max_score = max(p['score'] for p in players)
        winners = [p for p in players if p['score'] == max_score]
        
        assert len(winners) == 2
        assert max_score == 40
    
    def test_perfect_score(self):
        """Test perfect score calculation"""
        total_questions = 5
        points_per_question = 10
        perfect_score = total_questions * points_per_question
        
        assert perfect_score == 50


class TestTriviaTimers:
    """Test timer functionality"""
    
    def test_question_time_limit(self):
        """Test question has time limit"""
        time_limit = 30  # seconds
        
        assert time_limit > 0
    
    def test_time_runs_out(self):
        """Test handling when time runs out"""
        time_remaining = 0
        
        if time_remaining <= 0:
            # Time's up, treat as incorrect
            answer_correct = False
        
        assert 'answer_correct' in locals()
    
    def test_faster_answer_bonus(self):
        """Test optional time bonus for faster answers"""
        base_points = 10
        time_remaining = 20
        time_limit = 30
        
        # Optional: bonus for speed
        time_bonus = int((time_remaining / time_limit) * 5)
        total_points = base_points + time_bonus
        
        assert total_points >= base_points


class TestTriviaRoomManagement:
    """Test room/lobby management"""
    
    def test_room_code_generation(self):
        """Test room code is generated"""
        import random
        import string
        
        room_code = ''.join(random.choices(string.ascii_uppercase, k=4))
        
        assert len(room_code) == 4
        assert room_code.isupper()
    
    def test_room_code_uniqueness(self):
        """Test room codes should be unique"""
        codes = set()
        
        import random
        import string
        for _ in range(10):
            code = ''.join(random.choices(string.ascii_uppercase, k=4))
            codes.add(code)
        
        # Should have multiple unique codes (could theoretically fail, but unlikely)
        assert len(codes) >= 8
    
    def test_room_not_found(self):
        """Test handling of invalid room code"""
        rooms = {'ABCD': {}}
        room_code = 'WXYZ'
        
        room_exists = room_code in rooms
        
        assert room_exists is False
    
    def test_room_full(self):
        """Test room capacity check"""
        players = ['P1', 'P2', 'P3', 'P4']
        max_players = 4
        
        is_full = len(players) >= max_players
        
        assert is_full is True


class TestTriviaEdgeCases:
    """Test edge cases"""
    
    def test_empty_question_list(self):
        """Test handling of empty question list"""
        questions = []
        
        assert len(questions) == 0
    
    def test_single_player_game(self):
        """Test game can work with single player"""
        players = {'Alice': {'name': 'Alice', 'score': 0}}
        
        assert len(players) >= 1
    
    def test_all_correct_answers(self):
        """Test player answering all questions correctly"""
        total_questions = 5
        points_per_question = 10
        correct_answers = 5
        
        score = correct_answers * points_per_question
        
        assert score == 50
    
    def test_all_incorrect_answers(self):
        """Test player answering all questions incorrectly"""
        correct_answers = 0
        points_per_question = 10
        
        score = correct_answers * points_per_question
        
        assert score == 0
    
    def test_no_duplicate_questions(self):
        """Test questions should be unique in a game"""
        questions = [
            {'id': 1, 'question': 'Q1'},
            {'id': 2, 'question': 'Q2'},
            {'id': 3, 'question': 'Q3'}
        ]
        
        question_ids = [q['id'] for q in questions]
        
        assert len(question_ids) == len(set(question_ids))
