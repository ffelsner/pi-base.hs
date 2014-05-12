{-# OPTIONS_GHC -fno-warn-orphans #-}
module Application
    ( makeApplication
    , getApplicationDev
    , makeFoundation
    ) where

import Import
import Settings
import Yesod.Auth
import Yesod.Default.Config
import Yesod.Default.Main
import Yesod.Default.Handlers
import Network.Wai.Middleware.RequestLogger
    ( mkRequestLogger, outputFormat, OutputFormat (..), IPAddrSource (..), destination
    )
import qualified Network.Wai.Middleware.RequestLogger as RequestLogger
import qualified Database.Persist
-- import Database.Persist.Sql (runMigration)
import Network.HTTP.Client.Conduit (newManager)
-- import Control.Monad.Logger (runLoggingT)
import Control.Concurrent (forkIO, threadDelay)
import System.Log.FastLogger (newStdoutLoggerSet, defaultBufSize, flushLogStr)
import Network.HTTP.Types.Header (ResponseHeaders)
import Network.Wai (Middleware)
import Network.Wai.Internal (Response(..))
import Network.Wai.Logger (clockDateCacher)
import Data.Default (def)
import Yesod.Core.Types (loggerSet, Logger (Logger))

-- Import all relevant handler modules here.
-- Don't forget to add new modules to your cabal file!
import Handler.Home
import Handler.Properties
import Handler.Search
import Handler.Spaces
import Handler.Theorems
import Handler.Traits

import qualified Data.HashMap.Strict as M
import qualified Data.Aeson.Types as AT
#ifndef DEVELOPMENT
import qualified Web.Heroku
#endif

-- This line actually creates our YesodDispatch instance. It is the second half
-- of the call to mkYesodData which occurs in Foundation.hs. Please see the
-- comments there for more details.
mkYesodDispatch "App" resourcesApp


addHeaders :: ResponseHeaders -> Middleware
addHeaders hs app env = do
    res <- app env
    return $ case res of
        ResponseFile s rhs f mfp -> ResponseFile s (fix rhs) f mfp
        ResponseBuilder s rhs b -> ResponseBuilder s (fix rhs) b
        ResponseSource s rhs src -> ResponseSource s (fix rhs) src
        r -> r
  where fix rhs = rhs ++ hs

cors :: Middleware
cors = addHeaders [("Access-Control-Allow-Origin", "http://localhost:8000")]


-- This function allocates resources (such as a database connection pool),
-- performs initialization and creates a WAI application. This is also the
-- place to put your migrate statements to have automatic database
-- migrations handled by Yesod.
makeApplication :: AppConfig DefaultEnv Extra -> IO (Application, LogFunc)
makeApplication conf = do
    foundation <- makeFoundation conf

    -- Initialize the logging middleware
    logWare <- mkRequestLogger def
        { outputFormat =
            if development
                then Detailed True
                else Apache FromSocket
        , destination = RequestLogger.Logger $ loggerSet $ appLogger foundation
        }

    -- Create the WAI application and apply middlewares
    app <- toWaiAppPlain foundation
    let logFunc = messageLoggerSource foundation (appLogger foundation)
    return (cors . logWare $ defaultMiddlewaresNoLogging app, logFunc)


#ifndef DEVELOPMENT
canonicalizeKey :: (Text, val) -> (Text, val)
canonicalizeKey ("dbname", val) = ("database", val)
canonicalizeKey pair = pair

toMapping :: [(Text, Text)] -> AT.Value
toMapping xs = AT.Object $ M.fromList $ map (\(key, val) -> (key, AT.String val)) xs
#endif

combineMappings :: AT.Value -> AT.Value -> AT.Value
combineMappings (AT.Object m1) (AT.Object m2) = AT.Object $ m1 `M.union` m2
combineMappings _ _ = error "Data.Object is not a Mapping."

loadHerokuConfig :: IO AT.Value
loadHerokuConfig = do
#ifdef DEVELOPMENT
    return $ AT.Object M.empty
#else
    Web.Heroku.dbConnParams >>= return . toMapping . map canonicalizeKey
#endif

-- | Loads up any necessary settings, creates your foundation datatype, and
-- performs some initialization.
makeFoundation :: AppConfig DefaultEnv Extra -> IO App
makeFoundation conf = do
    manager <- newManager
    s <- staticSite
    hconfig <- loadHerokuConfig
    dbconf <- withYamlEnvironment "config/postgresql.yml" (appEnv conf)
              (Database.Persist.loadConfig . combineMappings hconfig) >>=
              Database.Persist.applyEnv
    p <- Database.Persist.createPoolConfig (dbconf :: Settings.PersistConf)

    loggerSet' <- newStdoutLoggerSet defaultBufSize
    (getter, updater) <- clockDateCacher

    -- If the Yesod logger (as opposed to the request logger middleware) is
    -- used less than once a second on average, you may prefer to omit this
    -- thread and use "(updater >> getter)" in place of "getter" below.  That
    -- would update the cache every time it is used, instead of every second.
    let updateLoop = do
            threadDelay 1000000
            updater
            flushLogStr loggerSet'
            updateLoop
    _ <- forkIO updateLoop

    let logger = Yesod.Core.Types.Logger loggerSet' getter
        foundation = App conf s p manager dbconf logger

    -- Perform database migration using our application's logging settings.
    -- runLoggingT
    --     (Database.Persist.runPool dbconf (runMigration migrateAll) p)
    --     (messageLoggerSource foundation logger)

    return foundation

-- for yesod devel
getApplicationDev :: IO (Int, Application)
getApplicationDev =
    defaultDevelApp loader (fmap fst . makeApplication)
  where
    loader = Yesod.Default.Config.loadConfig (configSettings Development)
        { csParseExtra = parseExtra
        }
