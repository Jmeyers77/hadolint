{-# LANGUAGE OverloadedStrings #-}
module Main where

import Data.Aeson
import Control.Monad (mzero)
import Snap.Http.Server
import Snap.Core
import Data.ByteString.Char8 (unpack)
import Hadolint.Parser (parseString)
import Hadolint.Rules (Check(..), Metadata(..), analyze, rules, link)


main :: IO ()
main = quickHttpServe site

site :: Snap ()
site = route [("dockerfile", lintHandler)]

analyzeAll = analyze rules

-- Helper to analyze AST quickly in GHCI
analyzeEither (Left err) = []
analyzeEither (Right dockerfile)  = analyzeAll dockerfile

lintHandler:: Snap ()
lintHandler = do
    modifyResponse $ setHeader "Content-Type" "application/json"
    modifyResponse $ setHeader "Access-Control-Allow-Origin" "*"
    modifyResponse $ setHeader "Access-Control-Allow-Methods" "GET, PUT, POST, DELETE, OPTIONS"
    modifyResponse $ setHeader "Access-Control-Allow-Headers" "*"

    source <- getParam "dockerfile"
    case source of
        Nothing   -> writeLBS "Please specify 'dockerfile' in request"
        Just str  -> do
            let ast = parseString $ unpack str
            case ast of
                Left err         -> writeLBS $ encode $ JsonError $ show err
                Right dockerfile -> writeLBS $ encode $ analyze rules dockerfile

data JsonError = JsonError String deriving (Show)
instance ToJSON JsonError where
    toJSON (JsonError error) = object [ "error" .= error ]

instance ToJSON Check where
    toJSON (Check metadata _ linenumber _) = object [ "metadata" .= metadata
                                                    , "linenumber" .= linenumber
                                                    , "link" .= link metadata
                                                    ]

instance ToJSON Metadata where
    toJSON (Metadata code severity message) = object [ "code" .= code
                                                     , "severity" .= show severity
                                                     , "message" .= message
                                                     ]
