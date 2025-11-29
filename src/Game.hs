{-# LANGUAGE OverloadedStrings #-}

module Game where

import Types
import Data.Maybe (isNothing, listToMaybe)
import Data.UUID (UUID)

-- | Check if a move is valid
isValidMove :: Board -> Int -> Int -> Bool
isValidMove board row col
  | row < 0 || row > 2 || col < 0 || col > 2 = False
  | otherwise = board !! row !! col == Empty

-- | Make a move on the board
makeMove :: Board -> Int -> Int -> Cell -> Maybe Board
makeMove board row col player
  | isValidMove board row col = Just $ updateBoard board row col player
  | otherwise = Nothing

-- | Update board at position
updateBoard :: Board -> Int -> Int -> Cell -> Board
updateBoard board row col player =
  let (beforeRows, targetRow:afterRows) = splitAt row board
      (beforeCols, _:afterCols) = splitAt col targetRow
      newRow = beforeCols ++ [player] ++ afterCols
  in beforeRows ++ [newRow] ++ afterRows

-- | Check for a winner
checkWinner :: Board -> Maybe Cell
checkWinner board = listToMaybe $ filter (/= Empty) $ concatMap checkLine allLines
  where
    allLines = rows ++ cols ++ diagonals
    rows = board
    cols = [[board !! r !! c | r <- [0..2]] | c <- [0..2]]
    diagonals = [[board !! i !! i | i <- [0..2]], [board !! i !! (2-i) | i <- [0..2]]]

    checkLine :: [Cell] -> [Cell]
    checkLine [a, b, c]
      | a /= Empty && a == b && b == c = [a]
      | otherwise = []
    checkLine _ = []

-- | Check if board is full (draw)
isBoardFull :: Board -> Bool
isBoardFull = all (all (/= Empty))

-- | Determine game status after a move
getGameStatus :: Board -> GameStatus
getGameStatus board =
  case checkWinner board of
    Just winner -> Finished (Just winner)
    Nothing -> if isBoardFull board
               then Finished Nothing
               else InProgress

-- | Get next turn
nextTurn :: Cell -> Cell
nextTurn X = O
nextTurn O = X
nextTurn Empty = X

-- | Process a move and return updated game state
processMove :: GameState -> UUID -> Int -> Int -> Either Text GameState
processMove game pid row col
  | gameStatus game /= InProgress = Left "Game is not in progress"
  | currentTurn game == X && pid /= playerX game = Left "Not your turn"
  | currentTurn game == O && pid /= playerO game = Left "Not your turn"
  | otherwise = case makeMove (gameBoard game) row col (currentTurn game) of
      Nothing -> Left "Invalid move"
      Just newBoard ->
        let newStatus = getGameStatus newBoard
            newTurn = if newStatus == InProgress then nextTurn (currentTurn game) else currentTurn game
        in Right $ game { gameBoard = newBoard
                        , currentTurn = newTurn
                        , gameStatus = newStatus
                        }
