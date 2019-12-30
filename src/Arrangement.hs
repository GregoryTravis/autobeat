module Arrangement
( Arrangement(..)
, Placement(..)
, Span(..)
, TiledArrangement(..)
, getTiledArrangementElements
, renderArrangement
, mixdown ) where

import Control.Monad.ST
import Data.List
import qualified Data.StorableVector as SV
import qualified Data.StorableVector.ST.Strict as MSV

import Resample
import Sound
import Util

data TiledArrangement a = Elem a | Par [TiledArrangement a] | Seq [TiledArrangement a]

-- The end sample of a Span is the sample *just after* the end of the audio
data Span = Span Int Int deriving Show
data Placement = Placement Sound Span | NRPlacement Sound Int deriving Show
data Arrangement = Arrangement [Placement] deriving Show

-- instance Functor Arrangement where
--   fmap f (Arrangement placements) = Arrangement (map f placements)

-- applyToSpan f (Placement s span) = Placement s (f span)

-- mapOverSpans :: (Spen -> Span) -> Arrangement -> Arrangement
-- mapOverSpans f arr = fmap (applyToSpan f) arr

instance Functor TiledArrangement where
  fmap f (Elem e) = Elem (f e)
  fmap f (Par es) = Par (map (fmap f) es)
  fmap f (Seq es) = Seq (map (fmap f) es)

getTiledArrangementElements :: Ord a => TiledArrangement a -> [a]
getTiledArrangementElements seq = sort $ nub $ get' seq
  where get' (Elem a) = [a]
        get' (Par seqs) = concat (map get' seqs)
        get' (Seq seqs) = concat (map get' seqs)

---- Checks that all elements of a Par are the same length, throws if not
--checkTiledArrangment :: TiledArrangement Sound -> Bool
--checkTiledArrangment arr = foo (getLength arr)
--  where foo Nothing = False
--        foo (Just _) = True

---- Returns nothing if the contents of any Par are inconsistent (not all equal)
--getLength :: TiledArrangement Sound -> Maybe Int
--getLength (Elem s) = Just $ numFrames s
--getLength (Seq xs) = fmap sum $ sequence (map getLength xs)
--getLength (Par xs) = justOne $ sequence (map getLength xs)
--  where justOne (Just xs) | length (nub xs) == 1 = Just (head xs)
--                          | otherwise = Nothing
--        justOne Nothing = Nothing

--translate :: Int -> Arrangement -> Arrangement
--translate n arr = mapOverSpans (translateSpan n) arr

--translateSpan n (Span s e) = Span (s+n, e+n)

----getSpan arr

--tiledArrangementToArrangement :: TiledArrangement Sound -> Arrangement
--tiledArrangementToArrangement arr = fmap (translate n) arr

-- mapPlacements :: (Placement -> Placement) -> Arrangement -> Arrangement
-- mapPlacements f (Arrangement ps) = Arrangement (map f ps)

-- Convert any Placements to NRPlacements
arrNrpToP :: Arrangement -> IO Arrangement
arrNrpToP (Arrangement ps) = do
  newPs <- mapM nrpToP ps
  return $ Arrangement newPs

nrpToP :: Placement -> IO Placement
nrpToP x@(NRPlacement _ _) = return x
nrpToP (Placement sound (Span s e)) = do
  resampled <- resampleSound (e-s) sound
  return $ NRPlacement resampled s

-- All Placements must be Placements and not NRPlacements
renderArrangement :: Arrangement -> IO Sound
renderArrangement arr = do
  msp arr
  nrpArr <- arrNrpToP arr
  msp nrpArr
  mixNRPs nrpArr

mixNRPs :: Arrangement -> IO Sound
mixNRPs arr = do
  let len = arrangementLength arr
  msp len
  let mix = SV.replicate (len * 2) 0 :: SV.Vector Float
  msp $ SV.index mix 0
  msp $ SV.index mix 1
  let mix' = wha pmixOnto mix [(0, 10.0), (1, 20.0)]
  msp $ SV.index mix' 0
  msp $ SV.index mix' 1
  let nrps = case arr of Arrangement nrps -> nrps
  let mix'' = runST $ guv mix nrps
  return Sound { samples = mix'' }
  where yeah :: MSV.Vector s Float -> Placement -> ST s ()
        yeah mix (NRPlacement sound pos) = mixOnto mix (samples sound) pos
        guv :: SV.Vector Float -> [Placement] -> ST s (SV.Vector Float)
        guv mix nrps = do
          mmix <- MSV.thaw mix
          mapM (yeah mmix) nrps
          mix' <- MSV.freeze mmix
          return mix'

mixOnto :: MSV.Vector s Float -> SV.Vector Float -> Int -> ST s ()
mixOnto mix v pos = do
  mapM mixSample indices
  return ()
  where indices = take (SV.length v) [0..]
        mixSample i = do
          mixSample <- MSV.read mix (i + (pos * 2))
          let vSample = SV.index v i
          MSV.write mix (i + (pos * 2)) (mixSample + vSample)
          where db = show ("MIX", i, pos, SV.length v, MSV.length mix)

-- This must be something
-- wha :: (a -> b -> IO a) -> a -> [b] -> IO a
-- wha f a [] = return a
-- wha f a (b : bs) = do
--   newA <- f a b
--   wha f newA bs
-- This is a fold, right?
wha :: (a -> b -> a) -> a -> [b] -> a
wha f a [] = a
wha f a (b : bs) = wha f (f a b) bs

pmixOnto :: SV.Vector Float -> (Int, Float) -> SV.Vector Float
pmixOnto v (i, x) = runST foo
  where foo = do
          mv <- MSV.thaw v
          -- let mv :: MSV.Vector Float
          --     mv = mmv
          MSV.write mv i x
          v' <- MSV.freeze mv
          return v'

arrangementLength :: Arrangement -> Int
arrangementLength (Arrangement nrps) = maximum (map endOf nrps)
  where endOf (NRPlacement sound start) = start + numFrames sound

mixdown :: TiledArrangement Sound -> Sound
mixdown seq = normalize (mixdown' seq)
  where mixdown' (Elem sound) = sound
        mixdown' (Par mixes) = mixSounds (map mixdown' mixes)
        mixdown' (Seq mixes) = appendSounds (map mixdown' mixes)
