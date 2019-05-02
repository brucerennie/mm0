module MMTypes where

import Control.Monad.Trans.State
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.Sequence as Q
import Environment (SortData, SExpr)

type Const = String
type Var = String
type Sort = String
type Label = String
type MMExpr = SExpr

data Hyp = VHyp Const Var | EHyp Const MMExpr deriving (Show)

type DVs = S.Set (Var, Var)
type Frame = ([(Bool, Label)], DVs)
data Proof = PHyp Label Int | PDummy Int | PBackref Int
  | PSorry | PSave Proof | PTerm Label [Proof] | PThm Label [Proof] deriving (Show)

data Stmt = Hyp Hyp
  | Term Frame Const MMExpr (Maybe ([Label], Proof))
  | Thm Frame Const MMExpr (Maybe ([Label], Proof))
  deriving (Show)

type Scope = [([(Label, Hyp)], [[Var]], S.Set Var)]

data Decl = Sort Sort | Stmt Label deriving (Show)

data MMDatabase = MMDatabase {
  mSorts :: M.Map Sort (Maybe Sort, SortData),
  mDecls :: Q.Seq Decl,
  mPrim :: S.Set Label,
  mStmts :: M.Map Label Stmt,
  mScope :: Scope } deriving (Show)

mkDatabase :: MMDatabase
mkDatabase = MMDatabase M.empty Q.empty S.empty M.empty [([], [], S.empty)]

memDVs :: DVs -> Var -> Var -> Bool
memDVs d v1 v2 = S.member (if v1 < v2 then (v1, v2) else (v2, v1)) d

unsave :: Proof -> (Proof, Q.Seq Proof)
unsave = \p -> runState (go p) Q.empty where
  go :: Proof -> State (Q.Seq Proof) Proof
  go (PTerm t ps) = PTerm t <$> mapM go ps
  go (PThm t ps) = PThm t <$> mapM go ps
  go (PSave p) = do
    p' <- go p
    state $ \heap -> (PBackref (Q.length heap), heap Q.|> p')
  go p = return p
