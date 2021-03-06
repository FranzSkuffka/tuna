port module Bandcamp exposing (..)

import Element
import Html.Events
import Json.Decode as Decode

import Html
import RemoteData

import Dict
import Element.Input
import Element.Font


import Bandcamp.Downloader
import Bandcamp.Model

import Bandcamp.Id
import RemoteData
import Track
import Bandcamp.SimpleDownloader

subscriptions : Bandcamp.Model.Model -> Sub Msg
subscriptions model =
    let
        captureBandcampLib val =
            val
            |> Decode.decodeValue extractModelFromBlob
            |> DataRetrieved
    in
        Sub.batch [
            bandcamp_in_connection_opened captureBandcampLib
          , Bandcamp.Downloader.subscriptions model.downloads
            |> Sub.map DownloaderMsg
          , Bandcamp.SimpleDownloader.subscriptions
            |> Sub.map SimpleDownloaderMsg
        ]

port bandcamp_out_connection_requested : String -> Cmd msg
port bandcamp_in_connection_opened : (Decode.Value -> msg) -> Sub msg

type Msg =
    CookieRetrieved Bandcamp.Model.Cookie
  | DataRetrieved (Result Decode.Error Bandcamp.Model.Library)
  | DownloaderMsg Bandcamp.Downloader.Msg
  | SimpleDownloaderMsg Bandcamp.SimpleDownloader.Msg
  | RefreshRequested

browser : Bandcamp.Model.Model -> Element.Element Msg
browser model =
    let
        refreshButton = Element.Input.button [] {onPress = Just RefreshRequested, label = Element.text "refresh"}
        loading =
            Element.paragraph
                [Element.padding 50, Element.Font.center]
                [Element.text "Loading..."]

        viewLib : Bandcamp.Model.Library -> Element.Element Msg
        viewLib lib =
            let
                attribs =
                    [ Element.height Element.fill
                    , Element.width Element.fill
                    , Element.clipY
                    , Element.scrollbarY
                    , Element.spacing 50
                    , Element.padding 50
                    ]
                content =
                    Bandcamp.Id.dictToList lib.purchases
                    |> List.map (viewPurchase model.downloads lib)
            in
                Element.wrappedRow attribs content

    in case model.cookie of
        Nothing -> authElement
        Just _ -> case model.library of
            RemoteData.NotAsked -> loading
            RemoteData.Failure e -> Element.text e
            RemoteData.Loading -> loading
            RemoteData.Success library ->
                Element.column [Element.height Element.fill, Element.spacing 10, Element.clip, Element.scrollbarY] [refreshButton, viewLib library]


viewPurchase : Bandcamp.Model.Downloads -> Bandcamp.Model.Library -> (Bandcamp.Id.Id, Bandcamp.Model.Purchase) -> Element.Element Msg
viewPurchase downloads library (_, {title, artist, artwork, item_id, sale_item_id}) =
    let
        imgSrc =
            "https://f4.bcbits.com/img/a"
            ++ (String.fromInt artwork)
            ++ "_16.jpg"
        viewInfo =
            Element.column
                [ Element.spacing 10 ]
                [ Element.paragraph [] [Element.text title]
                , Element.paragraph [] [Element.text artist]
                ]

        viewArtwork =
            Element.image
                [Element.height (Element.px 300), Element.width (Element.px 300)]
                {src = imgSrc, description = title}

        downloadUrl : Maybe String
        downloadUrl = Maybe.andThen(\s_id -> Bandcamp.Id.getBy s_id library.download_urls) sale_item_id
        viewDownloadOptions = case downloadUrl  of
            Just u ->
                Bandcamp.Downloader.viewDownloadButton
                    downloads library
                    item_id
            Nothing ->
                Element.text "no download available"
    in
    Element.column
        [Element.width (Element.px 300), Element.spacing 10]
        [
            viewArtwork
          , viewInfo
          , viewDownloadOptions
        ]
        |> Element.map DownloaderMsg

initCmd : Bandcamp.Model.Model -> Cmd Msg
initCmd model =
    case (model.cookie, model.library) of
        (Just (Bandcamp.Model.Cookie cookie), RemoteData.NotAsked ) -> fetchLatestLibrary cookie
        (Just (Bandcamp.Model.Cookie cookie), RemoteData.Failure f ) -> fetchLatestLibrary cookie
        _ -> Cmd.none

fetchLatestLibrary : String -> Cmd Msg
fetchLatestLibrary cookie =
    bandcamp_out_connection_requested cookie

matchType : String -> Decode.Decoder Bandcamp.Model.PurchaseType
matchType typeHint =
    case typeHint of
        "a" -> Decode.succeed Bandcamp.Model.Album
        "t" -> Decode.succeed Bandcamp.Model.Track
        _ -> Decode.fail <| "Could not match item type " ++ typeHint

decodeTrackInfos : Decode.Decoder (List Bandcamp.Model.TrackInfo)
decodeTrackInfos =
    Decode.field "tracks" <| Decode.list decodeTrackInfo

decodeTrackInfo : Decode.Decoder Bandcamp.Model.TrackInfo
decodeTrackInfo =
    Decode.map4 Bandcamp.Model.TrackInfo
        (Decode.field "title" Decode.string)
        (Decode.field "artist" Decode.string)
        decodeStreamUrl
        (Decode.field "id" Decode.int |> Decode.map String.fromInt)

