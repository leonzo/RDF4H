{-# LANGUAGE RankNTypes #-}
-- |This module re-exports most of the other modules of this library and also
-- defines some convenience methods for interactive experimentation, such as
-- simplified functions for parsing and serializing RDF, etc.
--
-- All the load functions can be used with any 'Graph' implementation, so you
-- must declare a type in order to help the type system disambiguate the 
-- @Graph gr@ constraint in those function's types.
-- 
-- Many of the simplified functions in this module call 'error' when there is 
-- a failure. This is so that you don't have to deal with 'Maybe' or 'Either'
-- return values while interacting. These functions are thus only intended
-- to be used when interactively exploring via ghci, and should not otherwise
-- be used.

module Text.RDF.RDF4H.Interact where

import Data.ByteString.Lazy.Char8(ByteString)
import qualified Data.ByteString.Lazy.Char8 as B

import Data.RDF
import Data.RDF.Utils()
import Data.RDF.TriplesGraph()
import Data.RDF.MGraph()
import Text.RDF.RDF4H.NTriplesParser (parseNTriplesRDF)
import Text.RDF.RDF4H.TurtleParser (parseTurtleRDF)
import Text.RDF.RDF4H.NTriplesSerializer()
import Text.RDF.RDF4H.TurtleSerializer()

-- |Load a Turtle file from the filesystem using the optional base URL 
-- (used to resolve relative URI fragments) and optional document URI
-- (used to resolve <> in the document). 
-- 
-- This function calls 'error' with an error message if unable to load the file.
loadTurtleFile :: forall rdf. (RDF rdf) => Maybe String -> Maybe String -> String -> IO rdf
loadTurtleFile baseUrl docUri = _load (parseFile' (mkTurtleParser baseUrl docUri))

-- |Load a Turtle file from a URL just like 'loadTurtleFile' does from the local
-- filesystem. See that function for explanation of args, etc.
loadTurtleURL  :: forall rdf. (RDF rdf) => Maybe String -> Maybe String -> String -> IO rdf
loadTurtleURL baseUrl docUri  = _load (parseURL' (mkTurtleParser baseUrl docUri))

-- |Parse a Turtle document from the given 'ByteString' using the given @baseUrl@ and 
-- @docUri@, which have the same semantics as in the loadTurtle* functions.
parseTurtleString :: forall rdf. (RDF rdf) => Maybe String -> Maybe String -> ByteString -> rdf
parseTurtleString baseUrl docUri = _parse (mkTurtleParser baseUrl docUri)

mkTurtleParser :: forall rdf. (RDF rdf)
               => Maybe String -> Maybe String -> ByteString -> Either ParseFailure rdf
mkTurtleParser b d = parseTurtleRDF ((BaseUrl . B.pack) `fmap` b) (B.pack `fmap` d)

-- |Load an NTriples file from the filesystem.
-- 
-- This function calls 'error' with an error message if unable to load the file.
loadNTriplesFile :: forall rdf. (RDF rdf) => String -> IO rdf
loadNTriplesFile = _load (parseFile' parseNTriplesRDF)

-- |Load an NTriples file from a URL just like 'loadNTriplesFile' does from the local
-- filesystem. See that function for more info.
loadNTriplesURL :: forall rdf. (RDF rdf) => String -> IO rdf
loadNTriplesURL  = _load (parseURL' parseNTriplesRDF)

-- |Parse an NTriples document from the given 'ByteString', as 'loadNTriplesFile' does
-- from a file.
parseNTriplesString :: forall rdf. (RDF rdf) => ByteString -> rdf
parseNTriplesString = _parse parseNTriplesRDF

-- |Print a list of triples to stdout; useful for debugging and interactive use.
printTriples :: Triples -> IO ()
printTriples  = mapM_ print

-- Load a graph using the given parseFunc, parser, and the location (filesystem path
-- or HTTP URL), calling error with the 'ParseFailure' message if unable to load
-- or parse for any reason.
_load :: forall rdf. (RDF rdf)
      => (String -> IO (Either ParseFailure rdf))
      -> String -> IO rdf
_load parser location = parser location >>= _handle

-- Use the given parseFunc and parser to parse the given 'ByteString', calling error
-- with the 'ParseFailure' message if unable to load or parse for any reason.
_parse :: forall rdf. (RDF rdf)
       => (ByteString -> Either ParseFailure rdf)
       -> ByteString -> rdf
_parse parser rdfBs = either (error . show) id $ parser rdfBs

-- Handle the result of an IO parse by returning the graph if parse was successful
-- and calling 'error' with the 'ParseFailure' error message if unsuccessful.
_handle :: forall rdf. (RDF rdf) => Either ParseFailure rdf -> IO rdf
_handle = either (error . show) return
