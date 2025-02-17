{-|
Helpers for making error messages.
-}

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Hledger.Data.Errors (
  makeAccountTagErrorExcerpt,
  makeTransactionErrorExcerpt,
  makePostingErrorExcerpt,
  makePostingAccountErrorExcerpt,
  makeBalanceAssertionErrorExcerpt,
  transactionFindPostingIndex,
)
where

import Data.Function ((&))
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T

import Hledger.Data.Transaction (showTransaction)
import Hledger.Data.Types
import Hledger.Utils
import Data.Maybe
import Safe (headMay)
import Hledger.Data.Posting (isVirtual)

-- | Given an account name and its account directive, and a problem tag within the latter:
-- render it as a megaparsec-style excerpt, showing the original line number and
-- marked column or region.
-- Returns the file path, line number, column(s) if known,
-- and the rendered excerpt, or as much of these as is possible.
-- The returned columns will be accurate for the rendered error message but not for the original journal data.
makeAccountTagErrorExcerpt :: (AccountName, AccountDeclarationInfo) -> TagName -> (FilePath, Int, Maybe (Int, Maybe Int), Text)
makeAccountTagErrorExcerpt (a, adi) _t = (f, l, merrcols, ex)
  -- XXX findtxnerrorcolumns is awkward, I don't think this is the final form
  where
    (SourcePos f pos _) = adisourcepos adi
    l = unPos pos
    txt   = showAccountDirective (a, adi) & textChomp & (<>"\n")
    ex = decorateTagErrorExcerpt l merrcols txt
    -- Calculate columns which will help highlight the region in the excerpt
    -- (but won't exactly match the real data, so won't be shown in the main error line)
    merrcols = Nothing
      -- don't bother for now
      -- Just (col, Just col2)
      -- where
      --   col  = undefined -- T.length (showTransactionLineFirstPart t') + 2
      --   col2 = undefined -- col + T.length tagname - 1      

showAccountDirective (a, AccountDeclarationInfo{..}) =
  "account " <> a
  <> (if not $ T.null adicomment then "    ; " <> adicomment else "")

-- | Add megaparsec-style left margin, line number, and optional column marker(s).
decorateTagErrorExcerpt :: Int -> Maybe (Int, Maybe Int) -> Text -> Text
decorateTagErrorExcerpt l mcols txt =
  T.unlines $ ls' <> colmarkerline <> map (lineprefix<>) ms
  where
    (ls,ms) = splitAt 1 $ T.lines txt
    ls' = map ((T.pack (show l) <> " | ") <>) ls
    colmarkerline =
      [lineprefix <> T.replicate (col-1) " " <> T.replicate regionw "^"
      | Just (col, mendcol) <- [mcols]
      , let regionw = maybe 1 (subtract col) mendcol + 1
      ]
    lineprefix = T.replicate marginw " " <> "| "
      where  marginw = length (show l) + 1

_showAccountDirective = undefined

-- | Given a problem transaction and a function calculating the best
-- column(s) for marking the error region:
-- render it as a megaparsec-style excerpt, showing the original line number
-- on the transaction line, and a column(s) marker.
-- Returns the file path, line number, column(s) if known,
-- and the rendered excerpt, or as much of these as is possible.
-- The returned columns will be accurate for the rendered error message but not for the original journal data.
makeTransactionErrorExcerpt :: Transaction -> (Transaction -> Maybe (Int, Maybe Int)) -> (FilePath, Int, Maybe (Int, Maybe Int), Text)
makeTransactionErrorExcerpt t findtxnerrorcolumns = (f, tl, merrcols, ex)
  -- XXX findtxnerrorcolumns is awkward, I don't think this is the final form
  where
    (SourcePos f tpos _) = fst $ tsourcepos t
    tl = unPos tpos
    txntxt = showTransaction t & textChomp & (<>"\n")
    merrcols = findtxnerrorcolumns t
    ex = decorateTransactionErrorExcerpt tl merrcols txntxt

-- | Add megaparsec-style left margin, line number, and optional column marker(s).
decorateTransactionErrorExcerpt :: Int -> Maybe (Int, Maybe Int) -> Text -> Text
decorateTransactionErrorExcerpt l mcols txt =
  T.unlines $ ls' <> colmarkerline <> map (lineprefix<>) ms
  where
    (ls,ms) = splitAt 1 $ T.lines txt
    ls' = map ((T.pack (show l) <> " | ") <>) ls
    colmarkerline =
      [lineprefix <> T.replicate (col-1) " " <> T.replicate regionw "^"
      | Just (col, mendcol) <- [mcols]
      , let regionw = maybe 1 (subtract col) mendcol + 1
      ]
    lineprefix = T.replicate marginw " " <> "| "
      where  marginw = length (show l) + 1

-- | Given a problem posting and a function calculating the best
-- column(s) for marking the error region:
-- look up error info from the parent transaction, and render the transaction
-- as a megaparsec-style excerpt, showing the original line number
-- on the problem posting's line, and a column indicator.
-- Returns the file path, line number, column(s) if known,
-- and the rendered excerpt, or as much of these as is possible.
-- A limitation: columns will be accurate for the rendered error message but not for the original journal data.
makePostingErrorExcerpt :: Posting -> (Posting -> Transaction -> Text -> Maybe (Int, Maybe Int)) -> (FilePath, Int, Maybe (Int, Maybe Int), Text)
makePostingErrorExcerpt p findpostingerrorcolumns =
  case ptransaction p of
    Nothing -> ("-", 0, Nothing, "")
    Just t  -> (f, errabsline, merrcols, ex)
      where
        (SourcePos f tl _) = fst $ tsourcepos t
        mpindex = transactionFindPostingIndex (==p) t
        errrelline = case mpindex of
          Nothing -> 0
          Just pindex ->
            commentExtraLines (tcomment t) + 
            sum (map postingLines $ take pindex $ tpostings t)
            where
              -- How many lines are used to render this posting ?
              postingLines p' = 1 + commentExtraLines (pcomment p')
              -- How many extra lines does this comment add to a transaction or posting rendering ?
              commentExtraLines c = max 0 (length (T.lines c) - 1)
        errabsline = unPos tl + errrelline
        txntxt = showTransaction t & textChomp & (<>"\n")
        merrcols = findpostingerrorcolumns p t txntxt
        ex = decoratePostingErrorExcerpt errabsline errrelline merrcols txntxt

