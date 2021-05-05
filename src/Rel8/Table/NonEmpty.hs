{-# language FlexibleContexts #-}
{-# language FlexibleInstances #-}
{-# language MultiParamTypeClasses #-}
{-# language NamedFieldPuns #-}
{-# language ScopedTypeVariables #-}
{-# language StandaloneKindSignatures #-}
{-# language TypeApplications #-}
{-# language TypeFamilies #-}
{-# language UndecidableInstances #-}

module Rel8.Table.NonEmpty
  ( NonEmptyTable(..)
  , nonEmptyTable, insertNonEmptyTable, nameNonEmptyTable
  )
where

-- base
import Data.Functor.Identity ( Identity( Identity ) )
import Data.Kind ( Type )
import Data.List.NonEmpty ( NonEmpty )
import Data.Type.Equality ( (:~:)( Refl ) )
import Prelude

-- rel8
import Rel8.Expr ( Expr, Col(..) )
import Rel8.Expr.Array ( sappend1, snonEmptyOf )
import Rel8.Kind.Necessity ( SNecessity( SOptional, SRequired ) )
import Rel8.Schema.Dict ( Dict( Dict ) )
import Rel8.Schema.HTable.NonEmpty ( HNonEmptyTable )
import Rel8.Schema.HTable.Vectorize ( happend, hvectorize )
import Rel8.Schema.Insert ( Col( OptionalInsert, RequiredInsert ), Insert )
import Rel8.Schema.Name ( Col( NameCol ), Name )
import Rel8.Schema.Null ( Nullity( Null, NotNull ) )
import Rel8.Schema.Reify ( hreify, hunreify )
import Rel8.Schema.Spec ( SSpec(..) )
import Rel8.Schema.Spec.ConstrainDBType ( dbTypeDict, dbTypeNullity )
import Rel8.Table
  ( Table, Context, Columns, fromColumns, toColumns
  , reify, unreify
  )
import Rel8.Table.Alternative ( AltTable, (<|>:) )
import Rel8.Table.Eq ( EqTable, eqTable )
import Rel8.Table.Ord ( OrdTable, ordTable )
import Rel8.Table.Recontextualize ( Recontextualize )
import Rel8.Table.Serialize ( FromExprs, ToExprs, fromResult, toResult )
import Rel8.Table.Unreify ( Unreifies )


-- | A @NonEmptyTable@ value contains one or more instances of @a@. You
-- construct @NonEmptyTable@s with 'Rel8.some' or 'nonEmptyAgg'.
type NonEmptyTable :: Type -> Type
newtype NonEmptyTable a =
  NonEmptyTable (HNonEmptyTable (Columns a) (Col (Context a)))


instance (Table context a, Unreifies context a) =>
  Table context (NonEmptyTable a)
 where
  type Columns (NonEmptyTable a) = HNonEmptyTable (Columns a)
  type Context (NonEmptyTable a) = Context a

  fromColumns = NonEmptyTable
  toColumns (NonEmptyTable a) = a

  reify Refl (NonEmptyTable a) = NonEmptyTable (hreify a)
  unreify Refl (NonEmptyTable a) = NonEmptyTable (hunreify a)


instance
  ( Unreifies from a, Unreifies to b
  , Recontextualize from to a b
  )
  => Recontextualize from to (NonEmptyTable a) (NonEmptyTable b)


instance EqTable a => EqTable (NonEmptyTable a) where
  eqTable =
    hvectorize
      (\SSpec {} (Identity dict) -> case dbTypeDict dict of
          Dict -> case dbTypeNullity dict of
            Null -> Dict
            NotNull -> Dict)
      (Identity (eqTable @a))


instance OrdTable a => OrdTable (NonEmptyTable a) where
  ordTable =
    hvectorize
      (\SSpec {} (Identity dict) -> case dbTypeDict dict of
          Dict -> case dbTypeNullity dict of
            Null -> Dict
            NotNull -> Dict)
      (Identity (ordTable @a))


type instance FromExprs (NonEmptyTable a) = NonEmpty (FromExprs a)


instance ToExprs exprs a => ToExprs (NonEmptyTable exprs) (NonEmpty a)
 where
  fromResult = fmap (fromResult @exprs) . fromColumns
  toResult = toColumns . fmap (toResult @exprs)


instance AltTable NonEmptyTable where
  (<|>:) = (<>)


instance Table Expr a => Semigroup (NonEmptyTable a) where
  NonEmptyTable as <> NonEmptyTable bs = NonEmptyTable $
    happend (\_ _ (DB a) (DB b) -> DB (sappend1 a b)) as bs


nonEmptyTable :: Table Expr a => NonEmpty a -> NonEmptyTable a
nonEmptyTable =
  NonEmptyTable .
  hvectorize (\SSpec {info} -> DB . snonEmptyOf info . fmap unDB) .
  fmap toColumns


insertNonEmptyTable :: Table Insert a => NonEmpty a -> NonEmptyTable a
insertNonEmptyTable =
  NonEmptyTable .
  hvectorize (\SSpec {necessity, info} -> case necessity of
    SRequired -> RequiredInsert . snonEmptyOf info . fmap (\(RequiredInsert a) -> a)
    SOptional -> OptionalInsert . fmap (snonEmptyOf info) . traverse (\(OptionalInsert a) -> a)) .
  fmap toColumns


nameNonEmptyTable :: Table Name a => a -> NonEmptyTable a
nameNonEmptyTable =
  NonEmptyTable .
  hvectorize (\_ (Identity (NameCol a)) -> NameCol a) .
  pure .
  toColumns
