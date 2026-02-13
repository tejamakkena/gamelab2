console.log('🎰 Roulette Casino loaded');

// Game state
const gameState = {
    totalMoney: 1000,
    currentChipValue: 10,
    bets: {},
    isSpinning: false,
    wheelRotation: 0
};

// Roulette numbers in exact wheel order (European Roulette)
const rouletteNumbers = [
    { num: 0, color: 'green' },
    { num: 32, color: 'red' }, { num: 15, color: 'black' }, { num: 19, color: 'red' },
    { num: 4, color: 'black' }, { num: 21, color: 'red' }, { num: 2, color: 'black' },
    { num: 25, color: 'red' }, { num: 17, color: 'black' }, { num: 34, color: 'red' },
    { num: 6, color: 'black' }, { num: 27, color: 'red' }, { num: 13, color: 'black' },
    { num: 36, color: 'red' }, { num: 11, color: 'black' }, { num: 30, color: 'red' },
    { num: 8, color: 'black' }, { num: 23, color: 'red' }, { num: 10, color: 'black' },
    { num: 5, color: 'red' }, { num: 24, color: 'black' }, { num: 16, color: 'red' },
    { num: 33, color: 'black' }, { num: 1, color: 'red' }, { num: 20, color: 'black' },
    { num: 14, color: 'red' }, { num: 31, color: 'black' }, { num: 9, color: 'red' },
    { num: 22, color: 'black' }, { num: 18, color: 'red' }, { num: 29, color: 'black' },
    { num: 7, color: 'red' }, { num: 28, color: 'black' }, { num: 12, color: 'red' },
    { num: 35, color: 'black' }, { num: 3, color: 'red' }, { num: 26, color: 'black' }
];

const redNumbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36];

// DOM Elements
const modeSelection = document.getElementById('mode-selection');
const rouletteGame = document.getElementById('roulette-game');
const soloModeBtn = document.getElementById('solo-mode-btn');
const spinBtn = document.getElementById('spin-btn');
const clearBetsBtn = document.getElementById('clear-bets-btn');
const canvas = document.getElementById('roulette-canvas');
const ctx = canvas ? canvas.getContext('2d') : null;
const ball = document.getElementById('ball');

// Initialize
function init() {
    console.log('🎰 Initializing Roulette Casino...');
    
    soloModeBtn?.addEventListener('click', startGame);
    
    // Chip selection
    document.querySelectorAll('.chip-btn').forEach(btn => {
        btn.addEventListener('click', () => selectChip(btn));
    });
    
    // Betting buttons
    document.querySelectorAll('.bet-btn').forEach(btn => {
        btn.addEventListener('click', () => placeBet(btn));
    });
    
    spinBtn?.addEventListener('click', spinWheel);
    clearBetsBtn?.addEventListener('click', clearBets);
    
    if (canvas) {
        drawWheel();
    }
}

function startGame() {
    console.log('🎮 Starting Roulette Casino...');
    modeSelection.classList.add('hidden');
    rouletteGame.classList.remove('hidden');
    updateDisplay();
}

