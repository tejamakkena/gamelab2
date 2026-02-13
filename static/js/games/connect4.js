console.log('Connect4 script loading...');
console.log('User:', window.user);

// Socket connection
const socket = io();

// Cleanup manager for proper resource cleanup
const cleanup = new CleanupManager();

// Game state
let gameState = {
    roomCode: null,
    players: [],
    isHost: false,
    myColor: null,
    currentTurn: null,
    board: Array(6).fill(null).map(() => Array(7).fill(null)),
    gameStarted: false,
    gameOver: false
};

// DOM elements
const sections = {
    modeSelection: document.getElementById('mode-selection'),
    joinRoom: document.getElementById('join-room-section'),
    waitingRoom: document.getElementById('waiting-room'),
    gameScreen: document.getElementById('game-screen')
};

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    console.log('DOM loaded, initializing Connect4...');
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
    
    // Game
    document.getElementById('leave-game-btn').addEventListener('click', leaveGame);
    
    // Game over
    document.getElementById('play-again-btn').addEventListener('click', playAgain);
    document.getElementById('exit-game-btn').addEventListener('click', exitToMenu);
    
    // Socket listeners
    setupSocketListeners();
}

function setupSocketListeners() {
    // Use safe socket handlers with error handling
    safeSocketOn(socket, 'connect', () => {
        console.log('Socket connected:', socket.id);
    });

    safeSocketOn(socket, 'room_created', (data) => {
        console.log('Room created:', data);
        gameState.roomCode = data.room_code;
        gameState.players = data.players || [];
        gameState.isHost = true;
        gameState.myColor = 'red';
        showWaitingRoom();
        updatePlayersList();
    });

    safeSocketOn(socket, 'room_joined', (data) => {
        console.log('Room joined:', data);
        gameState.roomCode = data.room_code;
        gameState.players = data.players;
        gameState.myColor = data.your_color;
        gameState.isHost = data.is_host;
        showWaitingRoom();
        updatePlayersList();
    });

    safeSocketOn(socket, 'player_joined', (data) => {
        console.log('Player joined:', data);
        gameState.players = data.players;
        updatePlayersList();
    });

    safeSocketOn(socket, 'player_left', (data) => {
        console.log('Player left:', data);
        gameState.players = data.players;
        updatePlayersList();
        
        if (gameState.gameStarted && !gameState.gameOver) {
            showMessage('Opponent left the game!', 'warning');
            setTimeout(() => exitToMenu(), 2000);
        }
    });

    safeSocketOn(socket, 'game_started', (data) => {
        console.log('Game started:', data);
        gameState.gameStarted = true;
        gameState.currentTurn = data.current_turn;
        gameState.board = data.board;
        showGameScreen();
        renderBoard();
        updateTurnDisplay();
    });

    safeSocketOn(socket, 'move_made', (data) => {
        console.log('Move made:', data);
        gameState.board = data.board;
        gameState.currentTurn = data.current_turn;
        renderBoard();
        updateTurnDisplay();
    });

    safeSocketOn(socket, 'game_over', (data) => {
        console.log('Game over:', data);
        gameState.gameOver = true;
        
        if (data.winning_cells) {
            highlightWinningCells(data.winning_cells);
        }
        
        setTimeout(() => {
            showGameOver(data.winner, data.reason);
        }, 1000);
    });

    safeSocketOn(socket, 'error', (data) => {
        console.error('Socket error:', data);
        showMessage(data.message || 'An error occurred', 'error');
    });
}

function createRoom() {
    console.log('Creating room...');
    console.log('User data:', window.user);
    
    // Use shared utility for getting user name
    const playerName = getUserName('Player');
    console.log('Player name:', playerName);
    
    const createBtn = document.getElementById('create-room-btn');
    emitWithLoading(socket, 'create_room', {
        game_type: 'connect4',
        player_name: playerName
    }, createBtn);
}

function showJoinRoom() {
    showSection('joinRoom');
    document.getElementById('room-code-input').focus();
}

