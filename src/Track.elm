module Track exposing (..)
{-| A module for keeping all the data around a track and operating on it
Note that a track may either come from bandamp or a local file
-}


import Json.Encode as Encode
import Json.Decode as Decode
import FileSystem


import Bandcamp.Id

initTracks = []

addLocal : List FileSystem.ReadResult -> Tracks -> Tracks
addLocal readResult tracks =
        tracks ++ (List.map refineLocalImport readResult)

refineLocalImport : FileSystem.ReadResult -> Track
refineLocalImport result =
    { title = result.name
    , artist = result.artist
    , source= LocalFile {name = result.name, path = result.path}
    , tags = result.tags
    , album = result.album
    , albumArtist = result.albumartist
    , id = "fs:" ++ result.hash
    }


-- [generator-start]
type alias Id = String

type alias Tracks = List Track
type alias Track =
    { title : String
    , artist: String
    , album: String
    , albumArtist : String
    , source: TrackSource
    , tags: String
    , id : Id
    }

type TrackSource =
    LocalFile FileSystem.FileRef
  | BandcampPurchase String Bandcamp.Id.Id
  | BandcampHeart String Bandcamp.Id.Id

-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeId =
   Decode.string

decodeTrack =
   Decode.map7
      Track
         ( Decode.field "title" Decode.string )
         ( Decode.field "artist" Decode.string )
         ( Decode.field "album" Decode.string )
         ( Decode.field "albumArtist" Decode.string )
         ( Decode.field "source" decodeTrackSource )
         ( Decode.field "tags" Decode.string )
         ( Decode.field "id" decodeId )

decodeTrackSource =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeTrackSourceHelp

decodeTrackSourceHelp constructor =
   case constructor of
      "LocalFile" ->
         Decode.map
            LocalFile
               ( Decode.field "A1" FileSystem.decodeFileRef )
      "BandcampPurchase" ->
         Decode.map2
            BandcampPurchase
               ( Decode.field "A1" Decode.string )
               ( Decode.field "A2" Bandcamp.Id.decodeId )
      "BandcampHeart" ->
         Decode.map2
            BandcampHeart
               ( Decode.field "A1" Decode.string )
               ( Decode.field "A2" Bandcamp.Id.decodeId )
      other->
         Decode.fail <| "Unknown constructor for type TrackSource: " ++ other

decodeTracks =
   Decode.list decodeTrack

encodeId a =
   Encode.string a

encodeTrack a =
   Encode.object
      [ ("title", Encode.string a.title)
      , ("artist", Encode.string a.artist)
      , ("album", Encode.string a.album)
      , ("albumArtist", Encode.string a.albumArtist)
      , ("source", encodeTrackSource a.source)
      , ("tags", Encode.string a.tags)
      , ("id", encodeId a.id)
      ]

encodeTrackSource a =
   case a of
      LocalFile a1->
         Encode.object
            [ ("Constructor", Encode.string "LocalFile")
            , ("A1", FileSystem.encodeFileRef a1)
            ]
      BandcampPurchase a1 a2->
         Encode.object
            [ ("Constructor", Encode.string "BandcampPurchase")
            , ("A1", Encode.string a1)
            , ("A2", Bandcamp.Id.encodeId a2)
            ]
      BandcampHeart a1 a2->
         Encode.object
            [ ("Constructor", Encode.string "BandcampHeart")
            , ("A1", Encode.string a1)
            , ("A2", Bandcamp.Id.encodeId a2)
            ]

encodeTracks a =
   (Encode.list encodeTrack) a 
-- [generator-end]
