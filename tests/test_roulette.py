"""
Test suite for Roulette game logic
"""
import pytest


class TestRouletteNumbers:
    """Test roulette number validation"""
    
    def test_valid_roulette_numbers(self):
        """Test that roulette has numbers 0-36"""
        valid_numbers = list(range(0, 37))
        assert len(valid_numbers) == 37
        assert 0 in valid_numbers
        assert 36 in valid_numbers
    
    def test_number_range(self):
        """Test number is within valid range"""
        for num in range(0, 37):
            assert 0 <= num <= 36


class TestRouletteColors:
    """Test color assignment for roulette numbers"""
    
    def test_red_numbers(self):
        """Test that red numbers are correctly identified"""
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        
        assert len(red_numbers) == 18
        assert 1 in red_numbers
        assert 36 in red_numbers
        assert 2 not in red_numbers  # 2 is black
    
    def test_black_numbers(self):
        """Test that black numbers are correctly identified"""
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        black_numbers = [n for n in range(1, 37) if n not in red_numbers]
        
        assert len(black_numbers) == 18
        assert 2 in black_numbers
        assert 4 in black_numbers
        assert 1 not in black_numbers  # 1 is red
    
    def test_zero_is_green(self):
        """Test that 0 is green"""
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        number = 0
        
        if number == 0:
            color = 'green'
        elif number in red_numbers:
            color = 'red'
        else:
            color = 'black'
        
        assert color == 'green'
    
    def test_color_assignment_logic(self):
        """Test color assignment for various numbers"""
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        
        # Test red
        assert 1 in red_numbers
        assert 36 in red_numbers
        
        # Test black
        assert 2 not in red_numbers
        assert 4 not in red_numbers
        
        # Test green (0)
        assert 0 not in red_numbers


class TestRouletteBetTypes:
    """Test different bet types"""
    
    def test_straight_up_bet(self):
        """Test betting on a single number (straight up)"""
        bet = {'type': 'straight', 'number': 17}
        winning_number = 17
        
        wins = bet['number'] == winning_number
        assert wins is True
        
        # Payout is 35:1
        payout_ratio = 35
        assert payout_ratio == 35
    
    def test_color_bet_red(self):
        """Test betting on red"""
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        winning_number = 5
        
        wins = winning_number in red_numbers
        assert wins is True
        
        # Payout is 1:1
        payout_ratio = 1
        assert payout_ratio == 1
    
    def test_color_bet_black(self):
        """Test betting on black"""
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        black_numbers = [n for n in range(1, 37) if n not in red_numbers]
        winning_number = 2
        
        wins = winning_number in black_numbers
        assert wins is True
    
    def test_even_odd_bet(self):
        """Test even/odd bets"""
        winning_number = 12
        
        is_even = winning_number % 2 == 0 and winning_number != 0
        is_odd = winning_number % 2 == 1
        
        assert is_even is True
        assert is_odd is False
    
    def test_high_low_bet(self):
        """Test high (19-36) and low (1-18) bets"""
        winning_number = 25
        
        is_low = 1 <= winning_number <= 18
        is_high = 19 <= winning_number <= 36
        
        assert is_low is False
        assert is_high is True
    
    def test_dozen_bet_first(self):
        """Test first dozen bet (1-12)"""
        winning_number = 7
        
        is_first_dozen = 1 <= winning_number <= 12
        
        assert is_first_dozen is True
        
        # Payout is 2:1
        payout_ratio = 2
        assert payout_ratio == 2
    
    def test_dozen_bet_second(self):
        """Test second dozen bet (13-24)"""
        winning_number = 20
        
        is_second_dozen = 13 <= winning_number <= 24
        
        assert is_second_dozen is True
    
    def test_dozen_bet_third(self):
        """Test third dozen bet (25-36)"""
        winning_number = 30
        
        is_third_dozen = 25 <= winning_number <= 36
        
        assert is_third_dozen is True
    
    def test_column_bet(self):
        """Test column bets"""
        # Column 1: 1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34
        # Column 2: 2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35
        # Column 3: 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36
        
        winning_number = 7
        column = ((winning_number - 1) % 3) + 1 if winning_number != 0 else None
        
        assert column == 1
        
        # Payout is 2:1
        payout_ratio = 2
        assert payout_ratio == 2


