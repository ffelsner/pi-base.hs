module Handler.Spaces where

import Import

import Handler.Resource

getSpacesR :: Handler Html
getSpacesR = do
  spaces <- page 0 10
  defaultLayout $(widgetFile "spaces/index")

getSpaceR :: SpaceId -> Handler Html
getSpaceR _id = do
  space <- runDB $ get404 _id
  defaultLayout $(widgetFile "spaces/show")
