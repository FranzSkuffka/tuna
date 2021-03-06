module Msg exposing (..)
import Model exposing (..)
import DropZone exposing (..)
import Model exposing (..)
import Bandcamp

import Json.Decode as Decode
import FileSystem
import Player
import Syncer


import InfiniteList
import Track

import MultiInput

-- UPDATE


type Msg
  = DropZoneMsg (DropZone.DropZoneMessage DropPayload)
  | FilesFound (List String)
  | FilesRead (Result Decode.Error (List FileSystem.ReadResult))
  | PlayerMsg Player.Msg

  | BandcampMsg Bandcamp.Msg

  | TabClicked Model.Tab

  | TagChanged Track.Id String

  | UrlRequested
  | UrlChanged

  | InfiniteListMsg InfiniteList.Model

  | SetQuickTag MultiInput.Msg
  | SetFilter (Maybe String)
  | SyncerMsg Syncer.Msg
