console.log('=== CANVAS_BATTLE.JS LOADED ===');

// Check Socket.IO
if (typeof io === 'undefined') {
    console.error('❌ Socket.IO not loaded!');
} else {
    console.log('✅ Socket.IO loaded');
}

// Initialize Socket.IO
const socket = io();

// Game state
const gameState = {
    roomCode: null,
    playerId: null,
    playerName: null,
    isHost: false,
    currentTool: 'pen',
    currentColor: '#000000',
    brushSize: 3,
    isDrawing: false,
    selectedSubmission: null,
    timerInterval: null,
    timeLeft: 0
};

// DOM Elements - these might not exist yet
let canvas, ctx;

// Initialize canvas when drawing screen is shown
function initializeCanvas() {
    if (!canvas) {
        canvas = document.getElementById('drawing-canvas');
        ctx = canvas ? canvas.getContext('2d') : null;
        
        if (canvas) {
            console.log('✅ Canvas initialized');
            setupCanvasEvents();
            resizeCanvas();
        }
    }
}

function setupCanvasEvents() {
    if (!canvas) return;

    canvas.addEventListener('mousedown', startDrawing);
    canvas.addEventListener('mousemove', draw);
    canvas.addEventListener('mouseup', stopDrawing);
    canvas.addEventListener('mouseout', stopDrawing);

    // Touch support
    canvas.addEventListener('touchstart', (e) => {
        e.preventDefault();
        const touch = e.touches[0];
        const rect = canvas.getBoundingClientRect();
        const mouseEvent = new MouseEvent('mousedown', {
            clientX: touch.clientX,
            clientY: touch.clientY
        });
        canvas.dispatchEvent(mouseEvent);
    });

    canvas.addEventListener('touchmove', (e) => {
        e.preventDefault();
        const touch = e.touches[0];
        const mouseEvent = new MouseEvent('mousemove', {
            clientX: touch.clientX,
            clientY: touch.clientY
        });
        canvas.dispatchEvent(mouseEvent);
    });

    canvas.addEventListener('touchend', (e) => {
        e.preventDefault();
        const mouseEvent = new MouseEvent('mouseup', {});
        canvas.dispatchEvent(mouseEvent);
    });
}

function resizeCanvas() {
    if (!canvas) return;
    
    const container = canvas.parentElement;
    if (!container) return;
    
    const maxWidth = Math.min(800, container.clientWidth - 20);
    
    // Just set display size, keep internal resolution
    canvas.style.width = maxWidth + 'px';
    canvas.style.height = (maxWidth * 0.75) + 'px'; // 4:3 ratio
}

// DOM Elements - Mode Selection
const modeSelection = document.getElementById('mode-selection');
const joinRoomSection = document.getElementById('join-room-section');
const waitingRoom = document.getElementById('waiting-room');
const drawingScreen = document.getElementById('drawing-screen');
const votingScreen = document.getElementById('voting-screen');
const resultsScreen = document.getElementById('results-screen');
const finalResultsScreen = document.getElementById('final-results-screen');

// Initialize
console.log('=== INITIALIZING CANVAS BATTLE ===');

// Event Listeners - Mode Selection
const createRoomBtn = document.getElementById('create-room-btn');
const joinRoomBtnStart = document.getElementById('join-room-btn-start');
const backToModeBtn = document.getElementById('back-to-mode-btn');
const joinRoomSubmitBtn = document.getElementById('join-room-submit-btn');
const roomCodeInput = document.getElementById('room-code-input');

if (createRoomBtn) {
    createRoomBtn.addEventListener('click', createRoom);
    console.log('✅ Create room button attached');
}

if (joinRoomBtnStart) {
    joinRoomBtnStart.addEventListener('click', () => {
        modeSelection.classList.add('hidden');
        joinRoomSection.classList.remove('hidden');
    });
}

if (backToModeBtn) {
    backToModeBtn.addEventListener('click', () => {
        joinRoomSection.classList.add('hidden');
        modeSelection.classList.remove('hidden');
    });
}

if (joinRoomSubmitBtn) {
    joinRoomSubmitBtn.addEventListener('click', joinRoom);
}

