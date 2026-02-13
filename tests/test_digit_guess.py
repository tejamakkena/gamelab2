"""
Test suite for Digit Guess game logic (Bulls & Cows)
"""
import pytest
from games.digit_guess.game_logic import (
    validate_number,
    calculate_feedback,
    check_winner,
    get_game_state_display
)


class TestDigitGuessValidation:
    """Test number validation"""
    
    def test_valid_4_digit_number(self):
        """Test that valid 4-digit number passes"""
        is_valid, error = validate_number("1234")
        assert is_valid is True
        assert error is None
    
    def test_valid_with_zeros(self):
        """Test that numbers with zeros are valid"""
        is_valid, error = validate_number("0123")
        assert is_valid is True
        assert error is None
    
    def test_valid_all_same_digits(self):
        """Test that same digits are valid"""
        is_valid, error = validate_number("1111")
        assert is_valid is True
        assert error is None
    
    def test_invalid_too_short(self):
        """Test that numbers too short are invalid"""
        is_valid, error = validate_number("123")
        assert is_valid is False
        assert "exactly 4 digits" in error
    
    def test_invalid_too_long(self):
        """Test that numbers too long are invalid"""
        is_valid, error = validate_number("12345")
        assert is_valid is False
        assert "exactly 4 digits" in error
    
    def test_invalid_contains_letters(self):
        """Test that numbers with letters are invalid"""
        is_valid, error = validate_number("12a4")
        assert is_valid is False
        assert "only digits" in error
    
    def test_invalid_contains_special_chars(self):
        """Test that numbers with special characters are invalid"""
        is_valid, error = validate_number("12-4")
        assert is_valid is False
        assert "only digits" in error
    
    def test_validation_with_whitespace(self):
        """Test that whitespace is handled"""
        is_valid, error = validate_number("  1234  ")
        assert is_valid is True
        assert error is None
    
    def test_validation_with_integer_input(self):
        """Test that integer input is handled"""
        is_valid, error = validate_number(1234)
        assert is_valid is True
        assert error is None
    
    def test_empty_string(self):
        """Test that empty string is invalid"""
        is_valid, error = validate_number("")
        assert is_valid is False
        assert "exactly 4 digits" in error


class TestDigitGuessFeedback:
    """Test feedback calculation"""
    
    def test_exact_match(self):
        """Test perfect guess (all 4 correct)"""
        feedback = calculate_feedback("1234", "1234")
        assert feedback['correct_positions'] == 4
        assert feedback['correct_digits'] == 4
    
    def test_no_match(self):
        """Test no correct digits"""
        feedback = calculate_feedback("1234", "5678")
        assert feedback['correct_positions'] == 0
        assert feedback['correct_digits'] == 0
    
    def test_all_correct_digits_wrong_positions(self):
        """Test all digits correct but in wrong positions"""
        feedback = calculate_feedback("1234", "4321")
        assert feedback['correct_positions'] == 0
        assert feedback['correct_digits'] == 4
    
    def test_partial_correct_positions(self):
        """Test some digits in correct positions"""
        feedback = calculate_feedback("1234", "1256")
        assert feedback['correct_positions'] == 2  # 1 and 2
        assert feedback['correct_digits'] == 2
    
    def test_mixed_correct(self):
        """Test mix of correct positions and wrong positions"""
        feedback = calculate_feedback("1234", "1324")
        assert feedback['correct_positions'] == 2  # 1 and 4
        assert feedback['correct_digits'] == 4  # all digits present
    
    def test_duplicate_digits_in_secret(self):
        """Test when secret has duplicate digits"""
        feedback = calculate_feedback("1123", "1111")
        assert feedback['correct_positions'] == 2  # first two 1s
        assert feedback['correct_digits'] == 2  # only 2 of the 4 guessed 1s are in secret
    
    def test_duplicate_digits_in_guess(self):
        """Test when guess has duplicate digits"""
        feedback = calculate_feedback("1234", "1111")
        assert feedback['correct_positions'] == 1  # only first 1
        assert feedback['correct_digits'] == 1  # only one 1 in secret
    
    def test_single_correct_digit_wrong_position(self):
        """Test single correct digit in wrong position"""
        feedback = calculate_feedback("1234", "5621")
        assert feedback['correct_positions'] == 0  # No digits in correct position
        assert feedback['correct_digits'] == 2  # 2 and 1 are in the secret
    
    def test_with_zeros(self):
        """Test feedback with zeros"""
        feedback = calculate_feedback("0123", "3210")
        assert feedback['correct_positions'] == 0
        assert feedback['correct_digits'] == 4


