module FCF exposing (..)

import Json.Decode exposing (Decoder, field, string, list, map, map2, map4, lazy)
import Debug exposing (log)


type GdtToleranceType
    = Position
    | Profile


decodeGdtToleranceType : String -> GdtToleranceType
decodeGdtToleranceType t =
    case t of
        "Position" ->
            Position

        "Profile" ->
            Profile

        _ ->
            log ("Unexpected tolerance type: " ++ t) Position


type Modifier
    = NoModifier
    | MMC
    | LMC
    | SL


decodeModifier : String -> Modifier
decodeModifier m =
    case m of
        "MMC" ->
            MMC

        "LMC" ->
            LMC

        "SL" ->
            SL

        _ ->
            log ("Unexpected modofier type: " ++ m) NoModifier


type alias Datum = 
    { label: String
    --| Reference String
    }


decodeDatum : Decoder Datum
decodeDatum =
    map Datum (field "label" string)


type DatumReference
    = Single Datum
    | Compound (List DatumUsage)


decodeDatumReference : Decoder DatumReference
decodeDatumReference =
    Json.Decode.oneOf
        [ map Single (field "Single" decodeDatum)
        , map Compound (field "Compound" (Json.Decode.list (Json.Decode.lazy (\_ -> decodeDatumUsage)))) 
        ]
-- _ -> log ("Unexpected datumreference: " ++ t) (map Single (map DatumLabel "" string


type alias DatumUsage =
    { datum : DatumReference
    , modifiers : List Modifier
    }


decodeDatumUsage : Decoder DatumUsage
decodeDatumUsage =
    map2 DatumUsage
        (field "datum" decodeDatumReference)
        (field "modifiers" (Json.Decode.list (map decodeModifier string)))


type alias Drf =
    List DatumUsage


type alias Fcf =
    { typ : GdtToleranceType
    , usl : String
    , modifiers : List Modifier
    , drf : Drf
    }


decodeFCF : Decoder Fcf
decodeFCF =
    map4 Fcf
        (map decodeGdtToleranceType (field "typ" string))
        (field "usl" string)
        (field "modifiers" (Json.Decode.list (map decodeModifier string)))
        (field "drf" (Json.Decode.list decodeDatumUsage))


type alias FullFcf = 
    { tiers: List Fcf,
      human_readable: String
    }

decodeFullFcf : Decoder FullFcf
decodeFullFcf =
    map2 FullFcf
        (field "tiers" (Json.Decode.list decodeFCF))
        (field "human_readable" string)
