{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE FlexibleContexts #-}

module System.Console.GetOpt.Generics (
  -- * Simple IO API
  withCli,
  WithCli(),
  HasArguments,
  WithCli.Argument(argumentType, parseArgument),
  -- * Customizing the CLI
  withCliModified,
  Modifier(..),
  -- * IO API
  getArguments,
  modifiedGetArguments,
  -- * Pure API
  parseArguments,
  Result(..),
  -- * Re-exports from "Generics.SOP"
  Generics.SOP.Generic,
  HasDatatypeInfo,
  Code,
  All2,
 ) where

import           Generics.SOP
import           System.Environment

import           WithCli
import           WithCli.Parser
import           WithCli.HasArguments
import           WithCli.Result
import           System.Console.GetOpt.Generics.Modifier

-- | Parses command line arguments (gotten from 'withArgs') and returns the
--   parsed value. This function should be enough for simple use-cases.
--
--   Throws the same exceptions as 'withCli'.
--
-- Here's an example:

-- ### Start "docs/RecordType.hs" "" Haddock ###

-- |
-- >  {-# LANGUAGE DeriveGeneric #-}
-- >
-- >  module RecordType where
-- >
-- >  import qualified GHC.Generics
-- >  import           System.Console.GetOpt.Generics
-- >
-- >  -- All you have to do is to define a type and derive some instances:
-- >
-- >  data Options
-- >    = Options {
-- >      port :: Int,
-- >      daemonize :: Bool,
-- >      config :: Maybe FilePath
-- >    }
-- >    deriving (Show, GHC.Generics.Generic)
-- >
-- >  instance Generic Options
-- >  instance HasDatatypeInfo Options
-- >
-- >  -- Then you can use `getArguments` to create a command-line argument parser:
-- >
-- >  main :: IO ()
-- >  main = do
-- >    options <- getArguments
-- >    print (options :: Options)

-- ### End ###

-- | And this is how the above program behaves:

-- ### Start "docs/RecordType.shell-protocol" "" Haddock ###

-- |
-- >  $ program --port 8080 --config some/path
-- >  Options {port = 8080, daemonize = False, config = Just "some/path"}
-- >  $ program  --port 8080 --daemonize
-- >  Options {port = 8080, daemonize = True, config = Nothing}
-- >  $ program --port foo
-- >  cannot parse as INTEGER: foo
-- >  # exit-code 1
-- >  $ program
-- >  missing option: --port=INTEGER
-- >  # exit-code 1
-- >  $ program --help
-- >  program [OPTIONS]
-- >        --port=INTEGER
-- >        --daemonize
-- >        --config=STRING (optional)
-- >    -h  --help                      show help and exit

-- ### End ###

getArguments :: forall a . (Generic a, HasDatatypeInfo a, All2 HasArguments (Code a)) =>
  IO a
getArguments = modifiedGetArguments []

-- | Like 'getArguments` but allows you to pass in 'Modifier's.
modifiedGetArguments :: forall a . (Generic a, HasDatatypeInfo a, All2 HasArguments (Code a)) =>
  [Modifier] -> IO a
modifiedGetArguments modifiers = do
  args <- getArgs
  progName <- getProgName
  handleResult $ parseArguments progName modifiers args

-- | Pure variant of 'modifiedGetArguments'.
--
--   Does not throw any exceptions.
parseArguments :: forall a . (Generic a, HasDatatypeInfo a, All2 HasArguments (Code a)) =>
     String -- ^ Name of the program (e.g. from 'getProgName').
  -> [Modifier] -- ^ List of 'Modifier's to manually tweak the command line interface.
  -> [String] -- ^ List of command line arguments to parse (e.g. from 'getArgs').
  -> Result a
parseArguments progName mods args = do
  modifiers <- mkModifiers mods
  parser <- genericParser modifiers
  runParser progName modifiers
    (normalizeParser (applyModifiers modifiers parser)) args
