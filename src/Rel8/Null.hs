{-# language BlockArguments #-}
{-# language ScopedTypeVariables #-}
{-# language TypeApplications #-}
{-# language TypeFamilies #-}

module Rel8.Null where

import Control.Monad.Trans.Reader ( ReaderT(..) )
import Data.Functor.Compose ( Compose(..) )
import Data.Functor.Contravariant ( Op(..) )
import Data.Functor.Identity ( Identity(..) )
import Data.Indexed.Functor ( hmap )
import Data.Indexed.Functor.Compose ( HCompose(..) )
import Data.Indexed.Functor.Representable ( HRepresentable(..) )
import Data.Indexed.Functor.Traversable ( HTraversable(..) )
import Data.Tagged.PolyKinded ( Tagged(..) )
import qualified Opaleye.Internal.HaskellDB.PrimQuery as O
import Rel8.Table


data Null a = Null (Maybe a)
  deriving (Show)


instance Table a => Table (Null a) where
  type Schema (Null a) =
    Compose (Tagged (Null a)) (HCompose (Schema a) Null)

  from (Null (Just x)) = Compose $ Tagged $ HCompose $ hmap (\(Identity y) -> Compose $ Identity $ Null $ Just y) (from x)
  from (Null Nothing) = Compose $ Tagged $ HCompose $ htabulate \_ -> Compose $ Identity $ Null Nothing

  to (Compose (Tagged (HCompose x))) =
    Null $ to <$> htraverse (\(Compose (Identity (Null y))) -> Identity <$> y) x

  encode =
    Compose $ Tagged $ HCompose $ hmap (\(Op f) -> Compose $ Op \(Null x) -> maybe (O.ConstExpr O.NullLit) f x) $ encode @a

  decode = Compose $ Tagged $ HCompose $ hmap (\f -> Compose (nullIsNothing f)) $ decode @a
    where
      nullIsNothing parser = ReaderT \field -> ReaderT (maybe (pure (Null Nothing)) (runReaderT (runReaderT (Null . Just <$> parser) field) . Just))