if (roomCodeInput) {
    roomCodeInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') joinRoom();
    });
}

// Waiting Room
const copyCodeBtn = document.getElementById('copy-code-btn');
const readyBtn = document.getElementById('ready-btn');
const startGameBtn = document.getElementById('start-game-btn');
const leaveRoomBtn = document.getElementById('leave-room-btn');

if (copyCodeBtn) copyCodeBtn.addEventListener('click', copyRoomCode);
if (readyBtn) readyBtn.addEventListener('click', markReady);
if (startGameBtn) startGameBtn.addEventListener('click', startGame);
if (leaveRoomBtn) leaveRoomBtn.addEventListener('click', leaveRoom);

// Drawing - Initialize when needed
const colorPicker = document.getElementById('color-picker');
const brushSize = document.getElementById('brush-size');
const clearCanvasBtn = document.getElementById('clear-canvas-btn');
const submitDrawingBtn = document.getElementById('submit-drawing-btn');

if (colorPicker) {
    colorPicker.addEventListener('change', (e) => {
        gameState.currentColor = e.target.value;
    });
}

if (brushSize) {
    brushSize.addEventListener('input', (e) => {
        gameState.brushSize = parseInt(e.target.value);
    });
}

if (clearCanvasBtn) clearCanvasBtn.addEventListener('click', clearCanvas);
if (submitDrawingBtn) submitDrawingBtn.addEventListener('click', submitDrawing);

// Tool buttons
document.querySelectorAll('.tool-btn[data-tool]').forEach(btn => {
    btn.addEventListener('click', () => selectTool(btn.dataset.tool));
});

// Voting
const submitVoteBtn = document.getElementById('submit-vote-btn');
if (submitVoteBtn) submitVoteBtn.addEventListener('click', submitVote);

// Results
const nextRoundBtn = document.getElementById('next-round-btn');
const viewFinalResultsBtn = document.getElementById('view-final-results-btn');
const newGameBtn = document.getElementById('new-game-btn');

if (nextRoundBtn) nextRoundBtn.addEventListener('click', nextRound);
if (viewFinalResultsBtn) viewFinalResultsBtn.addEventListener('click', viewFinalResults);
if (newGameBtn) newGameBtn.addEventListener('click', () => {
    // Clean up SocketIO state before reload
    if (gameState.roomCode) {
        socket.emit('leave_canvas_room', {
            room_code: gameState.roomCode
        });
    }
    socket.disconnect();
    setTimeout(() => location.reload(), 100);
});

// Window resize handler
window.addEventListener('resize', resizeCanvas);
window.addEventListener('orientationchange', resizeCanvas);

// Functions
function createRoom() {
    console.log('🎮 Create room clicked');
    
    // Check if user is logged in
    if (!window.user) {
        console.error('❌ User not logged in');
        alert('Please log in to create a room');
        return;
    }

    const userName = window.user.name || window.user.first_name || 'Player';
    gameState.playerName = userName;

    console.log('Creating room...', { playerName: userName });

    socket.emit('create_canvas_room', {
        player_name: userName,
        time_limit: 60
    });
}

function joinRoom() {
    const roomCode = roomCodeInput.value.trim().toUpperCase();
    
    if (!window.user) {
        alert('Please log in to join a room');
        return;
    }
    
    const userName = window.user.name || window.user.first_name || 'Player';

    if (roomCode.length !== 6) {
        alert('Please enter a valid 6-character room code');
        return;
    }

    gameState.playerName = userName;
    console.log('Joining room...', { roomCode, playerName: userName });

    socket.emit('join_canvas_room', {
        room_code: roomCode,
        player_name: userName
    });
}

function copyRoomCode() {
    const roomCode = gameState.roomCode;
    navigator.clipboard.writeText(roomCode).then(() => {
        const btn = copyCodeBtn;
        btn.textContent = '✅ Copied!';
        setTimeout(() => {
            btn.textContent = '📋 Copy Code';
        }, 2000);
    });
}

function markReady() {
    socket.emit('canvas_player_ready', {
        room_code: gameState.roomCode
    });

    const btn = readyBtn;
    btn.disabled = true;
    btn.textContent = '✅ Ready!';
}

