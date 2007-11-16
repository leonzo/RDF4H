module Text.RDF.NTriplesSerializer(
  writeGraph, writeTriples, writeTriple,
  writeNode, writeLValue, writeLiteralString
) where

import Text.RDF.Core
import Text.RDF.Utils

import Data.ByteString.Char8(ByteString)
import qualified Data.ByteString.Char8 as B

import System.IO
import Control.Monad

writeGraph :: Graph gr => Handle -> gr -> IO ()
writeGraph h = writeTriples h . triplesOf

writeTriples :: Handle -> Triples -> IO ()
writeTriples h = mapM_ (writeTriple h)

writeTriple :: Handle -> Triple -> IO ()
writeTriple h (Triple s p o) =
  writeNode h s >> hPutChar h ' ' >>
  writeNode h p >> hPutChar h ' ' >>
  writeNode h o >> hPutStrLn h " ."

writeNode :: Handle -> Node -> IO ()
writeNode h node = 
  case node of
    (UNode fs)  -> hPutChar h '<' >> 
                     hPutStrRev h (value fs) >> 
                     hPutChar h '>'
    (BNode gId) -> hPutStrRev h (value gId)
    (BNodeGen i)-> hPutStr h (show i)
    (LNode n)   -> writeLValue h n

writeLValue :: Handle -> LValue -> IO ()
writeLValue h lv =
  case lv of
    (PlainL lit)       -> writeLiteralString h lit
    (PlainLL lit lang) -> writeLiteralString h lit >>
                            hPutStr h "@\"" >>
                            B.hPutStr h lang >> 
                            hPutStr h "\""
    (TypedL lit dtype) -> writeLiteralString h lit >> 
                            hPutStr h "^^\"" >>
                            hPutStrRev h (value dtype) >> 
                            hPutStr h "\""

writeLiteralString:: Handle -> ByteString -> IO ()
writeLiteralString h bs = 
  do hPutChar h '"'
     B.foldl' writeChar (return True) bs
     hPutChar h '"'
  where
    writeChar :: IO (Bool) -> Char -> IO (Bool)
    writeChar b c = 
      case c of 
        '\n' ->  b >>= \b' -> when b' (hPutChar h '\\' >> hPutChar h 'n')  >> return True
        '\t' ->  b >>= \b' -> when b' (hPutChar h '\\' >> hPutChar h 't')  >> return True
        '\r' ->  b >>= \b' -> when b' (hPutChar h '\\' >> hPutChar h 'r')  >> return True
        '"'  ->  b >>= \b' -> when b' (hPutChar h '\\' >> hPutChar h '"')  >> return True
        '\\' ->  b >>= \b' -> when b' (hPutChar h '\\' >> hPutChar h '\\') >> return True
        _    ->  b >>= \b' -> when b' (hPutChar  h c)                      >> return True

_bs1, _bs2 :: ByteString
_bs1 = B.pack "\nthis \ris a \\U00015678long\t\nliteral\\uABCD\n"
_bs2 = B.pack "\nan \\U00015678 escape\n"

_w :: IO ()
_w = writeLiteralString stdout _bs1