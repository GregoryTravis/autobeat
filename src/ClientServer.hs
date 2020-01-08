{-# LANGUAGE BlockArguments #-}

module ClientServer (client, server) where

import Control.Concurrent (forkIO, forkFinally, killThread, threadDelay)
import qualified Control.Exception as E
import Control.Monad (unless, forever, void)
import qualified Data.ByteString as S
import qualified Data.ByteString.Char8 as C
import Network.Socket
--import Network.Socket hiding (recv)
--import Network.Socket (withFdSocket)
import Network.Socket.ByteString (recv, sendAll)

import Util

-- todo
-- move this to TCP.hs
-- withServer wrapper so we can clean it up
-- Use a chan
-- withRemote wrapper which provides the client chan
-- Open a gfx window in the server
-- only draw the circle when the command comes

server = do
  runTCPServer Nothing "3000" talk
  where
    talk s = do
        msg <- recv s 1024000000
        msp $ C.unpack msg
        unless (S.null msg) $ do
          sendAll s msg
          talk s

-- from the "network-run" package.
runTCPServer :: Maybe HostName -> ServiceName -> (Socket -> IO a) -> IO a
runTCPServer mhost port server = withSocketsDo $ do
    addr <- resolve
    E.bracket (open addr) close loop
  where
    resolve = do
        let hints = defaultHints {
                addrFlags = [AI_PASSIVE]
              , addrSocketType = Stream
              }
        head <$> getAddrInfo (Just hints) mhost (Just port)
    open addr = do
        sock <- socket (addrFamily addr) (addrSocketType addr) (addrProtocol addr)
        setSocketOption sock ReuseAddr 1
        withFdSocket sock $ setCloseOnExecIfNeeded
        bind sock $ addrAddress addr
        listen sock 1024
        return sock
    loop sock = forever $ do
        (conn, _peer) <- accept sock
        void $ forkFinally (server conn) (const $ gracefulClose conn 5000)-- import Network.Socket

client :: IO ()
client = runTCPClient "127.0.0.1" "3000" $ \s -> do
    sendAll s $ C.pack "Hello, world!"
    msg <- recv s 1024000000
    putStr "Received: "
    C.putStrLn msg

-- from the "network-run" package.
runTCPClient :: HostName -> ServiceName -> (Socket -> IO a) -> IO a
runTCPClient host port client = withSocketsDo $ do
    addr <- resolve
    E.bracket (open addr) close client
  where
    resolve = do
        let hints = defaultHints { addrSocketType = Stream }
        head <$> getAddrInfo (Just hints) (Just host) (Just port)
    open addr = do
        sock <- socket (addrFamily addr) (addrSocketType addr) (addrProtocol addr)
        connect sock $ addrAddress addr
        return sock