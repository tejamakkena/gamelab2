console.log('Digit Guess script loading...');
console.log('User:', window.user);

// Socket connection
const socket = io();

// Game state
let gameState = {
    roomCode: null,
    players: [],
    isHost: false,
    myPlayerId: null,
    currentTurn: null,
    mySecretNumber: null,
    gameStarted: false,
    gameOver: false,
    guessHistory: {}
};

// DOM elements
const sections = {
    modeSelection: document.getElementById('mode-selection'),
    joinRoom: document.getElementById('join-room-section'),
    waitingRoom: document.getElementById('waiting-room'),
    setNumber: document.getElementById('set-number-section'),
    gameScreen: document.getElementById('game-screen'),
    gameOver: document.getElementById('game-over-section')
};

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    console.log('DOM loaded, initializing Digit Guess...');
    initializeEventListeners();
});

function initializeEventListeners() {
    // Mode selection
    document.getElementById('create-room-btn').addEventListener('click', createRoom);
    document.getElementById('join-room-btn-start').addEventListener('click', showJoinRoom);
    
    // Join room
    document.getElementById('back-to-mode-btn').addEventListener('click', backToMode);
    document.getElementById('join-room-submit-btn').addEventListener('click', joinRoom);
    document.getElementById('room-code-input').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') joinRoom();
    });
    
    // Waiting room
    document.getElementById('copy-code-btn').addEventListener('click', copyRoomCode);
    document.getElementById('start-game-btn').addEventListener('click', startGame);
    document.getElementById('leave-room-btn').addEventListener('click', leaveRoom);
    
    // Set secret number
    document.getElementById('submit-secret-btn').addEventListener('click', submitSecretNumber);
    document.getElementById('secret-number-input').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') submitSecretNumber();
    });
    
    // Game
    document.getElementById('submit-guess-btn').addEventListener('click', submitGuess);
    document.getElementById('guess-input').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') submitGuess();
    });
    document.getElementById('leave-game-btn').addEventListener('click', leaveGame);
    
    // Game over
    document.getElementById('play-again-btn').addEventListener('click', playAgain);
    document.getElementById('exit-game-btn').addEventListener('click', exitToMenu);
    
    // Socket listeners
    setupSocketListeners();
}

function setupSocketListeners() {
    socket.on('connect', () => {
        console.log('Socket connected:', socket.id);
        gameState.myPlayerId = socket.id;
    });

    socket.on('room_created', (data) => {
        console.log('Room created:', data);
        gameState.roomCode = data.room_code;
        gameState.players = data.players || [];
        gameState.isHost = true;
        gameState.myPlayerId = data.player_id;
        showWaitingRoom();
        updatePlayersList();
    });

    socket.on('room_joined', (data) => {
        console.log('Room joined:', data);
        gameState.roomCode = data.room_code;
        gameState.players = data.players;
        gameState.isHost = data.is_host;
        gameState.myPlayerId = data.player_id;
        showWaitingRoom();
        updatePlayersList();
    });

    socket.on('player_joined', (data) => {
        console.log('Player joined:', data);
        gameState.players = data.players;
        updatePlayersList();
    });

    socket.on('player_left', (data) => {
        console.log('Player left:', data);
        gameState.players = data.players;
        updatePlayersList();
        
        if (gameState.gameStarted && !gameState.gameOver) {
            showMessage('Opponent left the game!');
            setTimeout(() => exitToMenu(), 2000);
        }
    });

    socket.on('game_started', (data) => {
        console.log('Game started:', data);
        gameState.gameStarted = true;
        showSetNumberSection();
    });

    socket.on('number_set', (data) => {
        console.log('Number set:', data);
        if (data.all_ready) {
            // Both players ready, will receive guessing_phase_started
        } else {
            // Show waiting message
            document.getElementById('secret-number-input').disabled = true;
            document.getElementById('submit-secret-btn').disabled = true;
            document.getElementById('waiting-opponent-msg').style.display = 'block';
        }
    });

    socket.on('guessing_phase_started', (data) => {
        console.log('Guessing phase started:', data);
        gameState.currentTurn = data.current_turn;
        gameState.players = data.players;
        showGameScreen();
        updateTurnIndicator();
    });

    socket.on('guess_made', (data) => {
        console.log('Guess made:', data);
        gameState.currentTurn = data.current_turn;
        gameState.guessHistory = data.guess_history;
        updateGuessHistory();
        updateTurnIndicator();
        
        // Clear input if it was my turn
        if (data.player_id === gameState.myPlayerId) {
            document.getElementById('guess-input').value = '';
        }
    });

    socket.on('game_over', (data) => {
        console.log('Game over:', data);
        gameState.gameOver = true;
        showGameOver(data);
    });

    socket.on('error', (data) => {
        console.error('Error:', data.message);
        showMessage(data.message);
    });
}