function joinRoom() {
    const roomCode = document.getElementById('room-code-input').value.trim().toUpperCase();
    
    if (!isValidRoomCode(roomCode)) {
        showMessage('Please enter a valid 6-character room code', 'warning');
        return;
    }
    
    // Use shared utility for getting user name
    const playerName = getUserName('Player');
    console.log('Joining room:', roomCode, 'as', playerName);
    
    const joinBtn = document.getElementById('join-room-submit-btn');
    emitWithLoading(socket, 'join_room', {
        room_code: roomCode,
        player_name: playerName
    }, joinBtn);
}

function backToMode() {
    document.getElementById('room-code-input').value = '';
    showSection('modeSelection');
}

function showWaitingRoom() {
    document.getElementById('display-room-code').textContent = gameState.roomCode;
    updatePlayersList();
    showSection('waitingRoom');
}

function updatePlayersList() {
    const listElement = document.getElementById('waiting-players-list');
    listElement.innerHTML = '';
    
    console.log('Updating players list:', gameState.players);
    
    const colors = ['red', 'yellow'];
    
    for (let i = 0; i < 2; i++) {
        const player = gameState.players[i];
        const color = colors[i];
        
        const playerItem = document.createElement('div');
        playerItem.className = `player-item ${player ? color : 'empty'}`;
        
        const colorIndicator = document.createElement('div');
        colorIndicator.className = `color-indicator ${player ? color : 'empty'}`;
        
        const playerName = document.createElement('span');
        playerName.className = 'player-name';
        playerName.textContent = player ? player.name : 'Waiting...';
        
        playerItem.appendChild(colorIndicator);
        playerItem.appendChild(playerName);
        
        if (player && player.is_host) {
            const hostBadge = document.createElement('span');
            hostBadge.className = 'host-badge';
            hostBadge.textContent = '👑 HOST';
            playerItem.appendChild(hostBadge);
        }
        
        listElement.appendChild(playerItem);
    }
    
    // Update start button visibility
    const startBtn = document.getElementById('start-game-btn');
    if (gameState.isHost && gameState.players.length === 2) {
        startBtn.classList.remove('hidden');
        console.log('Start button shown');
    } else {
        startBtn.classList.add('hidden');
        console.log('Start button hidden - Host:', gameState.isHost, 'Players:', gameState.players.length);
    }
}

function copyRoomCode() {
    const roomCode = gameState.roomCode;
    
    copyToClipboard(roomCode, showCopyFeedback, () => {
        showMessage(`Room code: ${roomCode}`, 'info');
    });
}

function showCopyFeedback() {
    const btn = document.getElementById('copy-code-btn');
    const originalText = btn.textContent;
    btn.textContent = '✓ Copied!';
    btn.style.background = 'linear-gradient(135deg, #00ff00, #00cc00)';
    btn.style.color = 'black';
    
    setTimeout(() => {
        btn.textContent = originalText;
        btn.style.background = '';
        btn.style.color = '';
    }, 2000);
}

function startGame() {
    console.log('Starting game...');
    socket.emit('start_game', { room_code: gameState.roomCode });
}

function showGameScreen() {
    showSection('gameScreen');
    renderBoard();
}

function renderBoard() {
    const boardElement = document.getElementById('game-board');
    boardElement.innerHTML = '';
    
    // Track which pieces are new for animation
    const currentBoardState = JSON.stringify(gameState.board);
    const isNewRender = !boardElement.dataset.lastState || 
                       boardElement.dataset.lastState !== currentBoardState;
    
    for (let row = 0; row < 6; row++) {
        for (let col = 0; col < 7; col++) {
            const cell = document.createElement('div');
            cell.className = 'board-cell';
            cell.dataset.row = row;
            cell.dataset.col = col;
            
            const piece = gameState.board[row][col];
            if (piece) {
                const pieceDiv = document.createElement('div');
                pieceDiv.className = `piece ${piece}`;
                
                // Add drop animation for new pieces
                if (isNewRender) {
                    pieceDiv.style.animation = 'dropPiece 0.5s cubic-bezier(0.34, 1.56, 0.64, 1)';
                }
                
                cell.appendChild(pieceDiv);
            }
            
            // Only allow clicks when it's your turn
            if (!gameState.gameOver && gameState.currentTurn === gameState.myColor) {
                cell.addEventListener('click', () => makeMove(col));
            } else {
                cell.classList.add('disabled');
            }
            
            boardElement.appendChild(cell);
        }
    }
    
    boardElement.dataset.lastState = currentBoardState;
}

