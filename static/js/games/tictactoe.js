let currentRoomCode = null;
    let playerId = null;
    let playerSymbol = null;
    let roomsPollingInterval = null;
    
    document.getElementById('create-game-btn').addEventListener('click', createGame);
    document.getElementById('join-game-btn').addEventListener('click', joinGameManual);
    document.getElementById('back-to-lobby').addEventListener('click', backToLobby);
    document.getElementById('refresh-rooms-btn').addEventListener('click', loadRooms);
    document.getElementById('play-again-btn').addEventListener('click', playAgain);
    document.getElementById('exit-to-lobby-btn').addEventListener('click', backToLobby);
    
    // Restore session if page reloaded
    if (sessionStorage.getItem('playerSymbol')) {
        playerSymbol = sessionStorage.getItem('playerSymbol');
        currentRoomCode = sessionStorage.getItem('currentRoomCode');
        playerId = sessionStorage.getItem('playerId');
    }
    
    // Load rooms on page load
    loadRooms();
    startRoomsPolling();
    
    async function loadRooms() {
        const response = await fetch('/tictactoe/rooms');
        const data = await response.json();
        
        const roomsList = document.getElementById('rooms-list');
        
        if (data.success && data.rooms.length > 0) {
            roomsList.innerHTML = data.rooms.map(room => {
                const statusClass = room.is_full ? 'full' : (room.status === 'PLAYING' ? 'playing' : 'waiting');
                const statusText = room.is_full ? 'Full' : (room.status === 'PLAYING' ? 'Playing' : 'Waiting for players');
                
                return `
                    <div class="room-item">
                        <div class="room-info">
                            <div class="room-code">${room.room_code}</div>
                            <div class="room-status ${statusClass}">
                                👥 ${room.player_count}/${room.max_players} • ${statusText}
                            </div>
                        </div>
                        <button class="join-room-btn btn" 
                                onclick="joinGameByCode('${room.room_code}')" 
                                ${room.is_full ? 'disabled' : ''}>
                            ${room.is_full ? '🔒 Full' : '▶️ Join'}
                        </button>
                    </div>
                `;
            }).join('');
        } else {
            roomsList.innerHTML = '<div class="empty-rooms">No active rooms. Create one to start playing!</div>';
        }
    }
    
    function startRoomsPolling() {
        roomsPollingInterval = setInterval(loadRooms, 3000);
    }
    
    function stopRoomsPolling() {
        if (roomsPollingInterval) {
            clearInterval(roomsPollingInterval);
            roomsPollingInterval = null;
        }
    }
    
    async function createGame() {
        const response = await fetch('/tictactoe/create', {
            method: 'POST'
        });
        const data = await response.json();
        
        console.log('=== CREATE RESPONSE ===', data);
        
        if (data.success) {
            currentRoomCode = data.room_code;
            playerId = data.player_id;
            playerSymbol = data.symbol;
            
            // Store in sessionStorage
            sessionStorage.setItem('playerSymbol', playerSymbol);
            sessionStorage.setItem('currentRoomCode', currentRoomCode);
            sessionStorage.setItem('playerId', playerId);
            
            console.log('=== CREATE GAME ===');
            console.log('Player ID:', playerId);
            console.log('Symbol:', playerSymbol);
            console.log('Symbol type:', typeof playerSymbol);
            console.log('Symbol charCode:', playerSymbol ? [...playerSymbol].map(c => c.charCodeAt(0)) : 'null');
            
            showGame();
            document.getElementById('room-code-display').textContent = `Room Code: ${currentRoomCode}`;
            document.getElementById('room-code-display').classList.remove('hidden');
            document.getElementById('game-status').textContent = 'Waiting for opponent...';
            
            startPolling();
            stopRoomsPolling();
        }
    }
    
    async function joinGameManual() {
        const roomCode = document.getElementById('room-code-input').value.toUpperCase();
        if (!roomCode) {
            alert('Please enter a room code');
            return;
        }
        await joinGameByCode(roomCode);
    }
    
    async function joinGameByCode(roomCode) {
        const response = await fetch(`/tictactoe/join/${roomCode}`, {
            method: 'POST'
        });
        const data = await response.json();
        
        console.log('=== JOIN RESPONSE ===', data);
        
        if (data.success) {
            currentRoomCode = roomCode;
            playerId = data.player_id;
            playerSymbol = data.symbol;
            
            // Store in sessionStorage
            sessionStorage.setItem('playerSymbol', playerSymbol);
            sessionStorage.setItem('currentRoomCode', currentRoomCode);
            sessionStorage.setItem('playerId', playerId);
            
            console.log('=== JOIN GAME ===');
            console.log('Player ID:', playerId);
            console.log('Symbol:', playerSymbol);
            console.log('Symbol type:', typeof playerSymbol);
            console.log('Symbol charCode:', playerSymbol ? [...playerSymbol].map(c => c.charCodeAt(0)) : 'null');
            
            showGame();
            document.getElementById('room-code-display').textContent = `Room Code: ${currentRoomCode}`;
            document.getElementById('room-code-display').classList.remove('hidden');
            updateGameState(data.game_state);
            startPolling();
            stopRoomsPolling();
        } else {
            alert(data.error);
        }
    }
    
    function showGame() {
        document.getElementById('lobby').classList.add('hidden');
        document.getElementById('game-area').classList.remove('hidden');
        
        document.querySelectorAll('.cell').forEach(cell => {
            cell.addEventListener('click', makeMove);
        });
    }
    
    async function makeMove(e) {
        const position = parseInt(e.target.dataset.index);
        
        const response = await fetch(`/tictactoe/move/${currentRoomCode}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ position })
        });
        
        const data = await response.json();
        
        if (data.success) {
            updateGameState(data.game_state);
        } else {
            alert(data.error);
        }
    }
    
    async function pollGameState() {
        if (!currentRoomCode) return;
        
        const response = await fetch(`/tictactoe/state/${currentRoomCode}`);
        const data = await response.json();
        
        if (data.success) {
            updateGameState(data.game_state);
        }
    }
    
    function updateGameState(gameState) {
        gameState.board.forEach((symbol, index) => {
            const cell = document.querySelector(`[data-index="${index}"]`);
            cell.textContent = symbol;
            if (symbol) {
                cell.classList.add('taken');
                if (symbol === '⭕') {
                    cell.classList.add('circle-symbol');
                } else if (symbol === '❌') {
                    cell.classList.add('x-symbol');
                }
            }
        });
        
        if (gameState.winner) {
            const winnerEmoji = gameState.winner === '⭕' ? '🔵' : '❌';
            document.getElementById('game-status').textContent = `${winnerEmoji} ${gameState.winner} wins! 🎉`;
            stopPolling();
            
            // Get symbol from storage if lost
            if (!playerSymbol) {
                playerSymbol = sessionStorage.getItem('playerSymbol');
            }
            
            console.log('=== GAME OVER ===');
            console.log('Winner:', gameState.winner);
            console.log('Winner type:', typeof gameState.winner);
            console.log('Winner charCodes:', gameState.winner ? [...gameState.winner].map(c => c.charCodeAt(0)) : 'null');
            console.log('My Symbol:', playerSymbol);
            console.log('My Symbol type:', typeof playerSymbol);
            console.log('My Symbol charCodes:', playerSymbol ? [...playerSymbol].map(c => c.charCodeAt(0)) : 'null');
            console.log('Are they equal?', gameState.winner === playerSymbol);
            console.log('Winner length:', gameState.winner ? gameState.winner.length : 'null');
            console.log('Symbol length:', playerSymbol ? playerSymbol.length : 'null');
            
            showGameEndModal(gameState.winner, false);
        } else if (gameState.is_draw) {
            document.getElementById('game-status').textContent = "It's a draw! 🤝";
            stopPolling();
            showGameEndModal(null, true);
        } else if (gameState.state === 'PLAYING') {
            const isMyTurn = gameState.players[playerId] === gameState.current_turn;
            const turnEmoji = gameState.current_turn === '⭕' ? '🔵' : '❌';
            document.getElementById('game-status').textContent = 
                isMyTurn ? `Your turn ${turnEmoji} ⏰` : `Opponent's turn ${turnEmoji} ⏳`;
        }
    }
    
    function showGameEndModal(winner, isDraw) {
        // Ensure we have the symbol
        if (!playerSymbol) {
            playerSymbol = sessionStorage.getItem('playerSymbol');
        }
        
        const modal = document.getElementById('game-end-modal');
        const modalIcon = document.getElementById('modal-icon');
        const modalTitle = document.getElementById('modal-title');
        const modalMessage = document.getElementById('modal-message');
        const playerSymbolEl = document.getElementById('player-symbol');
        const gameResultEl = document.getElementById('game-result');
        
        console.log('=== MODAL ===');
        console.log('Winner:', winner);
        console.log('My Symbol:', playerSymbol);
        console.log('Is Draw:', isDraw);
        console.log('Direct Comparison:', winner === playerSymbol);
        
        playerSymbolEl.textContent = playerSymbol || 'N/A';
        
        if (isDraw) {
            modalIcon.textContent = '🤝';
            modalTitle.textContent = "It's a Draw!";
            modalMessage.textContent = "Well played! Both players showed great skill.";
            gameResultEl.textContent = 'DRAW';
            gameResultEl.className = 'stat-value draw';
        } else if (!playerSymbol) {
            // Fallback if symbol still not found
            modalIcon.textContent = '❓';
            modalTitle.textContent = "Game Over";
            modalMessage.textContent = "The game has ended.";
            gameResultEl.textContent = 'FINISHED';
            gameResultEl.className = 'stat-value';
        } else {
            // Normalize symbols for comparison
            const normalizedWinner = String(winner).trim();
            const normalizedPlayerSymbol = String(playerSymbol).trim();
            
            console.log('Normalized Winner:', normalizedWinner, 'charCodes:', [...normalizedWinner].map(c => c.charCodeAt(0)));
            console.log('Normalized Symbol:', normalizedPlayerSymbol, 'charCodes:', [...normalizedPlayerSymbol].map(c => c.charCodeAt(0)));
            console.log('Normalized Match:', normalizedWinner === normalizedPlayerSymbol);
            
            if (normalizedWinner === normalizedPlayerSymbol) {
                modalIcon.textContent = '🏆';
                modalTitle.textContent = "Victory!";
                modalMessage.textContent = "Congratulations! You won the game!";
                gameResultEl.textContent = 'WIN';
                gameResultEl.className = 'stat-value win';
            } else {
                modalIcon.textContent = '😔';
                modalTitle.textContent = "Defeat";
                modalMessage.textContent = "Better luck next time!";
                gameResultEl.textContent = 'LOSS';
                gameResultEl.className = 'stat-value loss';
            }
        }
        
        modal.classList.remove('hidden');
        modal.classList.add('show');
    }
    
    function hideGameEndModal() {
        const modal = document.getElementById('game-end-modal');
        modal.classList.remove('show');
        modal.classList.add('hidden');
    }
    
    function playAgain() {
        hideGameEndModal();
        backToLobby();
    }
    
    let pollingInterval;
    
    function startPolling() {
        pollingInterval = setInterval(pollGameState, 1000);
    }
    
    function stopPolling() {
        if (pollingInterval) {
            clearInterval(pollingInterval);
        }
    }
    
    function backToLobby() {
        stopPolling();
        hideGameEndModal();
        
        // Clear session storage
        sessionStorage.removeItem('playerSymbol');
        sessionStorage.removeItem('currentRoomCode');
        sessionStorage.removeItem('playerId');
        
        currentRoomCode = null;
        playerId = null;
        playerSymbol = null;
        
        document.querySelectorAll('.cell').forEach(cell => {
            cell.textContent = '';
            cell.classList.remove('taken', 'circle-symbol', 'x-symbol');
        });
        
        document.getElementById('lobby').classList.remove('hidden');
        document.getElementById('game-area').classList.add('hidden');
        document.getElementById('room-code-display').classList.add('hidden');
        
        loadRooms();
        startRoomsPolling();
    }