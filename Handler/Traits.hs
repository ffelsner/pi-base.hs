module Handler.Traits where

import Import

import DB (derivedTraits)
import Explore (checkTrait, checkSpace)
import Form.Traits
import Handler.Partials (traitName, linkedTraitName, theoremName, revisionList)
import Handler.Helpers
import Models

-- FIXME
queueCheckTrait :: TraitId -> Handler ()
queueCheckTrait _id = do
  _ <- checkTrait "queueCheckTrait" _id
  return ()

-- FIXME
traitTitle :: Trait -> Text
traitTitle _ = "Trait"


getTraitsR :: Handler Html
getTraitsR = do
  (traits, pageWidget) <- page 10
  total <- runDB $ count ([] :: [Filter Trait])
  render "Traits" $(widgetFile "traits/index")

getCreateTraitR :: Handler Html
getCreateTraitR = do
  (widget, enctype) <- generateFormPost createTraitForm
  render "New Trait" $(widgetFile "traits/new")

postCreateTraitR :: Handler Html
postCreateTraitR = do
  ((result, widget), enctype) <- runFormPost createTraitForm
  case result of
    FormSuccess trait -> do
      existing <- runDB . getBy $ TraitSP (traitSpaceId trait) (traitPropertyId trait)
      case existing of
        Just (Entity _id _) -> do
          setMessage "Trait already exists"
          redirect $ TraitR _id
        Nothing -> do
          _id <- runDB $ insert trait
          _ <- revisionCreate $ Entity _id trait
          queueCheckTrait _id
          setMessage "Created trait"
          redirect $ TraitR _id
    _ -> render "New Trait" $(widgetFile "traits/new")

getEditTraitR :: TraitId -> Handler Html
getEditTraitR _id = do
  trait <- runDB $ get404 _id
  (widget, enctype) <- generateFormPost $ updateTraitForm trait
  render ("Edit " <> traitTitle trait) $(widgetFile "traits/edit")

postTraitR :: TraitId -> Handler Html
postTraitR _id = do
  trait <- runDB $ get404 _id
  ((result, widget), enctype) <- runFormPost $ updateTraitForm trait
  case result of
    FormSuccess updated -> do
      runDB $ replace _id updated
      _ <- revisionCreate $ Entity _id updated
      setMessage "Updated trait"
      redirect $ TraitR _id
    _ -> render ("Edit " <> traitTitle trait) $(widgetFile "traits/edit")

getTraitR :: TraitId -> Handler Html
getTraitR _id = do
  trait <- runDB $ get404 _id
  case traitDeduced trait of
    True -> do
      (Entity proofId proof) <- runDB . getBy404 $ UProofTrait _id
      assumedTraits  <- proofTraits  proofId
      assumedTheorem <- proofTheorem proof
      derived        <- derivedTraits _id
      render (traitTitle trait) $(widgetFile "traits/show_deduced")
    False -> do
      consequences <- traitConsequences _id
      render (traitTitle trait) $(widgetFile "traits/show")

getDeleteTraitR :: TraitId -> Handler Html
getDeleteTraitR _id = do
  trait <- runDB $ get404 _id
  consequences <- traitConsequences _id
  render ("Delete " <> traitTitle trait) $(widgetFile "traits/delete")

postDeleteTraitR :: TraitId -> Handler Html
postDeleteTraitR _id = do
  trait <- runDB $ get404 _id
  if traitDeduced trait
    then invalidArgs ["Please delete the root assumption for this trait"]
    else do
      _ <- traitDelete _id
      _ <- checkSpace "postDeleteTraitR" (traitSpaceId trait)
      setMessage "Deleted trait" -- TODO: show deleted / re-added counts
      redirect TraitsR

getTraitRevisionsR :: TraitId -> Handler Html
getTraitRevisionsR _id = do
  trait <- runDB $ get404 _id
  render (traitTitle trait <> " Revisions") $(widgetFile "traits/revisions")
