{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE ScopedTypeVariables #-}

module System.Console.GetOpt.GenericsSpec where

import           Control.Exception
import           Data.Foldable                   (forM_)
import           Data.List
import           Generics.SOP
import qualified GHC.Generics                    as GHC
import           System.Environment
import           System.Exit
import           System.IO
import           System.IO.Silently
import           Test.Hspec
import           Test.Hspec.Expectations.Contrib

import           System.Console.GetOpt.Generics

data Foo
  = Foo {
    bar :: Maybe Int,
    baz :: String,
    bool :: Bool
  }
  deriving (GHC.Generic, Show, Eq)

instance Generic Foo
instance HasDatatypeInfo Foo

spec :: Spec
spec = do
  describe "withArguments" $ do
    it "parses command line arguments" $ do
      withArgs (words "--bar 4 --baz foo") $
        getArguments `shouldReturn` Foo (Just 4) "foo" False

    it "allows optional arguments" $ do
      withArgs (words "--baz foo") $
        getArguments `shouldReturn` Foo Nothing "foo" False

    it "allows boolean flags" $ do
      withArgs (words "--bool --baz foo") $
        getArguments `shouldReturn` Foo Nothing "foo" True

    context "invalid arguments" $ do
      it "doesn't execute the action" $ do
        let main = withArgs (words "--invalid") $ do
              _ :: Foo <- getArguments
              throwIO (ErrorCall "action")
        main `shouldThrow` (== ExitFailure 1)

      it "prints out an error" $ do
        output <- hCapture_ [stderr] $ handle (\ (_ :: SomeException) -> return ()) $
          withArgs (words "--no-such-option") $ do
            _ :: Foo <- getArguments
            return ()
        output `shouldContain` "unrecognized"
        output `shouldContain` "--no-such-option"

      it "prints errors for missing options" $ do
        output <- hCapture_ [stderr] $ handle (\ (_ :: SomeException) -> return ()) $
          withArgs [] $ do
            _ :: Foo <- getArguments
            return ()
        output `shouldContain` "missing option: --baz=string"

      it "prints out an error for unparseable options" $ do
        output <- hCapture_ [stderr] $ handle (\ (_ :: SomeException) -> return ()) $
          withArgs (words "--bar foo --baz huhu") $ do
            _ :: Foo <- getArguments
            return ()
        output `shouldContain` "not an integer: foo"

      it "complains about invalid overwritten options" $ do
        output <- hCapture_ [stderr] $ handle (\ (_ :: SomeException) -> return ()) $
          withArgs (words "--bar foo --baz huhu --bar 12") $ do
            _ :: Foo <- getArguments
            return ()
        output `shouldContain` "not an integer: foo"

    context "--help" $ do
      it "implements --help" $ do
        output <- capture_ $ withArgs ["--help"] $
          handle (\ (_ :: SomeException) -> return ()) $ do
            _ :: Foo <- getArguments
            return ()
        mapM_ (output `shouldContain`) $
          "--bar=integer" : "optional" :
          "--baz=string" :
          "--bool" :
          []

      it "throws ExitSuccess" $ do
        withArgs ["--help"] (getArguments :: IO Foo)
          `shouldThrow` (== ExitSuccess)

      it "does not contain trailing spaces" $ do
        output <- capture_ $ withArgs ["--help"] $
          handle (\ (_ :: SomeException) -> return ()) $ do
            _ :: Foo <- getArguments
            return ()
        forM_ (lines output) $ \ line ->
          line `shouldSatisfy` (not . (" " `isSuffixOf`))

  next1

data ListOptions
  = ListOptions {
    multiple :: [String]
  }
  deriving (GHC.Generic, Show, Eq)

instance Generic ListOptions
instance HasDatatypeInfo ListOptions

next1 :: Spec
next1 = do
  describe "withArguments" $ do
    it "allows to interpret multiple uses of the same option as lists" $ do
      withArgs (words "--multiple foo --multiple bar") $ do
        getArguments `shouldReturn` ListOptions ["foo", "bar"]
  next2

data CamelCaseOptions
  = CamelCaseOptions {
    camelCase :: String
  }
  deriving (GHC.Generic, Show, Eq)

instance Generic CamelCaseOptions
instance HasDatatypeInfo CamelCaseOptions

next2 :: Spec
next2 = do
  describe "withArguments" $ do
    it "turns camelCase selectors to lowercase and seperates with a dash" $ do
        withArgs (words "--camel-case foo") $ do
          getArguments `shouldReturn` CamelCaseOptions "foo"

    it "help does not contain camelCase flags" $ do
      let OutputAndExit output :: Result CamelCaseOptions
            = parseArguments "header" [] ["--help"]
      output `shouldNotContain` "camelCase"
      output `shouldContain` "camel-case"

    it "error messages don't contain camelCase flags" $ do
      let Errors errs :: Result CamelCaseOptions
            = parseArguments "header" [] ["--bla"]
      show errs `shouldNotContain` "camelCase"
      show errs `shouldContain` "camel-case"

  describe "parseArguments" $ do
    context "Short" $ do
      it "allows hints for short options" $ do
        parseArguments "header" [Short "camel-case" 'x'] (words "-x foo")
          `shouldBe` Success (CamelCaseOptions "foo")

      it "allows hints in camelCase" $ do
        parseArguments "header" [Short "camelCase" 'x'] (words "-x foo")
          `shouldBe` Success (CamelCaseOptions "foo")

      let parse :: [String] -> Result CamelCaseOptions
          parse = parseArguments "header" [Short "camelCase" 'x']
      it "includes the short option in the help" $ do
        let OutputAndExit output = parse ["--help"]
        output `shouldContain` "-x string"

    context "Rename" $ do
      it "allows to rename options" $ do
        parseArguments "header" [RenameOption "camelCase" "bla"] (words "--bla foo")
          `shouldBe` Success (CamelCaseOptions "foo")

      let parse = parseArguments "header"
            [RenameOption "camelCase" "foo", RenameOption "camelCase" "bar"]
      it "allows to shadow earlier hints with later hints" $ do
        parse (words "--bar foo")
          `shouldBe` Success (CamelCaseOptions "foo")
        let Errors errs = parse (words "--foo foo")
        show errs `shouldContain` "unknown argument: foo"

      it "contains renamed options in error messages" $ do
        let Errors errs = parse []
        show errs `shouldNotContain` "camelCase"
        show errs `shouldContain` "camel-case"

      it "allows to address fields in Modifiers in slugified form" $ do
        parseArguments "header" [RenameOption "camel-case" "foo"] (words "--foo bar")
          `shouldBe` Success (CamelCaseOptions "bar")
