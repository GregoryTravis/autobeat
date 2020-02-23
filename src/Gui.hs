{-# LANGUAGE NamedFieldPuns #-}

module Gui
  ( guiMain
  , windowWidth
  , windowHeight ) where

import Control.Concurrent (forkIO, threadDelay, killThread)
--import Control.Concurrent.MVar
import Control.Concurrent.STM.TChan
import Control.Exception (finally)
import Control.Monad.STM (atomically)
import Data.Time.Clock (NominalDiffTime, diffUTCTime)
import Data.Time.Clock.System (getSystemTime, systemToUTCTime, SystemTime)
--import GHC.Float (float2Float)
import Graphics.Gloss
import Graphics.Gloss.Interface.IO.Game
import Linear
import System.Exit (exitSuccess)
import System.Random

import State
import TUI
import Util

windowWidth = 800
windowHeight = 800

data GuiState s v = GuiState s v

guiMain :: s -> (s -> s -> v) -> (v -> Picture) -> (Float -> v -> v) -> (Char -> s -> IO s) -> IO ()
guiMain s statesToViz renderViz advanceViz keyboardHandler =
  let initWorld = GuiState s (statesToViz s s)
      worldToPicture (GuiState s v) = return $ renderViz v
      eventHandler (EventKey (SpecialKey KeyEsc) Down _ _) gs = do
        exitSuccess
        return gs
      eventHandler (EventKey (Char c) Down _ _) (GuiState s v) = do
        s' <- keyboardHandler c s
        return $ GuiState s' (statesToViz s s')
      eventHandler e gs = return gs
      stepIteration dt (GuiState s v) = return $ GuiState s (advanceViz dt v)
   in playIO displayMode bgColor 100 initWorld worldToPicture eventHandler stepIteration
  where displayMode = InWindow "Nice Window" (windowWidth, windowHeight) (810, 10)
        bgColor = white
