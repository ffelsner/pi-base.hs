{-# LANGUAGE OverloadedStrings #-}

import Base

import Database.Persist
import Database.Persist.Sql        (rawExecute)
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Network.Wai                 (Application)
import Test.Hspec
import Test.Hspec.Wai

import Control.Concurrent.MVar (newMVar)

import Config (mkPool)
import Api    (mkApp)
import Models (doMigrations)
import qualified Universe as U

import Spec.Action (actionSpecs)
import Spec.App    (appSpecs)
import Spec.Logic  (logicSpecs)

config :: IO Config
config = do
  tu   <- newMVar $ U.empty
  pool <- mkPool Test

  return $ Config
    { getEnv  = Test
    , getPool = pool
    , getUVar = tu
    }

app :: IO Application
app = do
  c <- config
  return $ mkApp c

reset :: ConnectionPool -> IO ()
reset = runSqlPool $ do
  rawExecute "truncate table spaces cascade" []
  _ <- insertUnique $ User "test@example.com" (Just "James") True Nothing Nothing
  return ()

allSpecs :: Spec
allSpecs = do
  logicSpecs

  c <- runIO $ config
  let pool = getPool c
  runIO $ runSqlPool doMigrations pool


  before (reset pool) $ do
    it "resets between specs" $ do
      n <- flip runSqlPool pool $ count ([] :: [Filter Space])
      n `shouldBe` (0 :: Int)

    with app $ appSpecs

    actionSpecs c

main :: IO ()
main = hspec allSpecs