function startGame() {
    socket.emit('start_canvas_battle', {
        room_code: gameState.roomCode
    });
}

function leaveRoom() {
    socket.emit('leave_canvas_room', {
        room_code: gameState.roomCode
    });
    socket.disconnect();
    setTimeout(() => location.reload(), 100);
}

function updatePlayersList(players) {
    const container = document.getElementById('waiting-players-list');
    if (!container) return;
    
    container.innerHTML = '';

    players.forEach((player, index) => {
        const div = document.createElement('div');
        div.className = 'player-item';
        if (player.is_host) div.classList.add('host');
        if (player.ready) div.classList.add('ready');

        div.innerHTML = `
            <div style="font-size: 1.5em;">${index + 1}</div>
            <div style="flex: 1;">
                <div style="font-weight: bold;">${player.name}</div>
                <div style="font-size: 0.9em; opacity: 0.7;">
                    ${player.is_host ? '👑 Host' : '👤 Player'}
                    ${player.ready ? ' • ✅ Ready' : ''}
                </div>
            </div>
        `;

        container.appendChild(div);
    });

    // Show start button only for host if all ready
    if (gameState.isHost && startGameBtn) {
        const allReady = players.length >= 2 && players.every(p => p.ready);
        startGameBtn.classList.toggle('hidden', !allReady);
    }
}

// Drawing functions
function selectTool(tool) {
    gameState.currentTool = tool;
    document.querySelectorAll('.tool-btn[data-tool]').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tool === tool);
    });
}

function startDrawing(e) {
    if (!ctx) return;
    gameState.isDrawing = true;
    draw(e);
}

function stopDrawing() {
    if (!ctx) return;
    gameState.isDrawing = false;
    ctx.beginPath();
}

function draw(e) {
    if (!gameState.isDrawing || !ctx || !canvas) return;

    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    
    const x = (e.clientX - rect.left) * scaleX;
    const y = (e.clientY - rect.top) * scaleY;

    ctx.lineWidth = gameState.brushSize;
    ctx.lineCap = 'round';

    if (gameState.currentTool === 'pen') {
        ctx.strokeStyle = gameState.currentColor;
        ctx.globalCompositeOperation = 'source-over';
    } else if (gameState.currentTool === 'eraser') {
        ctx.globalCompositeOperation = 'destination-out';
    }

    ctx.lineTo(x, y);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(x, y);
}

function clearCanvas() {
    if (!ctx || !canvas) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
}

function submitDrawing() {
    if (!canvas) {
        console.error('❌ Canvas not found');
        alert('Canvas not initialized. Please refresh and try again.');
        return;
    }
    
    try {
        // Create a temporary canvas to ensure we capture the drawing
        const tempCanvas = document.createElement('canvas');
        tempCanvas.width = canvas.width;
        tempCanvas.height = canvas.height;
        const tempCtx = tempCanvas.getContext('2d');
        
        // Fill with white background
        tempCtx.fillStyle = 'white';
        tempCtx.fillRect(0, 0, tempCanvas.width, tempCanvas.height);
        
        // Draw the original canvas on top
        tempCtx.drawImage(canvas, 0, 0);
        
        // Convert to data URL with good quality
        const canvasData = tempCanvas.toDataURL('image/png', 1.0);
        
        console.log('📤 Submitting drawing, size:', canvasData.length);
        
        socket.emit('submit_canvas', {
            room_code: gameState.roomCode,
            canvas_data: canvasData
        });

        if (submitDrawingBtn) {
            submitDrawingBtn.disabled = true;
            submitDrawingBtn.textContent = '✅ Submitted!';
        }
        
        console.log('✅ Drawing submitted successfully');
    } catch (error) {
        console.error('❌ Error submitting drawing:', error);
        alert('Failed to submit drawing. Please try again.');
    }
}

