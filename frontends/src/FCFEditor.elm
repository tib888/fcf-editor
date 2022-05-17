module FCFEditor exposing (Model, Msg, update, buildRequest, viewFCFeditor)

import Html exposing (Html, Attribute, input, table, tr)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)
import FCF exposing (..)
import FCFView exposing (..)
import Debug exposing (log)
import Json.Encode exposing (..)


-- MODEL


type alias Model =
    { full_fcf : FullFcf
    , datum_letters : List String
    , allowed_modifiers : List Modifier    
    }


usl_lens : List Fcf -> Int -> String -> List Fcf
usl_lens fcfs tier_index new_value =
    case ( tier_index, fcfs ) of
        ( 0, fcf :: rest ) ->
            { fcf | usl = new_value } :: rest

        ( _, fcf :: rest ) ->
            fcf :: usl_lens rest (tier_index - 1) new_value

        ( _, [] ) ->
            log "unexpected usl_lens" [] -- must not get here


drf_content_lens : List Fcf -> Path -> String -> List Fcf
drf_content_lens fcfs path new_value =
    case ( path, fcfs ) of
        ( 0 :: subpath, fcf :: rest ) ->
            { fcf | drf = datum_reference_lens fcf.drf subpath new_value } :: rest

        ( tier_index :: subpath, fcf :: rest ) ->
            fcf :: drf_content_lens rest ((tier_index - 1) :: subpath) new_value

        ( [], _ ) ->
            log "unexpected drf_content_lens 1" []

        -- must not get here
        ( _, [] ) ->
            log "unexpected drf_content_lens 2" []



-- must not get here


datum_reference_lens : List DatumUsage -> Path -> String -> List DatumUsage
datum_reference_lens original path new_value =
    case ( path, original ) of
        ( 0 :: [], h :: t ) ->
            -- case String.right 1 new_value of
            --   "-" -> -- allow to insert more compound simblings?
            --     let
            --       new_val = String.dropRight 1 new_value
            --     in
            --       { datum = Compound [{ h | datum = Single (DatumLabel new_val) }, { h | datum = Single (DatumLabel "?")}], modifiers = [ SL] } :: t
            --   _  ->
            { h | datum = Single (Datum (String.toUpper new_value)) } :: t

        ( i :: [], h :: t ) ->
            h :: datum_reference_lens t [ i - 1 ] new_value

        ( 0 :: rest, h :: t ) ->
            { h
                | datum =
                    case h.datum of
                        Compound c ->
                            Compound (datum_reference_lens c rest new_value)

                        _ ->
                            log "datum_reference_lens 1" h.datum

                -- must not get here
            }
                :: t

        ( i :: rest, h :: t ) ->
            h :: datum_reference_lens t (i - 1 :: rest) new_value

        _ ->
            log "datum_reference_lens 2" original



-- must not get here
-- UPDATE


type Msg
    = ChangeToleranceValue Int String
    | ChangeDatumUse Path String


update : Msg -> Model -> Model
update msg model =
    case msg of
        ChangeToleranceValue tier_index new_value ->
            let 
                f = model.full_fcf 
            in
                { model | full_fcf = { f | tiers = usl_lens f.tiers tier_index new_value }}

        ChangeDatumUse path new_value ->
            let 
                f = model.full_fcf 
            in
                { model | full_fcf = { f | tiers = drf_content_lens f.tiers path new_value }}


buildRequest : Msg -> Json.Encode.Value 
buildRequest msg =
    case msg of
        ChangeToleranceValue tier_index new_value ->
            Json.Encode.object 
            [ ("ChangeToleranceValue", Json.Encode.list identity 
                [ Json.Encode.int tier_index
                , Json.Encode.string new_value
                ])
            ]

        ChangeDatumUse path new_value ->
            Json.Encode.object 
                [ ("ChangeDatumUse", Json.Encode.list identity 
                    [ Json.Encode.list int path
                    , Json.Encode.string new_value
                    ])
                ]

-- VIEW


type alias Path =
    List Int


adapt_width : String -> String
adapt_width text =
    String.fromFloat (Basics.max 1.0 (0.5 * toFloat (String.length text))) ++ "em"



-- todo
-- path_append : Int -> String -> String
-- path_append index path =
--   path ++ "/" ++ String.fromInt index
-- format_path: Path -> String
-- format_path path =
--   List.foldr path_append "" path
-- <text contenteditable="true" id="Username" class="cls-7" transform="translate(142 280)"><tspan x="0" y="0">Username</tspan></text>
-- my_editable_dropdown_input2: String -> Html Msg
-- my_editable_dropdown_input2 val =
--   text
--     [ class "cls-7"
--     --, transform "translate(142 280)"
--     ]
--     [
--       span [x "0", y "0" contenteditable True]
--       [val]
--     ]


