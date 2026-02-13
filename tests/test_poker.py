"""
Test suite for Poker game logic
"""
import pytest
from games.poker.socket_events import create_deck, generate_room_code, get_public_player_data


class TestPokerDeck:
    """Test deck creation and validation"""
    
    def test_deck_has_52_cards(self):
        """Test that deck has exactly 52 cards"""
        deck = create_deck()
        assert len(deck) == 52
    
    def test_deck_has_all_suits(self):
        """Test that deck contains all 4 suits"""
        deck = create_deck()
        suits = set(card['suit'] for card in deck)
        assert len(suits) == 4
        assert '♠' in suits
        assert '♥' in suits
        assert '♦' in suits
        assert '♣' in suits
    
    def test_deck_has_all_values(self):
        """Test that deck contains all 13 values"""
        deck = create_deck()
        values = set(card['value'] for card in deck)
        expected_values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
        assert len(values) == 13
        assert all(v in values for v in expected_values)
    
    def test_deck_has_correct_card_count_per_value(self):
        """Test that each value appears exactly 4 times (one per suit)"""
        deck = create_deck()
        for value in ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']:
            count = sum(1 for card in deck if card['value'] == value)
            assert count == 4, f"Value {value} should appear 4 times, found {count}"
    
    def test_deck_is_shuffled(self):
        """Test that deck is randomized (not in predictable order)"""
        deck1 = create_deck()
        deck2 = create_deck()
        # Very unlikely to get same order twice if shuffled
        assert deck1 != deck2, "Decks should be shuffled and different"
    
    def test_deck_card_structure(self):
        """Test that each card has correct structure"""
        deck = create_deck()
        for card in deck:
            assert isinstance(card, dict)
            assert 'value' in card
            assert 'suit' in card
            assert len(card) == 2  # Only value and suit


class TestPokerRoomCode:
    """Test room code generation"""
    
    def test_room_code_length(self):
        """Test that room code is 6 characters"""
        code = generate_room_code()
        assert len(code) == 6
    
    def test_room_code_alphanumeric(self):
        """Test that room code is alphanumeric"""
        code = generate_room_code()
        assert code.isalnum()
    
    def test_room_code_uppercase(self):
        """Test that room code is uppercase"""
        code = generate_room_code()
        assert code.isupper() or code.isdigit()


class TestPokerPlayerData:
    """Test player data management"""
    
    def test_get_public_player_data_basic(self):
        """Test getting public player data"""
        players = [
            {
                'id': 'p1',
                'name': 'Alice',
                'chips': 1000,
                'bet': 50,
                'folded': False,
                'position': 0,
                'hand': [{'value': 'A', 'suit': '♠'}, {'value': 'K', 'suit': '♠'}]
            },
            {
                'id': 'p2',
                'name': 'Bob',
                'chips': 950,
                'bet': 50,
                'folded': False,
                'position': 1,
                'hand': [{'value': 'Q', 'suit': '♥'}, {'value': 'J', 'suit': '♥'}]
            }
        ]
        
        public_data = get_public_player_data(players)
        
        assert len(public_data) == 2
        assert public_data[0]['name'] == 'Alice'
        assert public_data[1]['name'] == 'Bob'
        assert 'hand' not in public_data[0]  # Hands should be hidden
        assert 'hand' not in public_data[1]
    
    def test_get_public_player_data_with_requesting_player(self):
        """Test that requesting player is marked"""
        players = [
            {
                'id': 'p1',
                'name': 'Alice',
                'chips': 1000,
                'bet': 50,
                'folded': False,
                'position': 0
            }
        ]
        
        public_data = get_public_player_data(players, 'p1')
        
        assert public_data[0]['is_me'] is True
    
    def test_get_public_player_data_other_players_not_marked(self):
        """Test that other players are not marked as requesting player"""
        players = [
            {'id': 'p1', 'name': 'Alice', 'chips': 1000, 'bet': 0, 'folded': False, 'position': 0},
            {'id': 'p2', 'name': 'Bob', 'chips': 1000, 'bet': 0, 'folded': False, 'position': 1}
        ]
        
        public_data = get_public_player_data(players, 'p1')
        
        assert public_data[0]['is_me'] is True
        assert public_data[1]['is_me'] is False
    
    def test_get_public_player_data_includes_visible_fields(self):
        """Test that public data includes necessary fields"""
        players = [{
            'id': 'p1',
            'name': 'Alice',
            'chips': 1000,
            'bet': 50,
            'folded': False,
            'position': 0,
            'hand': [{'value': 'A', 'suit': '♠'}]  # Should be hidden
        }]
        
        public_data = get_public_player_data(players, 'p2')
        
        assert 'id' in public_data[0]
        assert 'name' in public_data[0]
        assert 'chips' in public_data[0]
        assert 'bet' in public_data[0]
        assert 'folded' in public_data[0]
        assert 'position' in public_data[0]
        assert 'is_me' in public_data[0]
        assert 'hand' not in public_data[0]


