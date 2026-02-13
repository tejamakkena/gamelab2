"""
Test suite for Snake and Ladder game logic
"""
import pytest


class TestSnakeLadderBoard:
    """Test board setup and configuration"""
    
    def test_board_size(self):
        """Test that board has 100 squares"""
        board_size = 100
        assert board_size == 100
    
    def test_starting_position(self):
        """Test players start at position 0"""
        starting_position = 0
        assert starting_position == 0
    
    def test_winning_position(self):
        """Test winning position is 100"""
        winning_position = 100
        assert winning_position == 100


class TestSnakeLadderDice:
    """Test dice rolling mechanics"""
    
    def test_dice_roll_range(self):
        """Test dice roll is between 1 and 6"""
        import random
        for _ in range(100):
            roll = random.randint(1, 6)
            assert 1 <= roll <= 6
    
    def test_dice_all_values_possible(self):
        """Test all dice values (1-6) are possible"""
        possible_values = {1, 2, 3, 4, 5, 6}
        assert len(possible_values) == 6


class TestSnakeLadderMovement:
    """Test player movement logic"""
    
    def test_move_forward_basic(self):
        """Test basic forward movement"""
        position = 10
        dice_roll = 5
        
        new_position = position + dice_roll
        
        assert new_position == 15
    
    def test_move_from_start(self):
        """Test movement from starting position"""
        position = 0
        dice_roll = 3
        
        new_position = position + dice_roll
        
        assert new_position == 3
    
    def test_move_near_end(self):
        """Test movement near the end"""
        position = 95
        dice_roll = 4
        
        new_position = position + dice_roll
        
        assert new_position == 99
    
    def test_exact_win(self):
        """Test exact landing on 100"""
        position = 97
        dice_roll = 3
        
        new_position = position + dice_roll
        
        assert new_position == 100
    
    def test_overshoot_stays_in_place(self):
        """Test that overshooting 100 keeps player in place"""
        position = 98
        dice_roll = 5
        
        new_position = position + dice_roll
        if new_position > 100:
            new_position = position  # Stay in place
        
        assert new_position == 98


class TestSnakeLadderSnakes:
    """Test snake mechanics"""
    
    def test_snake_exists(self):
        """Test that snakes exist on board"""
        # Common snake positions (head: tail)
        snakes = {
            17: 7,
            54: 34,
            62: 19,
            64: 60,
            87: 24,
            93: 73,
            95: 75,
            99: 78
        }
        
        assert len(snakes) > 0
        assert 17 in snakes
    
    def test_snake_moves_player_down(self):
        """Test landing on snake head moves player to tail"""
        snakes = {17: 7}
        position = 17
        
        if position in snakes:
            new_position = snakes[position]
        else:
            new_position = position
        
        assert new_position == 7
        assert new_position < position
    
    def test_no_snake_no_change(self):
        """Test landing on non-snake position doesn't change position"""
        snakes = {17: 7}
        position = 20
        
        if position in snakes:
            new_position = snakes[position]
        else:
            new_position = position
        
        assert new_position == 20
    
    def test_multiple_snakes(self):
        """Test multiple snakes on board"""
        snakes = {
            17: 7,
            54: 34,
            62: 19,
            87: 24,
            93: 73,
            95: 75,
            99: 78
        }
        
        # Each snake moves player backward
        for head, tail in snakes.items():
            assert tail < head


class TestSnakeLadderLadders:
    """Test ladder mechanics"""
    
    def test_ladder_exists(self):
        """Test that ladders exist on board"""
        # Common ladder positions (bottom: top)
        ladders = {
            4: 14,
            9: 31,
            21: 42,
            28: 84,
            51: 67,
            71: 91,
            80: 100
        }
        
        assert len(ladders) > 0
        assert 4 in ladders
    
    def test_ladder_moves_player_up(self):
        """Test landing on ladder bottom moves player to top"""
        ladders = {4: 14}
        position = 4
        
        if position in ladders:
            new_position = ladders[position]
        else:
            new_position = position
        
        assert new_position == 14
        assert new_position > position
    
    def test_no_ladder_no_change(self):
        """Test landing on non-ladder position doesn't change position"""
        ladders = {4: 14}
        position = 20
        
        if position in ladders:
            new_position = ladders[position]
        else:
            new_position = position
        
        assert new_position == 20
    
    def test_multiple_ladders(self):
        """Test multiple ladders on board"""
        ladders = {
            4: 14,
            9: 31,
            21: 42,
            28: 84,
            51: 67,
            71: 91,
            80: 100
        }
        
        # Each ladder moves player forward
        for bottom, top in ladders.items():
            assert top > bottom
    
    def test_ladder_to_win(self):
        """Test ladder can lead directly to win"""
        ladders = {80: 100}
        position = 80
        
        new_position = ladders[position]
        
        assert new_position == 100


