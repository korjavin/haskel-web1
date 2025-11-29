{-# LANGUAGE OverloadedStrings #-}

module Main where

import Server
import Types
import Control.Concurrent (forkIO)
import Control.Concurrent.STM
import qualified Network.Wai as Wai
import qualified Network.Wai.Handler.Warp as Warp
import qualified Network.Wai.Handler.WebSockets as WaiWS
import qualified Network.WebSockets as WS
import Network.Wai.Middleware.Cors
import qualified Data.ByteString.Lazy as BL
import System.IO (hPutStrLn, stderr)

-- | Static file serving for frontend
staticApp :: Wai.Application
staticApp req respond = do
  let path = Wai.pathInfo req
  case path of
    [] -> serveFrontend respond
    ["index.html"] -> serveFrontend respond
    ["app.js"] -> serveFile "public/app.js" "application/javascript" respond
    ["style.css"] -> serveFile "public/style.css" "text/css" respond
    _ -> respond $ Wai.responseLBS
      (toEnum 404)
      [("Content-Type", "text/plain")]
      "Not found"

serveFrontend :: (Wai.Response -> IO Wai.ResponseReceived) -> IO Wai.ResponseReceived
serveFrontend respond = do
  content <- BL.readFile "public/index.html"
  respond $ Wai.responseLBS
    (toEnum 200)
    [("Content-Type", "text/html")]
    content

serveFile :: FilePath -> BL.ByteString -> (Wai.Response -> IO Wai.ResponseReceived) -> IO Wai.ResponseReceived
serveFile path contentType respond = do
  content <- BL.readFile path
  respond $ Wai.responseLBS
    (toEnum 200)
    [("Content-Type", contentType)]
    content

-- | WebSocket application
wsApp :: TVar ServerState -> WS.ServerApp
wsApp stateVar pending = do
  conn <- WS.acceptRequest pending
  WS.withPingThread conn 30 (return ()) $ do
    handleNewConnection stateVar conn

main :: IO ()
main = do
  hPutStrLn stderr "Starting TicTacToe server..."
  state <- newServerState

  let port = 8080
  hPutStrLn stderr $ "Server running on http://localhost:" ++ show port
  hPutStrLn stderr $ "WebSocket endpoint: ws://localhost:" ++ show port ++ "/ws"

  -- Combine WebSocket and HTTP apps
  let corsPolicy = simpleCorsResourcePolicy
        { corsRequestHeaders = ["Content-Type"]
        , corsMethods = ["GET", "POST", "OPTIONS"]
        }
  let app = cors (const $ Just corsPolicy) $
        WaiWS.websocketsOr WS.defaultConnectionOptions (wsApp state) staticApp

  Warp.run port app