function selectChip(btn) {
    document.querySelectorAll('.chip-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    gameState.currentChipValue = parseInt(btn.dataset.value);
    console.log(`💎 Selected chip: $${gameState.currentChipValue}`);
}

function placeBet(btn) {
    if (gameState.isSpinning) {
        showMessage('⏳ Wait for the spin to complete!', 'warning');
        return;
    }
    
    const betType = btn.dataset.type;
    const chipValue = gameState.currentChipValue;
    
    if (gameState.totalMoney < chipValue) {
        showMessage('💸 Not enough money!', 'error');
        return;
    }
    
    // Add bet
    if (!gameState.bets[betType]) {
        gameState.bets[betType] = 0;
    }
    gameState.bets[betType] += chipValue;
    gameState.totalMoney -= chipValue;
    
    // Update display
    updateDisplay();
    updateBetDisplay(betType);
    
    // Enable spin button
    spinBtn.disabled = false;
    spinBtn.innerHTML = '🎰 SPIN TO WIN!';
    spinBtn.classList.add('btn-spin-ready');
    
    console.log(`💰 Bet placed: ${betType} - $${chipValue}`);
}

function updateBetDisplay(betType) {
    const betAmountEl = document.querySelector(`[data-bet="${betType}"]`);
    if (betAmountEl) {
        betAmountEl.textContent = `$${gameState.bets[betType] || 0}`;
        betAmountEl.parentElement.classList.add('bet-active');
    }
}

function clearBets(refund = true) {
    if (gameState.isSpinning) return;
    
    // Only refund if explicitly clearing (not after a spin)
    if (refund) {
        Object.values(gameState.bets).forEach(amount => {
            gameState.totalMoney += amount;
        });
    }
    
    gameState.bets = {};
    
    // Clear visual indicators
    document.querySelectorAll('.bet-amount').forEach(el => {
        el.textContent = '$0';
        el.parentElement.classList.remove('bet-active');
    });
    
    spinBtn.disabled = true;
    spinBtn.innerHTML = '🎰 Place Bets First';
    spinBtn.classList.remove('btn-spin-ready');
    
    updateDisplay();
    console.log(refund ? '🗑️ All bets cleared and refunded' : '🗑️ Bets cleared for new round');
}

function updateDisplay() {
    document.getElementById('total-money').textContent = `$${gameState.totalMoney}`;
    
    const totalBets = Object.values(gameState.bets).reduce((sum, val) => sum + val, 0);
    document.getElementById('current-bet-display').textContent = `$${gameState.currentChipValue}`;
    document.getElementById('round-total').textContent = `$${totalBets}`;
}

function drawWheel() {
    if (!ctx) return;
    
    const centerX = canvas.width / 2;
    const centerY = canvas.height / 2;
    const radius = 220;
    
    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Draw outer rim
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius + 20, 0, Math.PI * 2);
    ctx.strokeStyle = '#00f5ff';
    ctx.lineWidth = 4;
    ctx.stroke();
    ctx.fillStyle = '#0a0a0a';
    ctx.fill();
    
    // Draw wheel segments
    const segmentAngle = (Math.PI * 2) / rouletteNumbers.length;
    
    rouletteNumbers.forEach((item, index) => {
        const startAngle = index * segmentAngle + gameState.wheelRotation;
        const endAngle = startAngle + segmentAngle;
        
        // Draw segment
        ctx.beginPath();
        ctx.moveTo(centerX, centerY);
        ctx.arc(centerX, centerY, radius, startAngle, endAngle);
        ctx.closePath();
        
        // Fill color
        if (item.color === 'green') {
            ctx.fillStyle = '#00ff00';
        } else if (item.color === 'red') {
            ctx.fillStyle = '#ff0000';
        } else {
            ctx.fillStyle = '#000000';
        }
        ctx.fill();
        
        // Draw border
        ctx.strokeStyle = '#FFD700';
        ctx.lineWidth = 2;
        ctx.stroke();
        
        // Draw number
        ctx.save();
        ctx.translate(centerX, centerY);
        ctx.rotate(startAngle + segmentAngle / 2);
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = 'white';
        ctx.font = 'bold 16px Arial';
        ctx.fillText(item.num, radius * 0.75, 0);
        ctx.restore();
    });
    
    // Draw center circle
    ctx.beginPath();
    ctx.arc(centerX, centerY, 40, 0, Math.PI * 2);
    ctx.fillStyle = '#1a1a1a';
    ctx.fill();
    ctx.strokeStyle = '#00f5ff';
    ctx.lineWidth = 3;
    ctx.stroke();
}

function spinWheel() {
    if (gameState.isSpinning) return;
    
    const totalBets = Object.values(gameState.bets).reduce((sum, val) => sum + val, 0);
    if (totalBets === 0) {
        showMessage('🎯 Place your bets first!', 'warning');
        return;
    }
    
    gameState.isSpinning = true;
    spinBtn.disabled = true;
    spinBtn.innerHTML = '🎰 SPINNING...';
    
    // Select winning number and calculate target rotation
    const winningIndex = Math.floor(Math.random() * rouletteNumbers.length);
    const winningNumber = rouletteNumbers[winningIndex];
    
    // Calculate rotation needed to land on winning segment
    // The ball stops at the top (12 o'clock position), so we need to rotate
    // the wheel so the winning segment is at the top
    const segmentAngle = (Math.PI * 2) / rouletteNumbers.length;
    const extraSpins = 5; // Number of full rotations before stopping
    
    // Calculate target: rotate to position winning segment CENTER at top (270° or -π/2)
    // Account for current rotation and add extra spins
    // Subtract half segment angle to align segment CENTER with ball
    const targetAngle = (Math.PI * 2 * extraSpins) - (winningIndex * segmentAngle) - (segmentAngle / 2) + (Math.PI / 2);
    const startRotation = gameState.wheelRotation % (Math.PI * 2);
    const targetRotation = startRotation + targetAngle;
    
    const duration = 5000;
    const startTime = Date.now();
    
    // Ball starts at top and stays there
    const ballRadius = 200;
    const ballAngle = -Math.PI / 2; // Top position (270°)
    
    function animate() {
        const elapsed = Date.now() - startTime;
        const progress = Math.min(elapsed / duration, 1);
        
        // Easing function (ease-out cubic)
        const easeOut = 1 - Math.pow(1 - progress, 3);
        
        // Update wheel rotation
        const currentRotation = startRotation + (targetAngle * easeOut);
        gameState.wheelRotation = currentRotation;
        
        // Redraw wheel
        drawWheel();
        
        // Update ball position to match wheel rotation
        updateBallPosition(currentRotation);
        
        if (progress < 1) {
            requestAnimationFrame(animate);
        } else {
            // Normalize final rotation
            gameState.wheelRotation = currentRotation % (Math.PI * 2);
            drawWheel();
            finishSpin(winningNumber);
        }
    }
    
    animate();
}