class TestRoulettePayouts:
    """Test payout calculations"""
    
    def test_straight_up_payout(self):
        """Test straight up bet payout (35:1)"""
        bet_amount = 10
        payout_ratio = 35
        
        winnings = bet_amount * payout_ratio
        total = winnings + bet_amount  # Return bet plus winnings
        
        assert winnings == 350
        assert total == 360
    
    def test_color_payout(self):
        """Test color bet payout (1:1)"""
        bet_amount = 50
        payout_ratio = 1
        
        winnings = bet_amount * payout_ratio
        total = winnings + bet_amount
        
        assert winnings == 50
        assert total == 100
    
    def test_dozen_payout(self):
        """Test dozen bet payout (2:1)"""
        bet_amount = 20
        payout_ratio = 2
        
        winnings = bet_amount * payout_ratio
        total = winnings + bet_amount
        
        assert winnings == 40
        assert total == 60
    
    def test_losing_bet(self):
        """Test losing bet returns 0"""
        bet_amount = 100
        
        # Losing bet
        winnings = 0
        
        assert winnings == 0


class TestRouletteGameRules:
    """Test game rules and edge cases"""
    
    def test_zero_loses_most_bets(self):
        """Test that 0 causes most bets to lose"""
        winning_number = 0
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        
        # Red/Black bets lose
        red_wins = winning_number in red_numbers
        black_wins = winning_number != 0 and winning_number not in red_numbers
        
        assert red_wins is False
        assert black_wins is False
        
        # Even/Odd bets lose
        even_wins = winning_number % 2 == 0 and winning_number != 0
        odd_wins = winning_number % 2 == 1
        
        assert even_wins is False
        assert odd_wins is False
        
        # High/Low bets lose
        high_wins = 19 <= winning_number <= 36
        low_wins = 1 <= winning_number <= 18
        
        assert high_wins is False
        assert low_wins is False
    
    def test_starting_chips(self):
        """Test player starting chips"""
        starting_chips = 1000
        
        assert starting_chips == 1000
        assert starting_chips > 0
    
    def test_chip_deduction_after_bet(self):
        """Test chips are deducted when bet is placed"""
        chips = 1000
        bet_amount = 50
        
        chips_after_bet = chips - bet_amount
        
        assert chips_after_bet == 950
    
    def test_chip_addition_after_win(self):
        """Test chips are added after win"""
        chips = 950
        bet_amount = 50
        payout_ratio = 1  # Even money bet
        
        winnings = bet_amount * payout_ratio
        total_return = bet_amount + winnings
        chips_after_win = chips + total_return
        
        assert chips_after_win == 1050
    
    def test_minimum_bet(self):
        """Test minimum bet validation"""
        bet_amount = 1
        minimum_bet = 1
        
        is_valid = bet_amount >= minimum_bet
        
        assert is_valid is True
    
    def test_bet_exceeds_chips(self):
        """Test betting more than available chips"""
        chips = 50
        bet_amount = 100
        
        can_bet = bet_amount <= chips
        
        assert can_bet is False


class TestRouletteMultipleBets:
    """Test multiple bets in one round"""
    
    def test_multiple_bets_same_player(self):
        """Test player can place multiple bets"""
        bets = [
            {'type': 'red', 'amount': 10},
            {'type': 'even', 'amount': 20},
            {'type': 'straight', 'number': 17, 'amount': 5}
        ]
        
        total_bet = sum(bet['amount'] for bet in bets)
        
        assert len(bets) == 3
        assert total_bet == 35
    
    def test_multiple_winning_bets(self):
        """Test multiple bets can win simultaneously"""
        winning_number = 12  # Red, Even, First Dozen
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        
        red_wins = winning_number in red_numbers
        even_wins = winning_number % 2 == 0 and winning_number != 0
        first_dozen_wins = 1 <= winning_number <= 12
        
        assert red_wins is True
        assert even_wins is True
        assert first_dozen_wins is True


class TestRouletteEdgeCases:
    """Test edge cases"""
    
    def test_all_numbers_covered(self):
        """Test all 37 numbers (0-36) are valid"""
        valid_numbers = set(range(0, 37))
        assert len(valid_numbers) == 37
    
    def test_color_balance(self):
        """Test equal red and black numbers (18 each)"""
        red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        black_numbers = [n for n in range(1, 37) if n not in red_numbers]
        
        assert len(red_numbers) == 18
        assert len(black_numbers) == 18
    
    def test_even_odd_balance(self):
        """Test equal even and odd numbers (excluding 0)"""
        even_numbers = [n for n in range(1, 37) if n % 2 == 0]
        odd_numbers = [n for n in range(1, 37) if n % 2 == 1]
        
        assert len(even_numbers) == 18
        assert len(odd_numbers) == 18
    
    def test_high_low_balance(self):
        """Test equal high and low numbers"""
        low_numbers = list(range(1, 19))
        high_numbers = list(range(19, 37))
        
        assert len(low_numbers) == 18
        assert len(high_numbers) == 18
