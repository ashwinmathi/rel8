{-# language BlockArguments #-}
{-# language DataKinds #-}
{-# language FlexibleContexts #-}
{-# language GADTs #-}
{-# language NamedFieldPuns #-}
{-# language ScopedTypeVariables #-}
{-# language TypeApplications #-}

module Rel8.Table.Opaleye ( unpackspec, binaryspec, distinctspec, valuesspec ) where

-- rel8
import qualified Opaleye.Internal.Aggregate as Opaleye
import qualified Opaleye.Internal.Binary as Opaleye
import qualified Opaleye.Internal.Distinct as Opaleye
import qualified Opaleye.Internal.HaskellDB.PrimQuery as Opaleye
import qualified Opaleye.Internal.PackMap as Opaleye
import qualified Opaleye.Internal.Unpackspec as Opaleye
import qualified Opaleye.Internal.Values as Opaleye
import Rel8.Context ( Context( Column ), Meta( Meta ) )
import Rel8.DatabaseType ( DatabaseType( DatabaseType, typeName ) )
import Rel8.Expr ( Column( ExprColumn ), Expr, fromExprColumn, fromPrimExpr, toPrimExpr, traversePrimExpr, unsafeCastExpr )
import Rel8.HTable ( HTable, HField, hfield, hdbtype, htabulateMeta, htraverseMeta )
import Rel8.Info ( Info( Null, NotNull ), fromInfoColumn )
import Rel8.Table ( Table( toColumns, fromColumns ) )
import Rel8.Table.Congruent ( traverseTable, zipTablesWithM )


unpackspec :: Table Expr row => Opaleye.Unpackspec row row
unpackspec =
  Opaleye.Unpackspec $ Opaleye.PackMap \f ->
    fmap fromColumns . htraverseMeta (fmap ExprColumn . traversePrimExpr f . fromExprColumn) . addCasts . toColumns
  where
    addCasts :: forall f. HTable f => f (Column Expr) -> f (Column Expr)
    addCasts columns = htabulateMeta go
      where
        go :: forall x. HField f ('Meta x) -> Column Expr ('Meta x)
        go i = ExprColumn $ case fromInfoColumn (hfield hdbtype i) of
          NotNull t -> unsafeCastExpr (typeName t) (fromExprColumn (hfield columns i))
          Null t -> unsafeCastExpr (typeName t) (fromExprColumn (hfield columns i))


binaryspec :: Table Expr a => Opaleye.Binaryspec a a
binaryspec =
  Opaleye.Binaryspec $ Opaleye.PackMap \f (a, b) ->
    zipTablesWithM (\x y -> ExprColumn . fromPrimExpr <$> f (toPrimExpr (fromExprColumn x), toPrimExpr (fromExprColumn y))) a b


distinctspec :: Table Expr a => Opaleye.Distinctspec a a
distinctspec =
  Opaleye.Distinctspec $ Opaleye.Aggregator $ Opaleye.PackMap \f ->
    traverseTable (\x -> ExprColumn . fromPrimExpr <$> f (Nothing, toPrimExpr (fromExprColumn x)))


valuesspec :: forall expr. Table Expr expr => Opaleye.Valuesspec expr expr
valuesspec = Opaleye.ValuesspecSafe packmap unpackspec
  where
    packmap :: Opaleye.PackMap Opaleye.PrimExpr Opaleye.PrimExpr () expr
    packmap = Opaleye.PackMap \f () ->
      fmap fromColumns $
        htraverseMeta (fmap ExprColumn . traversePrimExpr f . fromExprColumn) $
          htabulateMeta \i ->
            case fromInfoColumn (hfield hdbtype i) of
              NotNull databaseType -> ExprColumn $ fromPrimExpr $ nullPrimExpr databaseType
              Null databaseType -> ExprColumn $ fromPrimExpr $ nullPrimExpr databaseType
        where
          nullPrimExpr :: DatabaseType a -> Opaleye.PrimExpr
          nullPrimExpr DatabaseType{ typeName } =
            Opaleye.CastExpr typeName (Opaleye.ConstExpr Opaleye.NullLit)
