{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}

module System.Console.Args.Generics (withArguments) where

import Generics.SOP
import Options.Applicative

withArguments :: (Generic a, HasDatatypeInfo a, All2 ToOption (Code a)) =>
  (a -> IO ()) -> IO ()
withArguments action = execParser opts >>= action
  where
    opts = info parser fullDesc

parser :: forall a . (Generic a, HasDatatypeInfo a, All2 ToOption (Code a)) =>
       Parser a
parser = case datatypeInfo (Proxy :: Proxy a) of
    ADT _ _ cs -> to <$> SOP <$> parser' cs
    Newtype _ _ c -> to <$> SOP <$> parser' (c :* Nil)
  where
    parser' :: NP ConstructorInfo (Code a) -> Parser (NS (NP I) (Code a))
    parser' (Record _ fields :* Nil) = Z <$> parser'' fields
    parser' _cs = undefined

    parser'' :: (All ToOption xs) => NP FieldInfo xs -> Parser (NP I xs)
    parser'' Nil = pure Nil
    parser'' (field :* r) =
      (:*) <$> (I <$> goField field) <*> (parser'' r)

goField :: (ToOption a) => FieldInfo a -> Parser a
goField (FieldInfo field) = toOpt field

class ToOption a where
  toOpt :: String -> Parser a

instance ToOption String where
  toOpt name = strOption (long name)

instance ToOption Bool where
  toOpt name = switch (long name)

instance ToOption Int where
  toOpt name = option auto (long name)

instance ToOption a => ToOption (Maybe a) where
  toOpt name = optional (toOpt name)