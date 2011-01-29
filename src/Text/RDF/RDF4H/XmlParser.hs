{-# LANGUAGE Arrows, RankNTypes, FlexibleContexts #-}
-- |An parser for the RDF/XML format 
-- <http://www.w3.org/TR/REC-rdf-syntax/>.

module Text.RDF.RDF4H.XmlParser(
  parseXmlRDF, getRDF
) where

import qualified Data.Map as Map
import Data.RDF

import Control.Arrow

import Text.XML.HXT.Core

import Data.ByteString.Lazy.Char8(ByteString)
import Data.String.Utils

-- |Parse a xml ByteString to an RDF representation
parseXmlRDF :: forall rdf. (RDF rdf)
            => Maybe BaseUrl           -- ^ The base URL for the RDF if required
            -> Maybe ByteString        -- ^ DocUrl: The request URL for the RDF if available
            -> ByteString              -- ^ The contents to parse
            -> Either ParseFailure rdf -- ^ The RDF representation of the triples or ParseFailure
parseXmlRDF bUrl dUrl xmlStr = case runSLA (xread >>> addMetaData bUrl dUrl >>> getRDF) 0 (b2s xmlStr) of
                                (_,r:rest) -> Right r
                                _ -> Left (ParseFailure "XML parsing failed")

-- |Add a root tag to a given XmlTree to appear as if it was read from a readDocument function
addMetaData :: (ArrowXml a) => Maybe BaseUrl -> Maybe ByteString -> a XmlTree XmlTree
addMetaData bUrlM dUrlM = mkelem "/"
                        ( [ sattr "transfer-Message" "OK"
                          , sattr "transfer-MimeType" "text/rdf"
                          ] ++ mkSource dUrlM ++ mkBase bUrlM
                        )
                        [ arr id ]
  where mkSource (Just dUrl) = [ sattr "source" (b2s dUrl) ]
        mkSource Nothing = []
        mkBase (Just (BaseUrl bUrl)) = [ sattr "transfer-URI" (b2s bUrl) ]
        mkBase Nothing = []

-- |Arrow that translates HXT XmlTree to an RDF representation
getRDF :: forall rdf a. (RDF rdf, ArrowXml a, ArrowState Int a) => a XmlTree rdf
getRDF = proc xml -> do
              rdf <- hasName "rdf:RDF" <<< isElem <<< getChildren                -< xml
              bUrl <- arr (Just . BaseUrl . s2b) <<< getAttrValue "transfer-URI" -< xml
              prefixMap <- arr toPrefixMap <<< toAttrMap                         -< rdf
              triples <- (parseDescription <<< isElem <<< getChildren) >. id     -< rdf
              returnA -< mkRdf triples bUrl prefixMap
  where toAttrMap = (getAttrl >>> (getName &&& (getChildren >>> getText))) >. id
        toPrefixMap = PrefixMappings . Map.fromList . map (\(n, m) -> (s2b (drop 6 n), s2b m)) . filter (startswith "xmlns:" . fst)
        parseDescription = proc desc -> do
                                s0 <- mkNode -< desc
                                (s, p, o) <- (arr2A getPredicatesFromAttr <+> arr2A getPredicatesFromChildren) -< (s0, desc)
                                returnA -< Triple s p o

getPredicatesFromChildren :: forall a. (ArrowXml a, ArrowState Int a) => Subject -> a XmlTree (Subject, Predicate, Object)
getPredicatesFromChildren s0 = proc rdf -> do
                                    cp <- isElem <<< getChildren        -< rdf
                                    p0 <- arr (unode . s2b) <<< getName -< cp
                                    co <- isElem <<< getChildren        -< cp
                                    o0 <- mkNode                        -< co
                                    (s, p, o) <- arr2A constA <+> (wrapKnownDescription <<< arr snd) -< ((s0, p0, o0), (o0, co))
                                    returnA -< (s, p, o)

recursiveParse :: forall a. (ArrowXml a, ArrowState Int a) => a ((Subject, Predicate, Object), (Object, XmlTree)) (Subject, Predicate, Object)
recursiveParse = arr2A constA <+> (arr (snd) >>> wrapKnownDescription)

wrapKnownDescription :: forall a. (ArrowXml a, ArrowState Int a) => a (Object, XmlTree) (Subject, Predicate, Object)
wrapKnownDescription = arr2A parseKnownDescription

parseKnownDescription :: forall a. (ArrowXml a, ArrowState Int a) => Subject -> a XmlTree (Subject, Predicate, Object)
parseKnownDescription s0 = proc desc -> do
                                (s, p, o) <- arr2A getPredicatesFromAttr <+> arr2A getPredicatesFromChildren -< (s0, desc)
                                returnA -< (s, p, o)

getPredicatesFromAttr :: forall a. (ArrowXml a, ArrowState Int a) => Subject -> a XmlTree (Subject, Predicate, Object)
getPredicatesFromAttr s = getAttrl >>> ((getName >>> isA (/= "rdf:about") >>> (arr (unode . s2b))) &&& (getChildren >>> getText >>> arr (lnode . plainL . s2b))) >>> arr (attachSubject s)

attachSubject :: Subject -> (Predicate, Object) -> (Subject, Predicate, Object)
attachSubject s (p, o) = (s, p, o)

-- |Read a Node from the "rdf:about" property or generate a blank node
mkNode :: forall a b. (ArrowXml a, ArrowState Int a) => a XmlTree Node
mkNode = ((getAttrValue0 "rdf:about" `orElse` getAttrValue0 "rdf:resource") >>> arr (unode . s2b)) `orElse` mkBlankNode

-- |Generate an RDF blank node with incrementing IDs from the arrow state
mkBlankNode :: forall a b. (ArrowState Int a) => a b Node
mkBlankNode = nextState (+1) >>> arr (BNodeGen)
