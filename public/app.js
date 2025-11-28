// Application state
const state = {
    ws: null,
    playerId: null,
    playerName: null,
    currentGameId: null,
    mySymbol: null,
    onlinePlayers: [],
    pendingChallenges: [],
    currentGame: null
};

// DOM elements
const elements = {
    loginSection: document.getElementById('login-section'),
    lobbySection: document.getElementById('lobby-section'),
    gameSection: document.getElementById('game-section'),
    playerNameInput: document.getElementById('player-name'),
    joinBtn: document.getElementById('join-btn'),
    connectionStatus: document.getElementById('connection-status'),
    myPlayerId: document.getElementById('my-player-id'),
    myPlayerName: document.getElementById('my-player-name'),
    playersList: document.getElementById('players-list'),
    challengesList: document.getElementById('challenges-list'),
    gameBoard: document.getElementById('game-board'),
    yourSymbol: document.getElementById('your-symbol'),
    currentTurn: document.getElementById('current-turn'),
    gameStatus: document.getElementById('game-status'),
    backToLobbyBtn: document.getElementById('back-to-lobby-btn')
};

// Initialize WebSocket connection
function connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`;

    elements.connectionStatus.textContent = 'Connecting...';
    elements.connectionStatus.className = 'status';

    state.ws = new WebSocket(wsUrl);

    state.ws.onopen = () => {
        console.log('WebSocket connected');
        elements.connectionStatus.textContent = 'Connected';
        elements.connectionStatus.className = 'status connected';
    };

    state.ws.onclose = () => {
        console.log('WebSocket disconnected');
        elements.connectionStatus.textContent = 'Disconnected - Refresh to reconnect';
        elements.connectionStatus.className = 'status disconnected';
    };

    state.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        elements.connectionStatus.textContent = 'Connection error';
        elements.connectionStatus.className = 'status disconnected';
    };

    state.ws.onmessage = (event) => {
        const message = JSON.parse(event.data);
        handleServerMessage(message);
    };
}

// Send message to server
function sendMessage(message) {
    if (state.ws && state.ws.readyState === WebSocket.OPEN) {
        state.ws.send(JSON.stringify(message));
    }
}

// Handle messages from server
function handleServerMessage(message) {
    console.log('Received:', message);

    switch (message.type) {
        case 'welcome':
            state.playerId = message.playerId;
            elements.myPlayerId.textContent = message.playerId;
            break;

        case 'online_players':
            state.onlinePlayers = message.players;
            renderPlayersList();
            break;

        case 'player_joined':
            if (!state.onlinePlayers.find(p => p.id === message.playerId)) {
                state.onlinePlayers.push({ id: message.playerId, name: message.name });
                renderPlayersList();
            }
            break;

        case 'player_left':
            state.onlinePlayers = state.onlinePlayers.filter(p => p.id !== message.playerId);
            renderPlayersList();
            break;

        case 'challenge_received':
            state.pendingChallenges.push({
                id: message.challengeId,
                from: message.challengerName
            });
            renderChallenges();
            break;

        case 'challenge_accepted':
            state.currentGameId = message.gameId;
            state.pendingChallenges = [];
            renderChallenges();
            break;

        case 'challenge_rejected':
            alert('Challenge was rejected');
            break;

        case 'game_update':
            state.currentGame = message;
            state.mySymbol = message.playerX === state.playerId ? 'X' : 'O';
            showGameSection();
            renderGame();
            break;

        case 'game_over':
            if (message.winner) {
                const winner = message.winner;
                const didIWin = winner === state.mySymbol;
                elements.gameStatus.textContent = didIWin ? 'You Win! 🎉' : 'You Lose 😢';
            } else {
                elements.gameStatus.textContent = 'Draw! 🤝';
            }
            disableBoard();
            break;

        case 'error':
            alert('Error: ' + message.message);
            break;
    }
}

// Event listeners
elements.joinBtn.addEventListener('click', () => {
    const name = elements.playerNameInput.value.trim();
    if (name) {
        state.playerName = name;
        elements.myPlayerName.textContent = name;
        sendMessage({ type: 'set_name', name: name });
        showLobbySection();
        requestPlayersList();
    }
});

elements.playerNameInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        elements.joinBtn.click();
    }
});

elements.backToLobbyBtn.addEventListener('click', () => {
    state.currentGameId = null;
    state.currentGame = null;
    state.mySymbol = null;
    showLobbySection();
    requestPlayersList();
});

// Setup board click handlers
document.querySelectorAll('.cell').forEach(cell => {
    cell.addEventListener('click', () => {
        const row = parseInt(cell.dataset.row);
        const col = parseInt(cell.dataset.col);
        makeMove(row, col);
    });
});

// Game functions
function makeMove(row, col) {
    if (!state.currentGame) return;
    if (state.currentGame.status !== 'in_progress') return;

    const isMyTurn = state.currentGame.currentTurn === state.mySymbol;
    if (!isMyTurn) {
        alert('Not your turn!');
        return;
    }

    const cell = state.currentGame.board[row][col];
    if (cell !== 'empty') {
        alert('Cell already occupied!');
        return;
    }

    sendMessage({ type: 'make_move', row: row, col: col });
}

function renderGame() {
    if (!state.currentGame) return;

    elements.yourSymbol.textContent = state.mySymbol;
    elements.currentTurn.textContent = state.currentGame.currentTurn;

    const isMyTurn = state.currentGame.currentTurn === state.mySymbol;
    elements.currentTurn.style.color = isMyTurn ? '#28a745' : '#dc3545';

    // Render board
    const cells = document.querySelectorAll('.cell');
    cells.forEach(cell => {
        const row = parseInt(cell.dataset.row);
        const col = parseInt(cell.dataset.col);
        const value = state.currentGame.board[row][col];

        cell.textContent = value === 'empty' ? '' : value;
        cell.className = 'cell';

        if (value !== 'empty') {
            cell.classList.add('occupied');
            cell.classList.add(value.toLowerCase());
        }
    });

    // Update game status
    if (state.currentGame.status === 'in_progress') {
        elements.gameStatus.textContent = isMyTurn ? 'Your turn!' : 'Opponent\'s turn';
    }
}

function disableBoard() {
    document.querySelectorAll('.cell').forEach(cell => {
        cell.classList.add('occupied');
    });
}

// UI functions
function showLobbySection() {
    elements.loginSection.classList.add('hidden');
    elements.gameSection.classList.add('hidden');
    elements.lobbySection.classList.remove('hidden');
}

function showGameSection() {
    elements.loginSection.classList.add('hidden');
    elements.lobbySection.classList.add('hidden');
    elements.gameSection.classList.remove('hidden');
}

function renderPlayersList() {
    if (state.onlinePlayers.length === 0) {
        elements.playersList.innerHTML = '<p class="empty-message">No other players online</p>';
        return;
    }

    elements.playersList.innerHTML = state.onlinePlayers.map(player => `
        <div class="player-item">
            <div class="player-info">
                <div class="player-name">${escapeHtml(player.name)}</div>
                <div class="player-id">${player.id}</div>
            </div>
            <button class="challenge-btn" onclick="challengePlayer('${player.id}')">
                Challenge
            </button>
        </div>
    `).join('');
}

function renderChallenges() {
    if (state.pendingChallenges.length === 0) {
        elements.challengesList.innerHTML = '<p class="empty-message">No pending challenges</p>';
        return;
    }

    elements.challengesList.innerHTML = state.pendingChallenges.map(challenge => `
        <div class="challenge-item">
            <p><strong>${escapeHtml(challenge.from)}</strong> challenged you to a game!</p>
            <div class="challenge-actions">
                <button class="accept-btn" onclick="acceptChallenge('${challenge.id}')">
                    Accept
                </button>
                <button class="reject-btn" onclick="rejectChallenge('${challenge.id}')">
                    Reject
                </button>
            </div>
        </div>
    `).join('');
}

// Global functions for onclick handlers
window.challengePlayer = function(playerId) {
    sendMessage({ type: 'challenge_player', playerId: playerId });
    alert('Challenge sent!');
};

window.acceptChallenge = function(challengeId) {
    sendMessage({ type: 'accept_challenge', challengeId: challengeId });
};

window.rejectChallenge = function(challengeId) {
    sendMessage({ type: 'reject_challenge', challengeId: challengeId });
    state.pendingChallenges = state.pendingChallenges.filter(c => c.id !== challengeId);
    renderChallenges();
};

function requestPlayersList() {
    sendMessage({ type: 'get_online_players' });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Refresh players list periodically
setInterval(() => {
    if (state.ws && state.ws.readyState === WebSocket.OPEN && !state.currentGameId) {
        requestPlayersList();
    }
}, 5000);

// Initialize
connectWebSocket();
