# TicTacToe Multiplayer - Haskell + WebSockets

A real-time multiplayer TicTacToe game built with Haskell backend and vanilla JavaScript frontend. This is an educational project to learn web development in Haskell.

## Features

- **Real-time multiplayer gameplay** using WebSockets
- **Online player tracking** - see who's online in real-time
- **Challenge system** - challenge other players to games
- **Live game updates** - moves are synchronized instantly
- **Clean vanilla JS frontend** - no frameworks, just HTML/CSS/JS

## Architecture

### Backend (Haskell)
- **Warp** - Fast HTTP server
- **WebSockets** - Real-time bidirectional communication
- **STM** - Software Transactional Memory for thread-safe state management
- **Aeson** - JSON encoding/decoding
- **Scotty** - Lightweight web framework for serving static files

### Frontend (Vanilla JavaScript)
- Pure HTML5/CSS3/JavaScript
- WebSocket client for real-time communication
- Responsive design

## Project Structure

```
haskel-web1/
├── src/
│   ├── Main.hs        # Entry point, server setup
│   ├── Types.hs       # Data types and JSON instances
│   ├── Game.hs        # TicTacToe game logic
│   └── Server.hs      # WebSocket server and message handling
├── public/
│   ├── index.html     # Frontend HTML
│   ├── style.css      # Styling
│   └── app.js         # Frontend JavaScript
├── stack.yaml         # Stack configuration
└── package.yaml       # Project dependencies
```

## Getting Started

### Prerequisites

You need to install the Haskell toolchain. The easiest way is to use [Stack](https://docs.haskellstack.org/en/stable/README/):

**On Linux/macOS:**
```bash
curl -sSL https://get.haskellstack.org/ | sh
```

**On Windows:**
Download the installer from [https://get.haskellstack.org/stable/windows-x86_64-installer.exe](https://get.haskellstack.org/stable/windows-x86_64-installer.exe)

**Alternative (GHCup):**
You can also use [GHCup](https://www.haskell.org/ghcup/) which provides Stack, GHC, and other tools.

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd haskel-web1
```

2. Build the project:
```bash
stack build
```

3. Run the server:
```bash
stack run
```

The server will start on `http://localhost:8080`

### Playing the Game

1. Open `http://localhost:8080` in your browser
2. Enter your name and click "Join Game"
3. Open another browser window/tab (or use incognito mode) to simulate another player
4. Challenge another player from the online players list
5. The challenged player accepts the challenge
6. Play TicTacToe in real-time!

## How It Works

### WebSocket Communication

The client and server communicate via WebSocket messages:

**Client → Server:**
- `set_name` - Set player name
- `get_online_players` - Request list of online players
- `challenge_player` - Challenge another player
- `accept_challenge` - Accept a challenge
- `reject_challenge` - Reject a challenge
- `make_move` - Make a move in the game

**Server → Client:**
- `welcome` - Send player their unique ID
- `online_players` - List of online players
- `player_joined` - Notify when a player joins
- `player_left` - Notify when a player leaves
- `challenge_received` - Incoming challenge
- `challenge_accepted` - Challenge was accepted
- `game_update` - Game state update
- `game_over` - Game finished
- `error` - Error message

### Game State Management

The server maintains:
- **Online players** - Map of player IDs to player connections
- **Active games** - Map of game IDs to game states
- **Pending challenges** - Map of challenge IDs to challenges

All state is managed using Haskell's STM (Software Transactional Memory) for thread-safe concurrent access.

### Game Logic

The TicTacToe game logic includes:
- Move validation
- Winner detection (rows, columns, diagonals)
- Draw detection
- Turn management

## Learning Resources

This project demonstrates:
- Setting up a Haskell web project with Stack
- Using WebSockets for real-time communication
- STM for concurrent state management
- Type-safe message handling with Aeson
- Serving static files with WAI/Warp
- Building interactive UIs with vanilla JavaScript

## Development

### Building
```bash
stack build
```

### Running in development
```bash
stack run
```

### Clean build
```bash
stack clean
stack build
```

## Future Enhancements

- Add game history/replay
- Implement matchmaking/ranking system
- Add chat functionality
- Support multiple simultaneous games per player
- Add sound effects and animations
- Implement different game modes (timed games, etc.)

## License

MIT License - see LICENSE file

## Contributing

This is an educational project. Feel free to fork and experiment!