function updateBallPosition(currentRotation) {
    const ball = document.getElementById('ball');
    const ballRadius = 180; // Distance from center
    
    // Ball moves opposite to wheel rotation
    const ballAngle = -currentRotation + Math.PI / 2; // Adjust starting position
    
    const x = Math.cos(ballAngle) * ballRadius;
    const y = Math.sin(ballAngle) * ballRadius;
    
    ball.style.left = `calc(50% + ${x}px)`;
    ball.style.top = `calc(50% + ${y}px)`;
}

function finishSpin(winningNumber) {
    gameState.isSpinning = false;
    
    // Display winning number
    document.getElementById('winning-number').textContent = winningNumber.num;
    document.getElementById('winning-number').style.color = 
        winningNumber.color === 'red' ? '#ff0000' : 
        winningNumber.color === 'green' ? '#00ff00' : '#ffffff';
    
    // Calculate winnings
    let totalWin = 0;
    const results = [];
    
    Object.entries(gameState.bets).forEach(([betType, amount]) => {
        const won = checkBet(betType, winningNumber.num, winningNumber.color);
        if (won) {
            const payout = getBetPayout(betType);
            const winAmount = amount * payout;
            totalWin += winAmount;
            results.push(`${betType}: +$${winAmount}`);
        }
    });
    
    // Add winnings to total money
    gameState.totalMoney += totalWin;
    
    // Show result
    const totalBet = Object.values(gameState.bets).reduce((sum, val) => sum + val, 0);
    const netResult = totalWin - totalBet;
    
    let resultMessage = `🎲 Number: ${winningNumber.num} (${winningNumber.color.toUpperCase()})\n\n`;
    
    if (netResult > 0) {
        resultMessage += `🎉 YOU WON $${netResult}!`;
        if (results.length > 0) {
            resultMessage += `\n\nWinning Bets:\n${results.join('\n')}`;
        }
        showMessage(resultMessage, 'success');
    } else if (netResult < 0) {
        resultMessage += `😔 You lost $${Math.abs(netResult)}`;
        showMessage(resultMessage, 'error');
    } else {
        resultMessage += `💰 Break even!`;
        showMessage(resultMessage, 'info');
    }
    
    // Reset for next round (don't refund - bets were already deducted!)
    clearBets(false);
    updateDisplay();
    
    console.log(`🎲 Result: ${winningNumber.num} (${winningNumber.color}) - Net: $${netResult}`);
}

function checkBet(betType, number, color) {
    switch(betType) {
        case 'red': return color === 'red';
        case 'black': return color === 'black';
        case 'zero': return number === 0;
        case 'even': return number !== 0 && number % 2 === 0;
        case 'odd': return number !== 0 && number % 2 === 1;
        case 'low': return number >= 1 && number <= 18;
        case 'high': return number >= 19 && number <= 36;
        case 'first12': return number >= 1 && number <= 12;
        case 'second12': return number >= 13 && number <= 24;
        case 'third12': return number >= 25 && number <= 36;
        default: return false;
    }
}

function getBetPayout(betType) {
    const payouts = {
        'red': 2, 'black': 2, 'zero': 36,
        'even': 2, 'odd': 2,
        'low': 2, 'high': 2,
        'first12': 3, 'second12': 3, 'third12': 3
    };
    return payouts[betType] || 1;
}

function showMessage(text, type) {
    const messageEl = document.getElementById('result-message');
    messageEl.textContent = text;
    messageEl.className = `result-message result-${type}`;
    messageEl.classList.remove('hidden');
    
    setTimeout(() => {
        messageEl.classList.add('hidden');
    }, 6000);
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', init);