class TestDigitGuessWinCondition:
    """Test win condition checking"""
    
    def test_winning_guess(self):
        """Test that exact match is detected as win"""
        assert check_winner("1234", "1234") is True
    
    def test_losing_guess(self):
        """Test that non-exact match is not a win"""
        assert check_winner("1234", "1235") is False
    
    def test_close_guess_not_win(self):
        """Test that close guess (3/4 correct) is not a win"""
        assert check_winner("1234", "1235") is False
    
    def test_all_correct_positions_needed(self):
        """Test that all positions must match"""
        assert check_winner("1234", "4321") is False
    
    def test_string_vs_int_comparison(self):
        """Test that string and int are handled correctly"""
        assert check_winner("1234", 1234) is True
        assert check_winner(1234, "1234") is True


class TestDigitGuessGameStateDisplay:
    """Test game state display formatting"""
    
    def test_empty_guess_history(self):
        """Test formatting with no guesses"""
        guesses = []
        display = get_game_state_display(guesses, "Player1")
        assert display == []
    
    def test_single_guess_display(self):
        """Test formatting with one guess"""
        guesses = [{
            'guess': '1234',
            'feedback': {'correct_positions': 2, 'correct_digits': 3}
        }]
        display = get_game_state_display(guesses, "Player1")
        
        assert len(display) == 1
        assert display[0]['guess'] == '1234'
        assert '2 in position' in display[0]['feedback']
        assert '3 total correct' in display[0]['feedback']
        assert display[0]['player'] == 'Player1'
    
    def test_multiple_guesses_display(self):
        """Test formatting with multiple guesses"""
        guesses = [
            {'guess': '1234', 'feedback': {'correct_positions': 1, 'correct_digits': 2}},
            {'guess': '5678', 'feedback': {'correct_positions': 0, 'correct_digits': 1}},
            {'guess': '1357', 'feedback': {'correct_positions': 3, 'correct_digits': 3}}
        ]
        display = get_game_state_display(guesses, "Player2")
        
        assert len(display) == 3
        assert all(d['player'] == 'Player2' for d in display)
        assert display[0]['guess'] == '1234'
        assert display[1]['guess'] == '5678'
        assert display[2]['guess'] == '1357'
    
    def test_display_with_perfect_guess(self):
        """Test formatting when guess is perfect"""
        guesses = [{
            'guess': '9876',
            'feedback': {'correct_positions': 4, 'correct_digits': 4}
        }]
        display = get_game_state_display(guesses, "Winner")
        
        assert len(display) == 1
        assert '4 in position' in display[0]['feedback']
        assert '4 total correct' in display[0]['feedback']
    
    def test_display_with_no_correct(self):
        """Test formatting when no digits are correct"""
        guesses = [{
            'guess': '0000',
            'feedback': {'correct_positions': 0, 'correct_digits': 0}
        }]
        display = get_game_state_display(guesses, "Player1")
        
        assert len(display) == 1
        assert '0 in position' in display[0]['feedback']
        assert '0 total correct' in display[0]['feedback']


class TestDigitGuessEdgeCases:
    """Test edge cases"""
    
    def test_all_zeros(self):
        """Test with all zeros"""
        feedback = calculate_feedback("0000", "0000")
        assert feedback['correct_positions'] == 4
        assert feedback['correct_digits'] == 4
    
    def test_all_nines(self):
        """Test with all nines"""
        feedback = calculate_feedback("9999", "9999")
        assert feedback['correct_positions'] == 4
        assert feedback['correct_digits'] == 4
    
    def test_alternating_pattern(self):
        """Test with alternating pattern"""
        feedback = calculate_feedback("1212", "2121")
        assert feedback['correct_positions'] == 0
        assert feedback['correct_digits'] == 4
    
    def test_sequential_numbers(self):
        """Test with sequential numbers"""
        feedback = calculate_feedback("1234", "2345")
        assert feedback['correct_positions'] == 0
        assert feedback['correct_digits'] == 3  # 2, 3, 4
    
    def test_reversed_numbers(self):
        """Test with reversed numbers"""
        feedback = calculate_feedback("1234", "4321")
        assert feedback['correct_positions'] == 0
        assert feedback['correct_digits'] == 4
    
    def test_feedback_consistency(self):
        """Test that feedback is consistent with check_winner"""
        secret = "5678"
        guess = "5678"
        
        feedback = calculate_feedback(secret, guess)
        is_winner = check_winner(guess, secret)
        
        # If all positions correct, should be a winner
        if feedback['correct_positions'] == 4:
            assert is_winner is True
        else:
            assert is_winner is False