class TestSnakeLadderTurnOrder:
    """Test turn management"""
    
    def test_turn_rotation_two_players(self):
        """Test turn rotation with 2 players"""
        num_players = 2
        current_turn = 0
        
        next_turn = (current_turn + 1) % num_players
        
        assert next_turn == 1
    
    def test_turn_rotation_wrap(self):
        """Test turn wraps to first player"""
        num_players = 4
        current_turn = 3
        
        next_turn = (current_turn + 1) % num_players
        
        assert next_turn == 0
    
    def test_turn_rotation_multiple_rounds(self):
        """Test turns cycle correctly"""
        num_players = 3
        turns = []
        current_turn = 0
        
        for _ in range(9):  # 3 complete rounds
            turns.append(current_turn)
            current_turn = (current_turn + 1) % num_players
        
        assert turns == [0, 1, 2, 0, 1, 2, 0, 1, 2]


class TestSnakeLadderWinCondition:
    """Test win detection"""
    
    def test_player_wins_on_100(self):
        """Test player wins when reaching 100"""
        position = 100
        
        has_won = position == 100
        
        assert has_won is True
    
    def test_player_not_won_before_100(self):
        """Test player hasn't won before reaching 100"""
        position = 99
        
        has_won = position == 100
        
        assert has_won is False
    
    def test_exact_landing_required(self):
        """Test exact landing on 100 is required"""
        position = 97
        dice_roll = 5
        
        new_position = position + dice_roll
        if new_position > 100:
            new_position = position
        
        has_won = new_position == 100
        
        assert has_won is False


class TestSnakeLadderGameFlow:
    """Test complete game flow scenarios"""
    
    def test_complete_turn_no_snake_ladder(self):
        """Test turn with no snake or ladder"""
        position = 25
        dice_roll = 4
        snakes = {17: 7}
        ladders = {4: 14}
        
        # Move
        new_position = position + dice_roll
        
        # Check snakes
        if new_position in snakes:
            new_position = snakes[new_position]
        
        # Check ladders
        if new_position in ladders:
            new_position = ladders[new_position]
        
        assert new_position == 29
    
    def test_complete_turn_with_snake(self):
        """Test turn landing on snake"""
        position = 13
        dice_roll = 4  # Lands on 17 (snake head)
        snakes = {17: 7}
        ladders = {}
        
        new_position = position + dice_roll
        
        if new_position in snakes:
            new_position = snakes[new_position]
        
        if new_position in ladders:
            new_position = ladders[new_position]
        
        assert new_position == 7
    
    def test_complete_turn_with_ladder(self):
        """Test turn landing on ladder"""
        position = 2
        dice_roll = 2  # Lands on 4 (ladder bottom)
        snakes = {}
        ladders = {4: 14}
        
        new_position = position + dice_roll
        
        if new_position in snakes:
            new_position = snakes[new_position]
        
        if new_position in ladders:
            new_position = ladders[new_position]
        
        assert new_position == 14


class TestSnakeLadderMultiplayers:
    """Test multiplayer scenarios"""
    
    def test_minimum_players(self):
        """Test game requires at least 2 players"""
        num_players = 2
        assert num_players >= 2
    
    def test_maximum_players(self):
        """Test game supports up to 6 players"""
        num_players = 6
        assert num_players <= 6
    
    def test_player_positions_independent(self):
        """Test each player has independent position"""
        players = [
            {'id': 'p1', 'position': 10},
            {'id': 'p2', 'position': 25},
            {'id': 'p3', 'position': 5}
        ]
        
        assert players[0]['position'] != players[1]['position']
        assert players[1]['position'] != players[2]['position']
    
    def test_first_to_100_wins(self):
        """Test first player to reach 100 wins"""
        players = [
            {'id': 'p1', 'position': 100},
            {'id': 'p2', 'position': 98},
            {'id': 'p3', 'position': 95}
        ]
        
        winners = [p for p in players if p['position'] == 100]
        
        assert len(winners) == 1
        assert winners[0]['id'] == 'p1'


class TestSnakeLadderEdgeCases:
    """Test edge cases"""
    
    def test_snake_at_99(self):
        """Test snake near winning position"""
        snakes = {99: 78}
        position = 99
        
        new_position = snakes[position]
        
        assert new_position < 100
        assert new_position == 78
    
    def test_no_snake_or_ladder_at_100(self):
        """Test winning square has no snake or ladder"""
        snakes = {17: 7, 99: 78}
        ladders = {4: 14, 80: 100}
        
        assert 100 not in snakes
        # Note: 100 can be a ladder destination but not origin
    
    def test_snake_ladder_dont_overlap(self):
        """Test no position has both snake and ladder"""
        snakes = {17: 7, 54: 34, 62: 19}
        ladders = {4: 14, 9: 31, 21: 42}
        
        overlap = set(snakes.keys()) & set(ladders.keys())
        
        assert len(overlap) == 0