editor_datum : Path -> Datum -> Html Msg
editor_datum path datum =
    my_editable_dropdown_input path datum.label


editor_compound : Path -> Int -> List DatumUsage -> List (Html Msg)
editor_compound path index list =
    case list of
        [] ->
            []

        h :: [] ->
            editor_datum_usage (List.append path [ index ]) h

        h :: t ->
            List.concat [ editor_datum_usage (List.append path [ index ]) h, [ my_text "-" ], editor_compound path (index + 1) t ]


editor_datum_reference : Path -> Bool -> DatumReference -> List (Html Msg)
editor_datum_reference path has_modifiers datum_reference =
    case datum_reference of
        Single datum ->
            [ editor_datum path datum ]

        Compound datums ->
            if has_modifiers then
                List.concat [ [ my_text "(" ], editor_compound path 0 datums, [ my_text ")" ] ]
            else
                editor_compound path 0 datums


editor_datum_usage : Path -> DatumUsage -> List (Html Msg)
editor_datum_usage path datum_usage =
    let
        has_modifiers =
            case datum_usage.modifiers of
                [] ->
                    False

                _ ->
                    True
    in
        List.concat
            [ editor_datum_reference path has_modifiers datum_usage.datum
            , List.map viewModifierSVG datum_usage.modifiers
            ]


editor_drf_box : Path -> Int -> DatumUsage -> Html Msg
editor_drf_box path index drf_box =
    viewFrame (editor_datum_usage (List.append path [ index ]) drf_box)


validate_unilateral_tolerance : String -> Attribute Msg
validate_unilateral_tolerance val =
    case String.toFloat (String.trim val) of
        Nothing ->
            style "color" "red"

        Just v ->
            style "color"
                (if v < 0.0 then
                    "red"
                 else
                    "black"
                )


my_editable_dropdown_input : Path -> String -> Html Msg
my_editable_dropdown_input path val =
    input
        [ style "width" (adapt_width val)
        , style "font-family" "Arial, Helvetica, sans-serif"
        , style "font-size" "0.85em"
        , style "vertical-align" "0.066em"
        , style "padding" "0"
        , style "margin" "0 0"
        , style "border-top-style" "hidden"
        , style "border-right-style" "hidden"
        , style "border-left-style" "hidden"
        , style "border-bottom-style" "hidden"
        , value val -- ++ format_path path
        , onInput (ChangeDatumUse path)

        --, list "datum_list"
        ]
        []


editor_fcf : Int -> Int -> Fcf -> Html Msg
editor_fcf tier_count tier_index fcf =
    tr
        [ style "font-family" "Arial, Helvetica, sans-serif"
        ]
        (List.concat        
            [ 
              if tier_index == 0 then
                [viewFrameEx tier_count [ viewGDTTypeSVG fcf.typ ]]
              else 
                []               
              , [viewFrame
                    (input
                        [ placeholder "..."
                        , style "width" (adapt_width fcf.usl)

                        -- , style "border-top-style" "hidden"
                        -- , style "border-right-style" "hidden"
                        -- , style "border-left-style" "hidden"
                        -- , style "border-bottom-style" "hidden"
                        , style "font-family" "Arial, Helvetica, sans-serif"
                        , style "font-size" "0.85em"
                        , style "vertical-align" "0.066em"

                        -- , style "background-color" "#eee"
                        , required True
                        , autofocus True

                        --, novalidate False
                        --, pattern regexp -- can be used for validation
                        --, type_ "text"
                        , validate_unilateral_tolerance fcf.usl -- gives red color on bad input
                        , onInput (ChangeToleranceValue tier_index)
                        , value fcf.usl
                        ]
                        []
                        :: List.map viewModifierSVG fcf.modifiers
                    )
                ]
                , List.indexedMap (editor_drf_box [ tier_index ]) fcf.drf
            ]
        )



-- to_option : String -> Html Msg -> Html Msg
-- to_option val render =
--   option [value val] [render]


viewFCFeditor : Model -> Html Msg
viewFCFeditor model =
  let
        tier_count = List.length model.full_fcf.tiers
  in
    table
        [ style "border-collapse" "collapse"
        , style "font-family" "Arial, Helvetica, sans-serif"
        , style "vertical-align" "middle"
        , style "cellspacing" "0"
        , style "cellpadding" "0"
        , style "border" "0"
        , style "table-layout" "fixed"
        ]
        (List.indexedMap (editor_fcf tier_count) model.full_fcf.tiers)



--, datalist [id "datum_list"] (List.map to_option model.datum_letters)
--, datalist [id "modifier_list"] (List.map to_option (List.map viewModifierSVG model.allowed_modifiers))