function displaySubmissions(submissions, theme) {
    const container = document.getElementById('submissions-container');
    const themeElement = document.getElementById('voting-theme');
    
    if (!container) {
        console.error('❌ Submissions container not found');
        return;
    }
    
    console.log('📊 Displaying submissions:', submissions);
    
    if (themeElement) themeElement.textContent = theme;
    container.innerHTML = '';

    if (!submissions || submissions.length === 0) {
        container.innerHTML = '<p style="text-align: center; color: #aaa;">No submissions received yet...</p>';
        return;
    }

    submissions.forEach((submission, index) => {
        console.log(`Submission ${index + 1}:`, submission.player_name);
        
        const card = document.createElement('div');
        card.className = 'submission-card';
        card.dataset.playerId = submission.player_id;

        const img = document.createElement('img');
        img.src = submission.canvas_data;
        img.className = 'submission-canvas';
        img.alt = `${submission.player_name}'s drawing`;
        
        // Add error handler for image loading
        img.onerror = () => {
            console.error('❌ Failed to load image for:', submission.player_name);
            img.src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="300" height="200"><rect width="300" height="200" fill="%23333"/><text x="150" y="100" text-anchor="middle" fill="white">Image Load Error</text></svg>';
        };
        
        img.onload = () => {
            console.log('✅ Image loaded for:', submission.player_name);
        };

        const author = document.createElement('div');
        author.className = 'submission-author';
        author.textContent = submission.player_name;

        card.appendChild(img);
        card.appendChild(author);

        // Can't vote for yourself
        if (submission.player_id !== gameState.playerId) {
            card.addEventListener('click', () => selectSubmission(card, submission.player_id));
        } else {
            card.style.opacity = '0.5';
            card.style.cursor = 'not-allowed';
            author.textContent += ' (You)';
        }

        container.appendChild(card);
    });
    
    console.log(`✅ Displayed ${submissions.length} submissions`);
}

function selectSubmission(card, playerId) {
    document.querySelectorAll('.submission-card').forEach(c => c.classList.remove('selected'));
    card.classList.add('selected');
    gameState.selectedSubmission = playerId;
    if (submitVoteBtn) submitVoteBtn.disabled = false;
}

function submitVote() {
    if (!gameState.selectedSubmission) return;

    socket.emit('submit_vote', {
        room_code: gameState.roomCode,
        voted_for_id: gameState.selectedSubmission
    });

    if (submitVoteBtn) {
        submitVoteBtn.disabled = true;
        submitVoteBtn.textContent = '✅ Vote Submitted!';
    }

    // Auto end voting after 3 seconds
    setTimeout(() => {
        if (gameState.isHost) {
            socket.emit('end_voting', {
                room_code: gameState.roomCode
            });
        }
    }, 3000);
}

function displayResults(results, isRound) {
    const container = isRound ? 
        document.getElementById('results-list') : 
        document.getElementById('final-results-list');
    
    if (!container) return;
    
    container.innerHTML = '';

    results.forEach((result, index) => {
        const div = document.createElement('div');
        div.className = 'result-item';
        
        if (index === 0) div.classList.add('first');
        else if (index === 1) div.classList.add('second');
        else if (index === 2) div.classList.add('third');

        const medal = index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : '🎨';

        div.innerHTML = `
            <div class="result-rank">${medal}</div>
            <div class="result-name">${result.name}</div>
            <div class="result-score">${isRound ? result.votes + ' votes' : result.score + ' pts'}</div>
        `;

        container.appendChild(div);
    });
}

function nextRound() {
    socket.emit('next_round', {
        room_code: gameState.roomCode
    });
}

function viewFinalResults() {
    if (resultsScreen) resultsScreen.classList.add('hidden');
    if (finalResultsScreen) finalResultsScreen.classList.remove('hidden');
}

function startTimer(seconds) {
    gameState.timeLeft = seconds;
    updateTimerDisplay();

    if (gameState.timerInterval) {
        clearInterval(gameState.timerInterval);
    }

    gameState.timerInterval = setInterval(() => {
        gameState.timeLeft--;
        updateTimerDisplay();

        if (gameState.timeLeft <= 0) {
            clearInterval(gameState.timerInterval);
            // Auto submit if not submitted
            if (submitDrawingBtn && !submitDrawingBtn.disabled) {
                submitDrawing();
            }
        }
    }, 1000);
}

