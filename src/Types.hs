{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Types where

import Data.Aeson
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Text (Text)
import Data.UUID (UUID)
import GHC.Generics
import qualified Network.WebSockets as WS

-- | Player representation
data Player = Player
  { playerId :: UUID
  , playerName :: Text
  , playerConnection :: WS.Connection
  }

-- | Cell state in TicTacToe
data Cell = Empty | X | O
  deriving (Eq, Show, Generic)

instance ToJSON Cell where
  toJSON Empty = String "empty"
  toJSON X = String "X"
  toJSON O = String "O"

instance FromJSON Cell

-- | Game board (3x3 grid)
type Board = [[Cell]]

-- | Game state
data GameState = GameState
  { gameId :: UUID
  , gameBoard :: Board
  , currentTurn :: Cell  -- X or O
  , playerX :: UUID
  , playerO :: UUID
  , gameStatus :: GameStatus
  }
  deriving (Generic)

data GameStatus = Waiting | InProgress | Finished (Maybe Cell)
  deriving (Eq, Show, Generic)

instance ToJSON GameStatus where
  toJSON Waiting = String "waiting"
  toJSON InProgress = String "in_progress"
  toJSON (Finished Nothing) = object ["status" .= String "draw"]
  toJSON (Finished (Just winner)) = object ["status" .= String "finished", "winner" .= winner]

instance FromJSON GameStatus

-- | Challenge between two players
data Challenge = Challenge
  { challengeId :: UUID
  , challenger :: UUID
  , challenged :: UUID
  }
  deriving (Generic)

-- | Server state
data ServerState = ServerState
  { onlinePlayers :: Map UUID Player
  , activeGames :: Map UUID GameState
  , pendingChallenges :: Map UUID Challenge
  }

-- | Messages from client to server
data ClientMessage
  = SetName Text
  | ChallengePlayer UUID
  | AcceptChallenge UUID
  | RejectChallenge UUID
  | MakeMove Int Int  -- row, col
  | GetOnlinePlayers
  deriving (Generic)

instance FromJSON ClientMessage where
  parseJSON = withObject "ClientMessage" $ \v -> do
    msgType <- v .: "type" :: Parser Text
    case msgType of
      "set_name" -> SetName <$> v .: "name"
      "challenge_player" -> ChallengePlayer <$> v .: "playerId"
      "accept_challenge" -> AcceptChallenge <$> v .: "challengeId"
      "reject_challenge" -> RejectChallenge <$> v .: "challengeId"
      "make_move" -> MakeMove <$> v .: "row" <*> v .: "col"
      "get_online_players" -> pure GetOnlinePlayers
      _ -> fail "Unknown message type"

-- | Messages from server to client
data ServerMessage
  = Welcome UUID  -- Send player their ID
  | OnlinePlayersList [(UUID, Text)]
  | ChallengeReceived UUID Text  -- challengeId, challenger name
  | ChallengeAccepted UUID  -- gameId
  | ChallengeRejected UUID
  | GameUpdate GameState
  | GameOver (Maybe Cell)  -- winner (Nothing for draw)
  | ErrorMessage Text
  | PlayerJoined UUID Text
  | PlayerLeft UUID
  deriving (Generic)

instance ToJSON ServerMessage where
  toJSON (Welcome uid) = object ["type" .= String "welcome", "playerId" .= uid]
  toJSON (OnlinePlayersList players) = object ["type" .= String "online_players", "players" .= map (\(uid, name) -> object ["id" .= uid, "name" .= name]) players]
  toJSON (ChallengeReceived cid name) = object ["type" .= String "challenge_received", "challengeId" .= cid, "challengerName" .= name]
  toJSON (ChallengeAccepted gid) = object ["type" .= String "challenge_accepted", "gameId" .= gid]
  toJSON (ChallengeRejected cid) = object ["type" .= String "challenge_rejected", "challengeId" .= cid]
  toJSON (GameUpdate gs) = object
    [ "type" .= String "game_update"
    , "gameId" .= gameId gs
    , "board" .= gameBoard gs
    , "currentTurn" .= currentTurn gs
    , "playerX" .= playerX gs
    , "playerO" .= playerO gs
    , "status" .= gameStatus gs
    ]
  toJSON (GameOver winner) = object ["type" .= String "game_over", "winner" .= winner]
  toJSON (ErrorMessage msg) = object ["type" .= String "error", "message" .= msg]
  toJSON (PlayerJoined uid name) = object ["type" .= String "player_joined", "playerId" .= uid, "name" .= name]
  toJSON (PlayerLeft uid) = object ["type" .= String "player_left", "playerId" .= uid]

-- | Helper to create empty board
emptyBoard :: Board
emptyBoard = replicate 3 (replicate 3 Empty)
