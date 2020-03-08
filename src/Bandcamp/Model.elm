module Bandcamp.Model exposing (..)
import Dict
import Json.Decode as Decode
import Json.Encode as Encode
import RemoteData
import Time
import FileSystem
import Bandcamp.Id

initDownload = RequestingAssetUrl

waitingDownload = Downloading Waiting

initModel : Model
initModel =
    Model
        RemoteData.NotAsked
        Nothing
        Bandcamp.Id.emptyDict_


type alias Date = Time.Posix

encodeDate = Time.posixToMillis >> Encode.int
decodeDate = Decode.int |> Decode.map Time.millisToPosix

type alias RemoteLibrary =
    RemoteData.RemoteData String Library

decodeRemoteLibrary : Decode.Decoder RemoteLibrary
decodeRemoteLibrary =
        decodeMaybeLibrary
        |> Decode.map (RemoteData.fromMaybe "Stored library not found")

encodeRemoteLibrary : RemoteLibrary -> Encode.Value
encodeRemoteLibrary =
    RemoteData.toMaybe
    >> encodeMaybeLibrary

-- [generator-start]

type alias MaybeLibrary = Maybe Library
type alias Model =
    { library : RemoteLibrary
    , cookie : Maybe Cookie
    , downloads : Downloads
    }

type alias Library =
    { download_urls : Bandcamp.Id.Dict_ String
    , purchases : Bandcamp.Id.Dict_ Purchase
    }

type alias LoadedModel =
    { library : Library
    , cookie : Maybe Cookie
    }
type alias Purchase =
    { title: String
    , artist : String
    , artwork: Int
    , item_id : Bandcamp.Id.Id
    }
type Cookie = Cookie String

type alias Downloads = Bandcamp.Id.Dict_ Download

type Download =
    RequestingFormatUrl
    | RequestingAssetUrl
    | Downloading DownloadStatus
    | Unzipping
    | Scanning
    | Completed (List FileSystem.FileRef)
    | Error

type DownloadStatus = Waiting | InProgress DownloadProgress

{-| in pct -}
type alias DownloadProgress = Int


-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeCookie =
   Decode.map Cookie Decode.string

decodeDownload =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeDownloadHelp

decodeDownloadHelp constructor =
   case constructor of
      "RequestingFormatUrl" ->
         Decode.succeed RequestingFormatUrl
      "RequestingAssetUrl" ->
         Decode.succeed RequestingAssetUrl
      "Downloading" ->
         Decode.map
            Downloading
               ( Decode.field "A1" decodeDownloadStatus )
      "Unzipping" ->
         Decode.succeed Unzipping
      "Scanning" ->
         Decode.succeed Scanning
      "Completed" ->
         Decode.map
            Completed
               ( Decode.field "A1" (Decode.list FileSystem.decodeFileRef) )
      "Error" ->
         Decode.succeed Error
      other->
         Decode.fail <| "Unknown constructor for type Download: " ++ other

decodeDownloadProgress =
   Decode.int

decodeDownloadStatus =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeDownloadStatusHelp

decodeDownloadStatusHelp constructor =
   case constructor of
      "Waiting" ->
         Decode.succeed Waiting
      "InProgress" ->
         Decode.map
            InProgress
               ( Decode.field "A1" decodeDownloadProgress )
      other->
         Decode.fail <| "Unknown constructor for type DownloadStatus: " ++ other

decodeDownloads =
   Bandcamp.Id.decodeDict_ decodeDownload

decodeLibrary =
   Decode.map2
      Library
         ( Decode.field "download_urls" ((Bandcamp.Id.decodeDict_ Decode.string)) )
         ( Decode.field "purchases" ((Bandcamp.Id.decodeDict_ decodePurchase)) )

decodeLoadedModel =
   Decode.map2
      LoadedModel
         ( Decode.field "library" decodeLibrary )
         ( Decode.field "cookie" (Decode.maybe decodeCookie) )

decodeMaybeLibrary =
   Decode.maybe decodeLibrary

decodeModel =
   Decode.map3
      Model
         ( Decode.field "library" decodeRemoteLibrary )
         ( Decode.field "cookie" (Decode.maybe decodeCookie) )
         ( Decode.field "downloads" decodeDownloads )

decodePurchase =
   Decode.map4
      Purchase
         ( Decode.field "title" Decode.string )
         ( Decode.field "artist" Decode.string )
         ( Decode.field "artwork" Decode.int )
         ( Decode.field "item_id" Bandcamp.Id.decodeId )

encodeCookie (Cookie a1) =
   Encode.string a1

encodeDownload a =
   case a of
      RequestingFormatUrl ->
         Encode.object
            [ ("Constructor", Encode.string "RequestingFormatUrl")
            ]
      RequestingAssetUrl ->
         Encode.object
            [ ("Constructor", Encode.string "RequestingAssetUrl")
            ]
      Downloading a1->
         Encode.object
            [ ("Constructor", Encode.string "Downloading")
            , ("A1", encodeDownloadStatus a1)
            ]
      Unzipping ->
         Encode.object
            [ ("Constructor", Encode.string "Unzipping")
            ]
      Scanning ->
         Encode.object
            [ ("Constructor", Encode.string "Scanning")
            ]
      Completed a1->
         Encode.object
            [ ("Constructor", Encode.string "Completed")
            , ("A1", Encode.list FileSystem.encodeFileRef a1)
            ]
      Error ->
         Encode.object
            [ ("Constructor", Encode.string "Error")
            ]

encodeDownloadProgress a =
   Encode.int a

encodeDownloadStatus a =
   case a of
      Waiting ->
         Encode.object
            [ ("Constructor", Encode.string "Waiting")
            ]
      InProgress a1->
         Encode.object
            [ ("Constructor", Encode.string "InProgress")
            , ("A1", encodeDownloadProgress a1)
            ]

encodeDownloads a =
   Bandcamp.Id.encodeDict_ encodeDownload a

encodeLibrary a =
   Encode.object
      [ ("download_urls", ((Bandcamp.Id.encodeDict_ Encode.string)) a.download_urls)
      , ("purchases", ((Bandcamp.Id.encodeDict_ encodePurchase)) a.purchases)
      ]

encodeLoadedModel a =
   Encode.object
      [ ("library", encodeLibrary a.library)
      , ("cookie", encodeMaybeCookie a.cookie)
      ]

encodeMaybeCookie a =
   case a of
      Just b->
         encodeCookie b
      Nothing->
         Encode.null

encodeMaybeLibrary a =
   case a of
      Just b->
         encodeLibrary b
      Nothing->
         Encode.null

encodeModel a =
   Encode.object
      [ ("library", encodeRemoteLibrary a.library)
      , ("cookie", encodeMaybeCookie a.cookie)
      , ("downloads", encodeDownloads a.downloads)
      ]

encodePurchase a =
   Encode.object
      [ ("title", Encode.string a.title)
      , ("artist", Encode.string a.artist)
      , ("artwork", Encode.int a.artwork)
      , ("item_id", Bandcamp.Id.encodeId a.item_id)
      ] 
-- [generator-end]