function updateTimerDisplay() {
    const display = document.getElementById('timer-display');
    if (!display) return;
    
    const minutes = Math.floor(gameState.timeLeft / 60);
    const seconds = gameState.timeLeft % 60;
    display.textContent = `⏱️ ${minutes}:${seconds.toString().padStart(2, '0')}`;
    
    if (gameState.timeLeft <= 10) {
        display.classList.add('warning');
    } else {
        display.classList.remove('warning');
    }
}

// Socket Events
socket.on('canvas_room_created', (data) => {
    console.log('✅ Room created:', data);
    gameState.roomCode = data.room_code;
    gameState.playerId = data.player_id;
    gameState.isHost = true;

    const displayRoomCode = document.getElementById('display-room-code');
    if (displayRoomCode) displayRoomCode.textContent = data.room_code;
    
    updatePlayersList(data.players);

    if (modeSelection) modeSelection.classList.add('hidden');
    if (waitingRoom) waitingRoom.classList.remove('hidden');
});

socket.on('canvas_room_joined', (data) => {
    console.log('✅ Room joined:', data);
    gameState.roomCode = data.room_code;
    gameState.playerId = data.player_id;
    gameState.isHost = false;

    const displayRoomCode = document.getElementById('display-room-code');
    if (displayRoomCode) displayRoomCode.textContent = data.room_code;
    
    updatePlayersList(data.players);

    if (joinRoomSection) joinRoomSection.classList.add('hidden');
    if (waitingRoom) waitingRoom.classList.remove('hidden');
});

socket.on('canvas_player_joined', (data) => {
    console.log('Player joined:', data);
    updatePlayersList(data.players);
});

socket.on('canvas_player_ready_update', (data) => {
    console.log('Player ready update:', data);
    updatePlayersList(data.players);
});

socket.on('drawing_round_start', (data) => {
    console.log('🎨 Drawing round started:', data);
    
    // Initialize canvas now
    initializeCanvas();
    
    const themeText = document.getElementById('theme-text');
    if (themeText) themeText.textContent = data.theme;
    
    clearCanvas();
    
    if (waitingRoom) waitingRoom.classList.add('hidden');
    if (resultsScreen) resultsScreen.classList.add('hidden');
    if (drawingScreen) drawingScreen.classList.remove('hidden');

    if (submitDrawingBtn) {
        submitDrawingBtn.disabled = false;
        submitDrawingBtn.textContent = '✅ Submit Drawing';
    }

    startTimer(data.time_limit);
});

socket.on('canvas_submission_update', (data) => {
    console.log('Submission update:', data);
});

socket.on('voting_round_start', (data) => {
    console.log('🗳️ Voting round started:', data);
    
    if (gameState.timerInterval) {
        clearInterval(gameState.timerInterval);
    }

    displaySubmissions(data.submissions, data.theme);

    if (drawingScreen) drawingScreen.classList.add('hidden');
    if (votingScreen) votingScreen.classList.remove('hidden');

    if (submitVoteBtn) {
        submitVoteBtn.disabled = true;
        submitVoteBtn.textContent = '🗳️ Submit Vote';
    }
    gameState.selectedSubmission = null;
});

socket.on('round_results', (data) => {
    console.log('📊 Round results:', data);
    
    displayResults(data.results, true);

    if (votingScreen) votingScreen.classList.add('hidden');
    if (resultsScreen) resultsScreen.classList.remove('hidden');

    // Show appropriate button
    if (gameState.isHost && nextRoundBtn) {
        nextRoundBtn.classList.remove('hidden');
    }
    if (viewFinalResultsBtn) {
        viewFinalResultsBtn.classList.add('hidden');
    }
});

socket.on('game_over', (data) => {
    console.log('🎉 Game over:', data);
    
    displayResults(data.final_results, false);

    if (nextRoundBtn) nextRoundBtn.classList.add('hidden');
    if (viewFinalResultsBtn) viewFinalResultsBtn.classList.remove('hidden');
});

socket.on('canvas_player_left', (data) => {
    console.log('Player left:', data);
    updatePlayersList(data.players);
});

socket.on('canvas_error', (data) => {
    console.error('❌ Canvas error:', data);
    alert(data.message);
});

console.log('✅ Canvas Battle initialized');
console.log('User info:', window.user);