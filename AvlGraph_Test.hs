import RDF
import AvlGraph
import Namespace

import GraphTestUtils

import Control.Monad
import Test.QuickCheck

instance Arbitrary AvlGraph where
  arbitrary = liftM mkGraph arbitraryTs
  coarbitrary = undefined

instance Show AvlGraph where
  --show gr = "Graph(n=" ++ show (length $ triplesOf gr) ++ ")"
  show gr = concatMap (\t -> show t ++ "\n")  (triplesOf gr)

graph :: Triples -> AvlGraph
graph = mkGraph

_empty :: AvlGraph
_empty = empty

_mkGraph :: Triples -> AvlGraph
_mkGraph = mkGraph

_triplesOf :: AvlGraph -> Triples
_triplesOf = triplesOf

-- The generic tests that apply to all graph implementations  --

prop_empty :: Bool
prop_empty = p_empty _triplesOf _empty

prop_mkGraph_triplesOf :: Triples -> Bool
prop_mkGraph_triplesOf = p_mkGraph_triplesOf _triplesOf _mkGraph

prop_mkGraph_no_dupes :: Triples -> Bool
prop_mkGraph_no_dupes = p_mkGraph_no_dupes _triplesOf _mkGraph

prop_query_all_wildcard :: Triples -> Bool
prop_query_all_wildcard = p_query_all_wildcard _mkGraph

prop_query_matched_spo :: AvlGraph -> Property
prop_query_matched_spo = p_query_matched_spo _triplesOf

prop_query_unmatched_spo :: AvlGraph -> Triple -> Property
prop_query_unmatched_spo = p_query_unmatched_spo _triplesOf

prop_query_match_s :: AvlGraph -> Property
prop_query_match_s = p_query_match_s _triplesOf

prop_query_match_p :: AvlGraph -> Property
prop_query_match_p = p_query_match_p _triplesOf

prop_query_match_o :: AvlGraph -> Property
prop_query_match_o = p_query_match_o _triplesOf

prop_query_match_sp :: AvlGraph -> Property
prop_query_match_sp = p_query_match_sp _triplesOf

prop_query_match_so :: AvlGraph -> Property
prop_query_match_so = p_query_match_so _triplesOf

prop_query_match_po :: AvlGraph -> Property
prop_query_match_po = p_query_match_po _triplesOf