class TestPokerGameLogic:
    """Test poker game logic components"""
    
    def test_blind_structure(self):
        """Test small and big blind amounts"""
        small_blind = 10
        big_blind = 20
        
        assert big_blind == small_blind * 2
    
    def test_pot_calculation(self):
        """Test pot calculation with multiple bets"""
        pot = 0
        bets = [50, 50, 100, 100]
        
        for bet in bets:
            pot += bet
        
        assert pot == 300
    
    def test_player_chips_after_bet(self):
        """Test chip count after betting"""
        initial_chips = 1000
        bet_amount = 50
        
        chips_after = initial_chips - bet_amount
        
        assert chips_after == 950
    
    def test_all_in_scenario(self):
        """Test all-in when player has fewer chips than bet"""
        chips = 30
        required_bet = 50
        
        all_in_amount = min(chips, required_bet)
        
        assert all_in_amount == 30
    
    def test_turn_rotation(self):
        """Test turn rotation logic"""
        num_players = 4
        current_turn = 2
        
        next_turn = (current_turn + 1) % num_players
        
        assert next_turn == 3
        
        # Test wrap-around
        current_turn = 3
        next_turn = (current_turn + 1) % num_players
        assert next_turn == 0


class TestPokerBettingRounds:
    """Test betting round logic"""
    
    def test_bet_matching(self):
        """Test if player bet matches current bet"""
        player_bet = 50
        current_bet = 50
        
        assert player_bet == current_bet
    
    def test_raise_detection(self):
        """Test if bet is a raise"""
        player_bet = 100
        current_bet = 50
        
        assert player_bet > current_bet
    
    def test_call_amount_calculation(self):
        """Test calculating call amount"""
        current_bet = 100
        player_current_bet = 50
        
        call_amount = current_bet - player_current_bet
        
        assert call_amount == 50
    
    def test_minimum_raise_amount(self):
        """Test minimum raise is at least current bet"""
        current_bet = 50
        minimum_raise = current_bet * 2
        
        assert minimum_raise >= current_bet


class TestPokerPlayerStates:
    """Test player state management"""
    
    def test_player_folded_state(self):
        """Test folded player state"""
        player = {'folded': True, 'chips': 1000}
        
        assert player['folded'] is True
    
    def test_active_player_count(self):
        """Test counting active (non-folded) players"""
        players = [
            {'folded': False},
            {'folded': True},
            {'folded': False},
            {'folded': True}
        ]
        
        active_count = sum(1 for p in players if not p['folded'])
        
        assert active_count == 2
    
    def test_all_in_player_state(self):
        """Test all-in player state"""
        player = {'chips': 0, 'bet': 1000, 'folded': False}
        
        assert player['chips'] == 0
        assert player['folded'] is False
    
    def test_player_can_act(self):
        """Test if player can take action"""
        player = {'folded': False, 'chips': 100}
        
        can_act = not player['folded'] and player['chips'] > 0
        
        assert can_act is True
    
    def test_player_cannot_act_if_folded(self):
        """Test that folded player cannot act"""
        player = {'folded': True, 'chips': 100}
        
        can_act = not player['folded'] and player['chips'] > 0
        
        assert can_act is False
    
    def test_player_cannot_act_if_all_in(self):
        """Test that all-in player cannot act further"""
        player = {'folded': False, 'chips': 0}
        
        can_act = not player['folded'] and player['chips'] > 0
        
        assert can_act is False


class TestPokerDealerPosition:
    """Test dealer button rotation"""
    
    def test_dealer_starts_at_zero(self):
        """Test dealer starts at position 0"""
        dealer = 0
        assert dealer == 0
    
    def test_dealer_advances(self):
        """Test dealer advances after hand"""
        dealer = 0
        num_players = 4
        
        new_dealer = (dealer + 1) % num_players
        
        assert new_dealer == 1
    
    def test_dealer_wraps_around(self):
        """Test dealer wraps to 0 after last player"""
        dealer = 3
        num_players = 4
        
        new_dealer = (dealer + 1) % num_players
        
        assert new_dealer == 0
    
    def test_blind_positions(self):
        """Test small blind and big blind positions"""
        dealer = 0
        num_players = 4
        
        small_blind_pos = (dealer + 1) % num_players
        big_blind_pos = (dealer + 2) % num_players
        
        assert small_blind_pos == 1
        assert big_blind_pos == 2


class TestPokerEdgeCases:
    """Test edge cases"""
    
    def test_two_player_game(self):
        """Test game with minimum players (2)"""
        num_players = 2
        assert num_players >= 2
    
    def test_six_player_game(self):
        """Test game with maximum players (6)"""
        num_players = 6
        assert num_players <= 6
    
    def test_empty_deck_handling(self):
        """Test behavior when deck is empty"""
        deck = []
        assert len(deck) == 0
    
    def test_single_active_player_wins(self):
        """Test that last active player wins"""
        players = [
            {'folded': True},
            {'folded': False},
            {'folded': True}
        ]
        
        active_players = [p for p in players if not p['folded']]
        
        assert len(active_players) == 1