-- | Add megaparsec-style left margin, line number, and optional column marker(s).
decoratePostingErrorExcerpt :: Int -> Int -> Maybe (Int, Maybe Int) -> Text -> Text
decoratePostingErrorExcerpt absline relline mcols txt =
  T.unlines $ js' <> ks' <> colmarkerline <> ms'
  where
    (ls,ms) = splitAt (relline+1) $ T.lines txt
    (js,ks) = splitAt (length ls - 1) ls
    (js',ks') = case ks of
      [k] -> (map (lineprefix<>) js, [T.pack (show absline) <> " | " <> k])
      _   -> ([], [])
    ms' = map (lineprefix<>) ms
    colmarkerline =
      [lineprefix <> T.replicate (col-1) " " <> T.replicate regionw "^"
      | Just (col, mendcol) <- [mcols]
      , let regionw = 1 + maybe 0 (subtract col) mendcol
      ]
    lineprefix = T.replicate marginw " " <> "| "
      where  marginw = length (show absline) + 1

-- | Find the 1-based index of the first posting in this transaction
-- satisfying the given predicate.
transactionFindPostingIndex :: (Posting -> Bool) -> Transaction -> Maybe Int
transactionFindPostingIndex ppredicate = 
  fmap fst . find (ppredicate.snd) . zip [1..] . tpostings

-- | From the given posting, make an error excerpt showing the transaction with
-- this posting's account part highlighted.
makePostingAccountErrorExcerpt :: Posting -> (FilePath, Int, Maybe (Int, Maybe Int), Text)
makePostingAccountErrorExcerpt p = makePostingErrorExcerpt p finderrcols
  where
    -- Calculate columns suitable for highlighting the synthetic excerpt.
    finderrcols p' _ _ = Just (col, Just col2)
      where
        col = 5 + if isVirtual p' then 1 else 0
        col2 = col + T.length (paccount p') - 1

-- | From the given posting, make an error excerpt showing the transaction with
-- the balance assertion highlighted.
makeBalanceAssertionErrorExcerpt :: Posting -> (FilePath, Int, Maybe (Int, Maybe Int), Text)
makeBalanceAssertionErrorExcerpt p = makePostingErrorExcerpt p finderrcols
  where
    finderrcols p' t trendered = Just (col, Just col2)
      where
        -- Analyse the rendering to find the columns to highlight.
        tlines = dbg5 "tlines" $ max 1 $ length $ T.lines $ tcomment t  -- transaction comment can generate extra lines
        (col, col2) =
          let def = (5, maximum (map T.length $ T.lines trendered))  -- fallback: underline whole posting. Shouldn't happen.
          in
            case transactionFindPostingIndex (==p') t of
              Nothing  -> def
              Just idx -> fromMaybe def $ do
                let
                  beforeps = take (idx-1) $ tpostings t
                  beforepslines = dbg5 "beforepslines" $ sum $ map (max 1 . length . T.lines . pcomment) beforeps   -- posting comment can generate extra lines (assume only one commodity shown)
                assertionline <- dbg5 "assertionline" $ headMay $ drop (tlines + beforepslines) $ T.lines trendered
                let
                  col2' = T.length assertionline
                  l = dropWhile (/= '=') $ reverse $ T.unpack assertionline
                  l' = dropWhile (`elem` ['=','*']) l
                  col' = length l' + 1
                return (col', col2')

