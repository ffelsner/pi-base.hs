{-# LANGUAGE RecordWildCards   #-}
module Universe
  ( empty
  , attributes
  , contains
  , insertTrait
  , insertTheorem
  , lookup
  , relevantTheorems
  , moveTheorem
  , table
  ) where

import Prelude hiding (lookup)
import Base
import Formula (implicationProperties)
import Util (encodeText)

import Control.Monad.State (modify, gets)
import qualified Data.Map  as M
import qualified Data.Set  as S
import qualified Data.Text as T

-- TODO: hide fields of Universe, only use this API

empty :: Universe
empty = Universe M.empty M.empty M.empty

lookup :: SpaceId -> PropertyId -> Universe -> Maybe TValueId
lookup s p = M.lookup p . attributes s

contains :: SpaceId -> PropertyId -> Universe -> Bool
contains sid pid = M.member pid . attributes sid

attributes :: SpaceId -> Universe -> Properties
attributes sid = fromMaybe M.empty . M.lookup sid . uspaces

relevantTheorems :: PropertyId -> Universe -> [(TheoremId, Implication)]
relevantTheorems pid u = z $ map withImplication theoremIds
  where
    theoremIds = M.findWithDefault [] pid $ urelTheorems u
    withImplication tid = (tid, M.lookup tid $ utheorems u)

    z [] = []
    z ((x, Just y) : zs) = (x,y) : z zs
    z (          _ : zs) =         z zs

-- TODO: refactor vvv
insertTrait :: SpaceId -> PropertyId -> TValueId -> State Universe ()
insertTrait s key t = modify $ \u -> u { uspaces = M.alter add s $ uspaces u }
  where
    add :: Maybe Properties -> Maybe Properties
    add mps = Just $ case mps of
      Nothing -> M.fromList [(key,t)]
      Just ps -> M.insert key t ps

insertTheorem :: TheoremId -> Implication -> State Universe ()
insertTheorem tid i = do
  thrmLk <- gets utheorems
  propLk <- gets urelTheorems
  -- TODO: verify id isn't already present (esp. for `provisional`)
  let theorems = M.insert tid i thrmLk
      relThrms = foldl addTid propLk $ S.toList $ implicationProperties i
  modify $ \u -> u { utheorems = theorems, urelTheorems = relThrms }
  where
    addTid :: Map PropertyId [TheoremId] -> PropertyId -> Map PropertyId [TheoremId]
    addTid m p = M.insertWith (++) p [tid] m

replace :: Eq a => a -> a -> [a] -> [a]
replace old new = map f
  where f x = if x == old then new else x

moveTheorem :: TheoremId -> TheoremId -> Universe -> Universe
moveTheorem old new u = u { utheorems = uts, urelTheorems = urs }
  where
    m   = utheorems u
    mv  = M.lookup old m
    uts = case mv of
      Just val -> M.insert new val $ M.delete old m
      Nothing  -> M.delete old m
    urs = M.map (replace old new) (urelTheorems u)

table :: Universe -> String
table Universe{..} = "Implications\n===\n" ++ implications
  where
    implications = unlines . map (T.unpack . encodeText) $ M.assocs utheorems
