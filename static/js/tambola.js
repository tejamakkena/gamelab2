// Tambola game client-side logic
let socket;
let gameId;
let playerId;
let myTicket;

// Initialize Socket.IO connection
document.addEventListener('DOMContentLoaded', () => {
    socket = io();
    
    document.getElementById('createGame').addEventListener('click', createGame);
    document.getElementById('joinGame').addEventListener('click', joinGame);
    
    // Socket event listeners
    socket.on('player_joined', handlePlayerJoined);
    socket.on('number_called', handleNumberCalled);
    socket.on('win_claimed', handleWinClaimed);
});

function createGame() {
    // TODO: Implement game creation
    fetch('/games/tambola/create', { method: 'POST' })
        .then(res => res.json())
        .then(data => {
            console.log('Game created:', data);
            // Show game area and host controls
        });
}

function joinGame() {
    gameId = document.getElementById('gameIdInput').value;
    // TODO: Implement game joining
    fetch(`/games/tambola/join/${gameId}`, { method: 'POST' })
        .then(res => res.json())
        .then(data => {
            console.log('Joined game:', data);
            socket.emit('tambola_join', { game_id: gameId, player_id: playerId });
        });
}

function renderTicket(ticket) {
    const grid = document.getElementById('ticketGrid');
    grid.innerHTML = '';
    
    ticket.grid.forEach((row, rowIdx) => {
        row.forEach((cell, colIdx) => {
            const cellDiv = document.createElement('div');
            cellDiv.className = 'ticket-cell';
            
            if (cell === null) {
                cellDiv.classList.add('empty');
            } else {
                cellDiv.textContent = cell;
                cellDiv.onclick = () => markNumber(cell);
            }
            
            grid.appendChild(cellDiv);
        });
    });
}

function markNumber(number) {
    // Mark number on ticket (visual only for now)
    const cells = document.querySelectorAll('.ticket-cell');
    cells.forEach(cell => {
        if (cell.textContent == number) {
            cell.classList.toggle('marked');
        }
    });
}

function callNumber() {
    socket.emit('tambola_call_number', { game_id: gameId });
}

function handleNumberCalled(data) {
    document.getElementById('currentNumber').textContent = data.number;
    
    // Add to called list
    const calledList = document.getElementById('calledList');
    const span = document.createElement('span');
    span.textContent = data.number + ' ';
    calledList.appendChild(span);
}

function claimWin(winType) {
    socket.emit('tambola_claim_win', {
        game_id: gameId,
        player_id: playerId,
        win_type: winType
    });
}

function handlePlayerJoined(data) {
    console.log('Player joined:', data.player_id);
}

function handleWinClaimed(data) {
    alert(`${data.player_id} claimed ${data.win_type}! Verified: ${data.verified}`);
}
