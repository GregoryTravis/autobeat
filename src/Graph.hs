{-# LANGUAGE TupleSections #-}

module Graph
( Graph
, empty
, add
, addMulti
, nodes
, components
, fromComponents
, showGraphAsComponents ) where

---- Really dumb undirected graph: extremely slow!!

import Data.Containers.ListUtils (nubOrd)
import Data.List (intercalate, intersect, nub)
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import Util

-- An unordered graph expressed as a map from each node to all the nodes it
-- shares an edge with. Each edge is represented twice, once for each of its
-- nodes. This representation does not permit nodes without any edges attached
-- to them.

data Graph a = Graph (M.Map a (S.Set a))
  deriving Eq

instance (Eq a, Ord a, Show a) => Show (Graph a) where
  show g = show $ edges g

empty = Graph (M.empty)

-- Add an edge (x, y). Adds y to the adjacency list for x, and vice versa,
-- because I'm a jerk.
add :: (Ord a, Show a) => Graph a -> a -> a -> Graph a
add g x y =
  let g' = addKeyIfMissing g x
      g'' = addKeyIfMissing g' y
      (Graph m) = g''
      m' = M.adjust (S.insert x) y m
      m'' = M.adjust (S.insert y) x m'
   -- in eesp (show ("hoy", m, m', m'')) $ Graph m''
   in Graph m''

-- Add multiple edges.
-- TODO this is a fold
addMulti :: (Ord a, Show a) => Graph a -> [(a, a)] -> Graph a
addMulti g ((x, y) : ps) = addMulti (add g x y) ps
addMulti g [] = g

-- Add the given elements as a connected component: given (x:ys), add (x, y)
-- for each y in ys.
addComponent :: (Ord a, Show a) => Graph a -> [a] -> Graph a
addComponent g (x:xs) = addMulti g (zip (repeat x) xs)
addComponent g [] = g

edges :: (Eq a, Ord a) => Graph a -> [(a, a)]
edges g = nubOrd $ map sortEdge $ directedEdges g

sortEdge :: Ord a => (a, a) -> (a, a)
sortEdge (a, b) | a > b = (b, a)
sortEdge (a, b) | otherwise = (a, b)

-- Return each edge twice, in each ordering
directedEdges :: Ord a => Graph a -> [(a, a)]
directedEdges g@(Graph m) = concat (Prelude.map (nodeEdges g) (M.keys m))

-- Return all edges (x, y) for the given x
nodeEdges :: Ord a => Graph a -> a -> [(a, a)]
nodeEdges (Graph m) x = map (x,) $ S.toList (m M.! x)

-- Return connected components of the graph
-- This is extremely inefficient; it constructs a size-n component n times
components :: (Eq a, Ord a, Show a) => Graph a -> [S.Set a]
components g = nub $ Prelude.map (closure g) (S.toList (nodes g))

showComponents :: Show a => [S.Set a] -> String
showComponents sets = intercalate " " $ map show (map S.toList sets)

showGraphAsComponents :: (Eq a, Ord a, Show a) => Graph a -> String
showGraphAsComponents = showComponents . components

-- Construct a graph from the given connected components.
-- They don't have to be disjoint, so (components . fromComponents) /= id
fromComponents :: (Show a, Ord a) => [[a]] -> Graph a
fromComponents [] = Graph M.empty
fromComponents (c:cs) = addComponent (fromComponents cs) c

nodes :: Ord a => Graph a -> S.Set a
nodes (Graph m) = flatten (M.elems m)

closure :: (Ord a, Show a) => Graph a -> a -> S.Set a
closure g x = converge (closure' g) (S.singleton x)

closure' :: (Ord a, Show a) => Graph a -> S.Set a -> S.Set a
closure' (Graph m) xs = xs `S.union` (flatten $ Prelude.map (m M.!) (S.toList xs))

flatten :: Ord a => [S.Set a] -> S.Set a
flatten sets = S.fromList (concat (Prelude.map S.toList sets))

-- I wonder if this doesn't recompute (f x)
converge :: Eq a => (a -> a) -> a -> a
converge f x | (f x) == x = x
converge f x | otherwise = converge f (f x)

addKeyIfMissing :: Ord a => Graph a -> a -> Graph a
addKeyIfMissing g x | graphMember x g = g
addKeyIfMissing (Graph m) x | otherwise = Graph $ M.insert x S.empty m

graphMember :: Ord a => a -> Graph a -> Bool
graphMember x (Graph m) = M.member x m

-- Separate module?
type MetaGraph a = Graph [a]

-- Construct a k-metagraph.
-- Such a graph has an edge (x, y) if the intersection of x and y is of size k or greater.
buildMetaGraph :: (Eq a, Show a, Ord a) => [[a]] -> Int -> MetaGraph a
buildMetaGraph xses k = addMulti empty (findOverlapping k xses)

-- Return pairs of lists that overlap
findOverlapping :: (Eq a, Show a, Ord a) => Int -> [[a]] -> [([a], [a])]
findOverlapping k xses = filter (uncurry $ overlapBy k) pairs
  where pairs = [(xs, ys) | xs <- xses, ys <- xses]

-- -- Return pairs of lists that overlap by at least k
-- findOverlapping :: (Eq a, Show a, Ord a) => [[a]] -> Int -> [([a], [a])]
-- findOverlapping xses k = filter (> k . length) (findOverlapping xses)

-- Nonempty intersection?
overlapBy :: Eq a => Int -> [a] -> [a] -> Bool
overlapBy k xs ys = length (intersect xs ys) >= k