function makeMove(col) {
    if (gameState.gameOver) return;
    if (gameState.currentTurn !== gameState.myColor) return;
    
    console.log('Making move in column:', col);
    socket.emit('make_move', {
        room_code: gameState.roomCode,
        column: col
    });
}

function updateTurnDisplay() {
    const turnDisplay = document.getElementById('turn-display');
    
    if (gameState.currentTurn === gameState.myColor) {
        turnDisplay.innerHTML = `
            <span class="turn-indicator ${gameState.myColor}"></span>
            <span>Your Turn!</span>
        `;
    } else {
        const opponentColor = gameState.myColor === 'red' ? 'yellow' : 'red';
        turnDisplay.innerHTML = `
            <span class="turn-indicator ${opponentColor}"></span>
            <span>Opponent's Turn</span>
        `;
    }
}

function highlightWinningCells(cells) {
    cells.forEach(([row, col]) => {
        const cell = document.querySelector(`[data-row="${row}"][data-col="${col}"] .piece`);
        if (cell) {
            cell.classList.add('winning');
        }
    });
}

function showGameOver(winner, reason) {
    const overlay = document.getElementById('game-over-overlay');
    const announcement = document.getElementById('winner-announcement');
    
    if (winner === 'draw') {
        announcement.textContent = "It's a Draw!";
        announcement.className = 'winner-announcement';
    } else if (winner === gameState.myColor) {
        announcement.textContent = 'You Win! 🎉';
        announcement.className = `winner-announcement ${winner}`;
    } else {
        announcement.textContent = 'You Lose';
        announcement.className = `winner-announcement ${winner}`;
    }
    
    overlay.classList.remove('hidden');
}

function playAgain() {
    document.getElementById('game-over-overlay').classList.add('hidden');
    gameState.gameOver = false;
    gameState.gameStarted = false;
    gameState.board = Array(6).fill(null).map(() => Array(7).fill(null));
    
    // Go back to waiting room
    showWaitingRoom();
}

function exitToMenu() {
    leaveRoom();
    document.getElementById('game-over-overlay').classList.add('hidden');
}

function leaveRoom() {
    if (gameState.roomCode) {
        socket.emit('leave_room', { room_code: gameState.roomCode });
    }
    
    resetGameState();
    showSection('modeSelection');
}

function leaveGame() {
    if (confirm('Are you sure you want to leave the game?')) {
        leaveRoom();
    }
}

function resetGameState() {
    gameState = {
        roomCode: null,
        players: [],
        isHost: false,
        myColor: null,
        currentTurn: null,
        board: Array(6).fill(null).map(() => Array(7).fill(null)),
        gameStarted: false,
        gameOver: false
    };
}

function showSection(sectionName) {
    console.log('Showing section:', sectionName);
    Object.values(sections).forEach(section => {
        if (section) section.classList.add('hidden');
    });
    
    if (sections[sectionName]) {
        sections[sectionName].classList.remove('hidden');
    }
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    console.log('Cleaning up Connect4 resources...');
    cleanup.cleanup();
    if (gameState.roomCode && socket.connected) {
        socket.emit('leave_room', { room_code: gameState.roomCode });
    }
    socket.disconnect();
});

// Handle visibility change (tab switching) - disconnect inactive games
document.addEventListener('visibilitychange', () => {
    if (document.hidden && gameState.roomCode) {
        console.log('Page hidden, considering disconnect...');
        // Could implement idle timeout here
    } else if (!document.hidden) {
        console.log('Page visible again');
        // Reconnect logic if needed
    }
});

console.log('Connect4 script loaded successfully');