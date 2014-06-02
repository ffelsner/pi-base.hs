module Form.Traits
( createTraitForm
, updateTraitForm
) where

import Import
import Form

import Control.Applicative ((<*))
import Data.Time (getCurrentTime)
import Yesod.Form.Bootstrap3

createTraitForm :: Html -> MForm Handler (FormResult Trait, Widget)
createTraitForm = renderBootstrap3 fLayout $ Trait
  <$> areq spaceField    (fs "Space")       Nothing
  <*> areq propertyField (fs "Property")    Nothing
  <*> areq valueField    (fs "Value")       Nothing
  <*> areq textField     (fs "Description") Nothing
  <*> lift (liftIO getCurrentTime)
  <*> lift (liftIO getCurrentTime)
  <*> pure False
  <*  bootstrapSubmit ("Save" :: BootstrapSubmit Text)

updateTraitForm :: Trait -> Html -> MForm Handler (FormResult Trait, Widget)
updateTraitForm t = renderBootstrap3 fLayout $ Trait
  <$> pure (traitSpaceId t)
  <*> pure (traitPropertyId t)
  <*> pure (traitValueId t)
  <*> areq textField (fs "Description") (Just $ traitDescription t)
  <*> pure (traitCreatedAt t)
  <*> lift (liftIO getCurrentTime)
  <*> pure (traitDeduced t)
  <* bootstrapSubmit ("Save" :: BootstrapSubmit Text)