{-| The stream URL might be mp3-v0 or mp3-320 -}
decodeStreamUrl : Decode.Decoder String
decodeStreamUrl =
    Decode.field "file" <| Decode.oneOf [Decode.field "mp3-128" Decode.string, Decode.field "mp3-v0" Decode.string]
extractModelFromBlob : Decode.Decoder Bandcamp.Model.Library
extractModelFromBlob =
    let
        extractPurchases : Decode.Decoder (List Bandcamp.Model.Purchase)
        extractPurchases =
            Decode.at ["items"] (Decode.list extractPurchase)

        extractPurchase : Decode.Decoder Bandcamp.Model.Purchase
        extractPurchase =
            Decode.map7 Bandcamp.Model.Purchase
                (Decode.field "item_title" Decode.string)
                (Decode.field "band_name" Decode.string)
                (Decode.field "item_art_id" Decode.int)
                (Decode.field "item_id" Decode.int |> Decode.map Bandcamp.Id.fromPort)
                (Decode.field "sale_item_id" (Decode.maybe Decode.int |> Decode.map (Maybe.map Bandcamp.Id.fromPort)))
                (Decode.field "tralbum_type" (Decode.string |> Decode.andThen matchType))
                (decodeTrackInfos)

        item_id_as_key : List Bandcamp.Model.Purchase -> Bandcamp.Id.Dict_ Bandcamp.Model.Purchase
        item_id_as_key =
            List.map (\item -> (Bandcamp.Id.toPort item.item_id, item))
            >> Dict.fromList
            >> Bandcamp.Id.wrapDict_

        purchase_id_to_item_id : Dict.Dict String String -> Bandcamp.Id.Dict_ String
        purchase_id_to_item_id =
            Dict.toList
            >> List.filterMap (\(id, download) -> case Bandcamp.Id.parsePurchaseId id of
                    Just item_id -> Just (Bandcamp.Id.toPort item_id, download)
                    Nothing -> Nothing
                )
            >> Dict.fromList
            >> Bandcamp.Id.wrapDict_
        extractDownloadUrls : Decode.Decoder (Dict.Dict String String)
        extractDownloadUrls =
            Decode.at
                ["redownload_urls"]
                (Decode.dict Decode.string)
    in
        Decode.map2
            Bandcamp.Model.Library
            (extractDownloadUrls |> Decode.map purchase_id_to_item_id)
            (extractPurchases  |> Decode.map item_id_as_key )


{-| Launch bandcamp/login inside an iframe and extract the cookie when the user was authed successfully -}
authElement : Element.Element Msg
authElement =
    let
        parseCookie : String -> Decode.Decoder Msg
        parseCookie cookieString =
            if String.isEmpty cookieString
                then Decode.fail "cookie can not be an empty string"
                else Decode.succeed (CookieRetrieved <| Bandcamp.Model.Cookie cookieString)

        listener = Html.Events.on "cookieretrieve" readCookie
        readCookie =
            Decode.at ["detail", "cookie"] Decode.string
            |> Decode.andThen parseCookie
    in
        Element.html (Html.node "bandcamp-auth" [listener] [])

update : Msg -> Bandcamp.Model.Model -> (Bandcamp.Model.Model, Cmd Msg)
update msg model =
    case msg of
        RefreshRequested ->
            (model, case model.cookie of
                Nothing -> Cmd.none
                Just (Bandcamp.Model.Cookie cookie) -> bandcamp_out_connection_requested(cookie)
            )
        CookieRetrieved (Bandcamp.Model.Cookie c) ->
            ({model | cookie = Just (Bandcamp.Model.Cookie c)}
            , fetchLatestLibrary c)
        DataRetrieved res ->
            case res of
                Ok newLibrary ->
                    ({model | library = RemoteData.succeed newLibrary}
                    , Cmd.none
                    )
                Err e ->
                        (model, Cmd.none)

        DownloaderMsg msg_ ->
            let
                (mdl, cmd) = Bandcamp.Downloader.update msg_ model
            in
                ( mdl
                , Cmd.map DownloaderMsg cmd
                )

        SimpleDownloaderMsg msg_ ->
            let
                (simpleDownloads, cmd) = Bandcamp.SimpleDownloader.update msg_ model.simpleDownloads
            in
                ( {model | simpleDownloads = simpleDownloads}
                , Cmd.map SimpleDownloaderMsg cmd
                )

extractTracksFromPurchase : (Bandcamp.Id.Id, Bandcamp.Model.Purchase) -> Track.Tracks
extractTracksFromPurchase (id, purchase) =
    purchase.tracks
    |> List.indexedMap (trackInfoToTrack purchase)

trackInfoToTrack : Bandcamp.Model.Purchase ->  Int -> Bandcamp.Model.TrackInfo -> Track.Track
trackInfoToTrack purchase trackNumber trackInfo =
      { title = trackInfo.title
      , source = case purchase.sale_item_id of
        Just _ -> Track.BandcampPurchase trackInfo.playback_url purchase.item_id
        Nothing -> Track.BandcampHeart trackInfo.playback_url purchase.item_id
      , artist = trackInfo.artist
      , album = purchase.title
      , albumArtist = purchase.artist
      , tags = ""
      , id = "bc-track-" ++ trackInfo.id
      }

toTracks : Bandcamp.Model.Model -> Track.Tracks
toTracks {library} =
    case library of
        RemoteData.Success {purchases} ->
            purchases
            |> Bandcamp.Id.dictToList
            |> List.map extractTracksFromPurchase
            |> List.concat
        _ -> []


