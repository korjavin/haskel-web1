{-# LANGUAGE OverloadedStrings #-}

module Server where

import Types
import Game
import Control.Concurrent.STM
import Control.Monad (forever, forM_)
import Control.Exception (catch, SomeException)
import Data.Aeson (encode, decode)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Text (Text)
import qualified Data.Text as T
import Data.UUID (UUID)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUID
import qualified Network.WebSockets as WS
import Data.Maybe (mapMaybe)

-- | Create initial server state
newServerState :: IO (TVar ServerState)
newServerState = newTVarIO $ ServerState
  { onlinePlayers = Map.empty
  , activeGames = Map.empty
  , pendingChallenges = Map.empty
  }

-- | Send a message to a specific player
sendToPlayer :: Player -> ServerMessage -> IO ()
sendToPlayer player msg = do
  catch (WS.sendTextData (playerConnection player) (encode msg))
        (\(_ :: SomeException) -> return ())

-- | Broadcast a message to all online players
broadcastToAll :: TVar ServerState -> ServerMessage -> IO ()
broadcastToAll stateVar msg = do
  state <- readTVarIO stateVar
  let players = Map.elems (onlinePlayers state)
  forM_ players $ \player -> sendToPlayer player msg

-- | Broadcast to all players except one
broadcastToOthers :: TVar ServerState -> UUID -> ServerMessage -> IO ()
broadcastToOthers stateVar excludeId msg = do
  state <- readTVarIO stateVar
  let players = Map.elems $ Map.delete excludeId (onlinePlayers state)
  forM_ players $ \player -> sendToPlayer player msg

-- | Handle a new client connection
handleNewConnection :: TVar ServerState -> WS.Connection -> IO ()
handleNewConnection stateVar conn = do
  -- Generate new player ID
  pid <- UUID.nextRandom

  -- Send welcome message with player ID
  WS.sendTextData conn $ encode $ Welcome pid

  -- Store temporary player (without name initially)
  let tempPlayer = Player pid "" conn
  atomically $ modifyTVar' stateVar $ \state ->
    state { onlinePlayers = Map.insert pid tempPlayer (onlinePlayers state) }

  -- Handle incoming messages
  catch (forever $ do
    msg <- WS.receiveData conn
    case decode msg of
      Just clientMsg -> handleClientMessage stateVar pid clientMsg
      Nothing -> WS.sendTextData conn $ encode $ ErrorMessage "Invalid message format"
    )
    (\(_ :: SomeException) -> disconnect pid)

  where
    disconnect pid = do
      -- Remove player from state
      (name, _) <- atomically $ do
        state <- readTVar stateVar
        let player = Map.lookup pid (onlinePlayers state)
        let name = maybe "" playerName player
        modifyTVar' stateVar $ \s -> s { onlinePlayers = Map.delete pid (onlinePlayers s) }
        return (name, player)

      -- Notify others
      broadcastToOthers stateVar pid (PlayerLeft pid)

-- | Handle messages from client
handleClientMessage :: TVar ServerState -> UUID -> ClientMessage -> IO ()
handleClientMessage stateVar pid msg = case msg of
  SetName name -> do
    -- Update player name
    atomically $ modifyTVar' stateVar $ \state ->
      case Map.lookup pid (onlinePlayers state) of
        Just player ->
          let updatedPlayer = player { playerName = name }
          in state { onlinePlayers = Map.insert pid updatedPlayer (onlinePlayers state) }
        Nothing -> state

    -- Notify others that player joined
    broadcastToOthers stateVar pid (PlayerJoined pid name)

    -- Send current online players list to the new player
    state <- readTVarIO stateVar
    let player = Map.lookup pid (onlinePlayers state)
    case player of
      Just p -> do
        let playersList = mapMaybe (\(id, pl) ->
              if T.null (playerName pl) || id == pid
              then Nothing
              else Just (id, playerName pl))
              (Map.toList $ onlinePlayers state)
        sendToPlayer p (OnlinePlayersList playersList)
      Nothing -> return ()

  GetOnlinePlayers -> do
    state <- readTVarIO stateVar
    let player = Map.lookup pid (onlinePlayers state)
    case player of
      Just p -> do
        let playersList = mapMaybe (\(id, pl) ->
              if T.null (playerName pl) || id == pid
              then Nothing
              else Just (id, playerName pl))
              (Map.toList $ onlinePlayers state)
        sendToPlayer p (OnlinePlayersList playersList)
      Nothing -> return ()

  ChallengePlayer targetId -> do
    challengeId <- UUID.nextRandom
    (mChallengerPlayer, mTargetPlayer) <- atomically $ do
      state <- readTVar stateVar
      let challenge = Challenge challengeId pid targetId
      modifyTVar' stateVar $ \s ->
        s { pendingChallenges = Map.insert challengeId challenge (pendingChallenges s) }
      return (Map.lookup pid (onlinePlayers state), Map.lookup targetId (onlinePlayers state))

    case (mChallengerPlayer, mTargetPlayer) of
      (Just challenger, Just target) ->
        sendToPlayer target (ChallengeReceived challengeId (playerName challenger))
      _ -> do
        state <- readTVarIO stateVar
        case Map.lookup pid (onlinePlayers state) of
          Just p -> sendToPlayer p (ErrorMessage "Player not found")
          Nothing -> return ()

  AcceptChallenge challengeId -> do
    mChallenge <- atomically $ do
      state <- readTVar stateVar
      return $ Map.lookup challengeId (pendingChallenges state)

    case mChallenge of
      Nothing -> do
        state <- readTVarIO stateVar
        case Map.lookup pid (onlinePlayers state) of
          Just p -> sendToPlayer p (ErrorMessage "Challenge not found")
          Nothing -> return ()
      Just challenge -> do
        -- Create new game
        gameId <- UUID.nextRandom
        let newGame = GameState
              { gameId = gameId
              , gameBoard = emptyBoard
              , currentTurn = X
              , playerX = challenger challenge
              , playerO = challenged challenge
              , gameStatus = InProgress
              }

        (mChallenger, mChallenged) <- atomically $ do
          modifyTVar' stateVar $ \state ->
            state { activeGames = Map.insert gameId newGame (activeGames state)
                  , pendingChallenges = Map.delete challengeId (pendingChallenges state)
                  }
          state <- readTVar stateVar
          return ( Map.lookup (challenger challenge) (onlinePlayers state)
                 , Map.lookup (challenged challenge) (onlinePlayers state)
                 )

        -- Notify both players
        case (mChallenger, mChallenged) of
          (Just challengerPlayer, Just challengedPlayer) -> do
            sendToPlayer challengerPlayer (ChallengeAccepted gameId)
            sendToPlayer challengedPlayer (ChallengeAccepted gameId)
            sendToPlayer challengerPlayer (GameUpdate newGame)
            sendToPlayer challengedPlayer (GameUpdate newGame)
          _ -> return ()

  RejectChallenge challengeId -> do
    mChallenge <- atomically $ do
      state <- readTVar stateVar
      let challenge = Map.lookup challengeId (pendingChallenges state)
      modifyTVar' stateVar $ \s ->
        s { pendingChallenges = Map.delete challengeId (pendingChallenges s) }
      return challenge

    case mChallenge of
      Just challenge -> do
        state <- readTVarIO stateVar
        case Map.lookup (challenger challenge) (onlinePlayers state) of
          Just challengerPlayer -> sendToPlayer challengerPlayer (ChallengeRejected challengeId)
          Nothing -> return ()
      Nothing -> return ()

  MakeMove row col -> do
    -- Find active game where player is participating
    (mGame, mPlayers) <- atomically $ do
      state <- readTVar stateVar
      let games = Map.elems $ activeGames state
      let playerGame = filter (\g -> playerX g == pid || playerO g == pid) games
      case playerGame of
        [] -> return (Nothing, Nothing)
        (game:_) -> do
          let opponentId = if playerX game == pid then playerO game else playerX game
          return (Just game, (,) <$> Map.lookup pid (onlinePlayers state)
                                  <*> Map.lookup opponentId (onlinePlayers state))

    case (mGame, mPlayers) of
      (Just game, Just (currentPlayer, opponent)) -> do
        case processMove game pid row col of
          Left err -> sendToPlayer currentPlayer (ErrorMessage err)
          Right updatedGame -> do
            atomically $ modifyTVar' stateVar $ \state ->
              state { activeGames = Map.insert (gameId updatedGame) updatedGame (activeGames state) }

            -- Send update to both players
            sendToPlayer currentPlayer (GameUpdate updatedGame)
            sendToPlayer opponent (GameUpdate updatedGame)

            -- If game is over, send game over message
            case gameStatus updatedGame of
              Finished winner -> do
                sendToPlayer currentPlayer (GameOver winner)
                sendToPlayer opponent (GameOver winner)
              _ -> return ()
      _ -> do
        state <- readTVarIO stateVar
        case Map.lookup pid (onlinePlayers state) of
          Just p -> sendToPlayer p (ErrorMessage "No active game found")
          Nothing -> return ()
