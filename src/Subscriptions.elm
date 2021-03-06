module Subscriptions exposing (subscriptions)
import Model
import Msg
import Bandcamp
import FileSystem
import Json.Decode as Decode
import MultiInput
import Syncer

subscriptions : Model.Model -> Sub Msg.Msg
subscriptions model =
    Sub.batch
        [ Bandcamp.subscriptions model.bandcamp |> Sub.map Msg.BandcampMsg
        , filesystemSub
        , MultiInput.subscriptions model.quickTagsInputState |> Sub.map Msg.SetQuickTag
        , Syncer.subscriptions |> Sub.map Msg.SyncerMsg
        ]



filesystemSub : Sub Msg.Msg
filesystemSub =
    let
        captureFileSystemScan val =
            val
            |> Decode.decodeValue (Decode.list FileSystem.decodeReadResult)
            |> Msg.FilesRead

        found = FileSystem.filesystem_in_paths_scanned Msg.FilesFound
        read = FileSystem.filesystem_in_files_parsed captureFileSystemScan
    in
        Sub.batch [found, read]
