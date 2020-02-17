{-# LANGUAGE NamedFieldPuns #-}

module Gui
( gfxMain ) where

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
import Util

data Ding = Ding (V2 Float) (V2 Float)
  deriving Show

data GuiState = GuiState { getState :: State
                         , getDings :: [Ding] }
  --deriving Show

initGuiState :: State -> GuiState
initGuiState s = GuiState { getState = s, getDings = initDings s }

initDings :: State -> [Ding]
initDings s = take n dings
  where dings = repeat (Ding (V2 0 0) (V2 0 0))
        n = length (sounds s)

worldToPicture :: GuiState -> IO Picture
worldToPicture gs = return $ Pictures (map render (getDings gs))
  where render (Ding (V2 x y) _) = Translate x y $ Circle 20

--renderNode :: Node -> Picture
--renderNode (Node { pos = V2 x y }) = translate x y $ lineLoop (rectanglePath 30 50)

stepIteration :: Float -> Float -> GuiState -> IO GuiState
stepIteration t dt gs = return gs

data Cumulator a = Cumulator (Float, a)
cumulative :: (Float -> Float -> a -> IO a) -> (Float -> Cumulator a -> IO (Cumulator a))
cumulative si = newSi
  where newSi dt (Cumulator (t, w)) = do
          let t' = t + dt
          newW <- si t' dt w
          return $ Cumulator (t', newW)

cumulativePlayIO dm c rate w wtp eh si =  playIO dm c rate (Cumulator (0.0, w)) wtp' eh' si'
  where si' = cumulative si
        wtp' (Cumulator (_, w)) = wtp w
        eh' e (Cumulator (t, w)) = do
          w' <- eh e w
          return $ Cumulator (t, w')

gfxMain :: State -> IO ()
gfxMain s = do
  cumulativePlayIO displayMode bgColor 100 (initGuiState s) worldToPicture eventHandler stepIteration
  where displayMode = InWindow "Nice Window" (800, 800) (810, 10)
        bgColor = white

--"Event EventKey (SpecialKey KeyEsc) Down (Modifiers {shift = Up, ctrl = Up, alt = Up}) (383.0,20.0)"
eventHandler :: Event -> GuiState -> IO GuiState
eventHandler e w = do
  msp $ "Event " ++ (show e)
  quitOnEsc e
  return w
  where
    quitOnEsc (EventKey (SpecialKey KeyEsc) Down _ _) = exitSuccess
    quitOnEsc _                                       = return ()