class HangmanGame:
    MAX_WRONG_GUESSES = 6

    def __init__(self, room_code):
        self.room_code = room_code
        self.players = {}  # {player_id: {'id', 'name', 'is_host', 'correct_guesses'}}
        self.host_id = None
        self.state = 'WAITING'  # WAITING, PLAYING, FINISHED
        self.secret_word = None
        self.hint = ''
        self.guessed_letters = set()
        self.wrong_guesses = []
        self.winner = None  # 'guessers' or 'host'

    def add_player(self, player_id, name, is_host=False):
        self.players[player_id] = {
            'id': player_id,
            'name': name,
            'is_host': is_host,
            'correct_guesses': 0,
        }
        if is_host:
            self.host_id = player_id

    def remove_player(self, player_id):
        self.players.pop(player_id, None)

    def set_word(self, word, hint=''):
        self.secret_word = word.upper().strip()
        self.hint = hint.strip()
        self.guessed_letters = set()
        self.wrong_guesses = []
        self.winner = None
        self.state = 'PLAYING'

    def get_display_word(self):
        if not self.secret_word:
            return []
        result = []
        for ch in self.secret_word:
            if ch == ' ':
                result.append(' ')
            elif ch in self.guessed_letters:
                result.append(ch)
            else:
                result.append('_')
        return result

    def guess_letter(self, letter):
        """Returns (outcome, letter) where outcome is one of:
        'correct', 'wrong', 'win', 'lose', 'already_guessed', 'invalid'
        """
        if not letter or len(letter) != 1 or not letter.isalpha():
            return 'invalid', None

        letter = letter.upper()

        if letter in self.guessed_letters:
            return 'already_guessed', letter

        self.guessed_letters.add(letter)

        if letter in self.secret_word:
            display = self.get_display_word()
            if '_' not in display:
                self.state = 'FINISHED'
                self.winner = 'guessers'
                return 'win', letter
            return 'correct', letter
        else:
            self.wrong_guesses.append(letter)
            if len(self.wrong_guesses) >= self.MAX_WRONG_GUESSES:
                self.state = 'FINISHED'
                self.winner = 'host'
                return 'lose', letter
            return 'wrong', letter

    def get_public_state(self, reveal_word=False):
        return {
            'state': self.state,
            'display_word': self.get_display_word(),
            'secret_word': self.secret_word if reveal_word else None,
            'hint': self.hint,
            'guessed_letters': sorted(self.guessed_letters),
            'wrong_guesses': self.wrong_guesses,
            'wrong_count': len(self.wrong_guesses),
            'max_wrong': self.MAX_WRONG_GUESSES,
            'winner': self.winner,
            'players': list(self.players.values()),
        }