// UI Functions
function showSection(section) {
    Object.values(sections).forEach(s => s.classList.add('hidden'));
    section.classList.remove('hidden');
}

function showMessage(message) {
    const toast = document.getElementById('message-toast');
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

function createRoom() {
    console.log('Creating room...');
    const playerName = window.user?.name || 'Player 1';
    socket.emit('create_room', {
        game_type: 'digit_guess',
        player_name: playerName
    });
}

function showJoinRoom() {
    showSection(sections.joinRoom);
    document.getElementById('room-code-input').focus();
}

function backToMode() {
    showSection(sections.modeSelection);
    document.getElementById('room-code-input').value = '';
}

function joinRoom() {
    const roomCode = document.getElementById('room-code-input').value.trim().toUpperCase();
    if (roomCode.length !== 6) {
        showMessage('Room code must be 6 characters');
        return;
    }
    
    const playerName = window.user?.name || 'Player 2';
    socket.emit('join_room', {
        game_type: 'digit_guess',
        room_code: roomCode,
        player_name: playerName
    });
}

function showWaitingRoom() {
    showSection(sections.waitingRoom);
    document.getElementById('display-room-code').textContent = gameState.roomCode;
    
    // Show/hide start button based on host status
    const startBtn = document.getElementById('start-game-btn');
    startBtn.style.display = gameState.isHost ? 'inline-block' : 'none';
}

function updatePlayersList() {
    const container = document.getElementById('players-list-container');
    container.innerHTML = '';
    
    gameState.players.forEach(player => {
        const playerDiv = document.createElement('div');
        playerDiv.className = 'player-item';
        
        const nameSpan = document.createElement('span');
        nameSpan.textContent = player.name;
        if (player.is_host) {
            nameSpan.textContent += ' 👑';
        }
        
        const statusSpan = document.createElement('span');
        statusSpan.className = `player-status ${player.ready ? 'ready' : 'not-ready'}`;
        
        playerDiv.appendChild(nameSpan);
        playerDiv.appendChild(statusSpan);
        container.appendChild(playerDiv);
    });
}

function copyRoomCode() {
    const code = gameState.roomCode;
    navigator.clipboard.writeText(code).then(() => {
        showMessage('Room code copied!');
    }).catch(() => {
        showMessage('Failed to copy code');
    });
}

function startGame() {
    if (gameState.players.length !== 2) {
        showMessage('Need exactly 2 players to start!');
        return;
    }
    
    socket.emit('start_game', {
        room_code: gameState.roomCode
    });
}

function leaveRoom() {
    socket.emit('leave_room', {
        room_code: gameState.roomCode
    });
    resetGame();
    showSection(sections.modeSelection);
}

function showSetNumberSection() {
    showSection(sections.setNumber);
    document.getElementById('secret-number-input').value = '';
    document.getElementById('secret-number-input').disabled = false;
    document.getElementById('submit-secret-btn').disabled = false;
    document.getElementById('waiting-opponent-msg').style.display = 'none';
    document.getElementById('secret-number-input').focus();
}

function submitSecretNumber() {
    const input = document.getElementById('secret-number-input');
    const number = input.value.trim();
    
    if (number.length !== 4 || !/^\d{4}$/.test(number)) {
        showMessage('Please enter exactly 4 digits');
        return;
    }
    
    gameState.mySecretNumber = number;
    
    socket.emit('set_secret_number', {
        room_code: gameState.roomCode,
        secret_number: number
    });
}

function showGameScreen() {
    showSection(sections.gameScreen);
    updateGuessHistory();
    updateTurnIndicator();
    document.getElementById('guess-input').value = '';
}

function updateTurnIndicator() {
    const indicator = document.getElementById('turn-indicator');
    const isMyTurn = gameState.currentTurn === gameState.myPlayerId;
    
    if (isMyTurn) {
        indicator.textContent = '🎯 Your Turn - Make a Guess!';
        indicator.style.borderColor = '#00ff88';
        document.getElementById('guess-input').disabled = false;
        document.getElementById('submit-guess-btn').disabled = false;
    } else {
        const opponentName = gameState.players.find(p => p.id === gameState.currentTurn)?.name || 'Opponent';
        indicator.textContent = `⏳ ${opponentName}'s Turn`;
        indicator.style.borderColor = '#ff6b6b';
        document.getElementById('guess-input').disabled = true;
        document.getElementById('submit-guess-btn').disabled = true;
    }
}

function updateGuessHistory() {
    const container = document.getElementById('guess-history-container');
    container.innerHTML = '';
    
    // Combine and sort all guesses by timestamp (we'll use index as proxy)
    const allGuesses = [];
    
    for (const playerId in gameState.guessHistory) {
        const player = gameState.players.find(p => p.id === playerId);
        const playerName = player?.name || 'Player';
        const isMine = playerId === gameState.myPlayerId;
        
        gameState.guessHistory[playerId].forEach((guessData, index) => {
            allGuesses.push({
                playerName,
                isMine,
                guess: guessData.guess,
                feedback: guessData.feedback,
                index
            });
        });
    }
    
    if (allGuesses.length === 0) {
        container.innerHTML = '<p style="color: #aaa; text-align: center;">No guesses yet</p>';
        return;
    }
    
    // Display most recent first
    allGuesses.reverse();
    
    allGuesses.forEach(item => {
        const guessDiv = document.createElement('div');
        guessDiv.className = `guess-item ${item.isMine ? 'my-guess' : 'opponent-guess'}`;
        
        guessDiv.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <span style="font-weight: 600;">${item.playerName}</span>
                <span class="guess-number">${item.guess}</span>
            </div>
            <div class="guess-feedback">
                <span class="feedback-stat">🎯 ${item.feedback.correct_positions} in position</span>
                <span class="feedback-stat">✓ ${item.feedback.correct_digits} total correct</span>
            </div>
        `;
        
        container.appendChild(guessDiv);
    });
}

function submitGuess() {
    const input = document.getElementById('guess-input');
    const guess = input.value.trim();
    
    if (guess.length !== 4 || !/^\d{4}$/.test(guess)) {
        showMessage('Please enter exactly 4 digits');
        return;
    }
    
    if (gameState.currentTurn !== gameState.myPlayerId) {
        showMessage('Not your turn!');
        return;
    }
    
    socket.emit('make_guess', {
        room_code: gameState.roomCode,
        guess: guess
    });
}

function leaveGame() {
    if (confirm('Are you sure you want to leave the game?')) {
        socket.emit('leave_room', {
            room_code: gameState.roomCode
        });
        resetGame();
        showSection(sections.modeSelection);
    }
}

function showGameOver(data) {
    showSection(sections.gameOver);
    
    const isWinner = data.winner_id === gameState.myPlayerId;
    
    document.getElementById('game-over-title').textContent = isWinner ? 'You Win! 🎉' : 'Game Over';
    document.getElementById('winner-announcement').textContent = 
        isWinner ? 'Congratulations! You cracked the code!' : `${data.winner_name} wins!`;
    
    // Show secret numbers
    const secretsContainer = document.getElementById('secrets-container');
    secretsContainer.innerHTML = '';
    
    gameState.players.forEach(player => {
        const secretDiv = document.createElement('div');
        secretDiv.style.margin = '15px 0';
        
        const isMine = player.id === gameState.myPlayerId;
        secretDiv.innerHTML = `
            <div style="color: ${isMine ? '#00ff88' : '#ff6b6b'}; font-weight: 600;">
                ${player.name}${isMine ? ' (You)' : ''}:
            </div>
            <div class="secret-number-display">${data.secret_numbers[player.id]}</div>
        `;
        
        secretsContainer.appendChild(secretDiv);
    });
}

function playAgain() {
    socket.emit('leave_room', {
        room_code: gameState.roomCode
    });
    resetGame();
    showSection(sections.modeSelection);
}

function exitToMenu() {
    if (!gameState.gameOver) {
        socket.emit('leave_room', {
            room_code: gameState.roomCode
        });
    }
    resetGame();
    showSection(sections.modeSelection);
}

function resetGame() {
    gameState = {
        roomCode: null,
        players: [],
        isHost: false,
        myPlayerId: socket.id,
        currentTurn: null,
        mySecretNumber: null,
        gameStarted: false,
        gameOver: false,
        guessHistory: {}
    };
}

console.log('Digit Guess script loaded successfully');
