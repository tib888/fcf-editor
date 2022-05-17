module FCFView exposing (viewFullFCF, viewDRF, viewModifierSVG, viewGDTTypeSVG, viewFrame, viewFrameEx, my_text)

import FCF exposing (..)
import Html exposing (Html, text, table, tr, td, span)
import Html.Attributes exposing (..)
import Svg exposing (svg, circle, path)
import Svg.Attributes exposing (viewBox, cx, cy, r, height, d)

-- VIEW


view_datum : Datum -> Html msg
view_datum datum =
    my_text datum.label


view_compound : List DatumUsage -> List (Html msg)
view_compound list =
    case list of
        [] ->
            []

        h :: [] ->
            view_datum_usage h

        h :: t ->
            List.concat [ view_datum_usage h, [ my_text "-" ], view_compound t ]


svgCanvas : Int -> List (Html msg) -> Html msg
svgCanvas width content =
    svg
        [ viewBox (String.fromInt (-width // 2) ++ " -100 " ++ String.fromInt width ++ " 200")
        , Svg.Attributes.height "1.15em"
        , Svg.Attributes.preserveAspectRatio "xMidYMid"
        , style "padding" "0"
        , style "margin" "0"
        , style "vertical-align" "top"
        , Svg.Attributes.strokeLinecap "round"
        ]
        content



-- ((path [ d " M -100 -100 l 200 200 M -100 100 l 200 -200", Svg.Attributes.stroke "black", Svg.Attributes.fill "transparent", Svg.Attributes.strokeWidth "2" ] []) :: content)


letterInCircle : Char -> Html msg
letterInCircle letter =
    svgCanvas 160
        [ circle [ cx "0", cy "0", r "75", Svg.Attributes.stroke "black", Svg.Attributes.fill "transparent", Svg.Attributes.strokeWidth "8" ] []
        , path [ d " M 0 0" ] []
        , Svg.text_ [ Svg.Attributes.x "0", Svg.Attributes.y "50", Svg.Attributes.textAnchor "middle", Svg.Attributes.fontSize "140" ] [ Svg.text (String.fromChar letter) ]
        ]


viewGDTTypeSVG : GdtToleranceType -> Html msg
viewGDTTypeSVG t =
    case t of
        Position ->
            svgCanvas 200
                [ circle [ cx "0", cy "0", r "50", Svg.Attributes.stroke "black", Svg.Attributes.fill "transparent", Svg.Attributes.strokeWidth "8" ] []
                , path [ d " M -75 0 l 150 0 m -75 -75 l 0 150", Svg.Attributes.stroke "black", Svg.Attributes.fill "transparent", Svg.Attributes.strokeWidth "8" ] []
                ]

        Profile ->
            svgCanvas 250
                [ path [ d " M -100 50 A 100 100 0 0 1 100 50", Svg.Attributes.stroke "black", Svg.Attributes.fill "transparent", Svg.Attributes.strokeWidth "8" ] []
                , path [ d " M -100 50 l 200 0", Svg.Attributes.stroke "black", Svg.Attributes.fill "transparent", Svg.Attributes.strokeWidth "8" ] []

                --, path [ d " M -100 -100 l 200 200 M -100 100 l 200 -200", Svg.Attributes.stroke "black", Svg.Attributes.fill "transparent", Svg.Attributes.strokeWidth "8" ] []
                ]
    


viewFrameEx : Int -> List (Html msg) -> Html msg
viewFrameEx row_span content =
    td
        [ style "border" "0.05em solid black"
        , style "margin" "0"
        , style "padding" "0 0.1em"
        , style "vertical-align" "middle"
        , rowspan row_span

        --, style "overflow" "auto"
        ]
        --[toSubTable content]
        content


viewFrame : List (Html msg) -> Html msg
viewFrame =
    viewFrameEx 1


my_text : String -> Html msg
my_text txt =
    span
        [ style "line-height" "1em"
        , style "font-size" "0.8em"
        , style "vertical-align" "0.066em"

        --, style "margin" "0.15em 0 0 0"
        ]
        [ text txt ]


viewModifierSVG : Modifier -> Html msg
viewModifierSVG modifier =
    case modifier of
        NoModifier ->
            my_text ""

        MMC ->
            letterInCircle 'M'

        LMC ->
            letterInCircle 'L'

        SL ->
            my_text "[SL]"


view_datum_reference : Bool -> DatumReference -> List (Html msg)
view_datum_reference has_modifiers datum_reference =
    case datum_reference of
        Single datum ->
            [ view_datum datum ]

        Compound datums ->
            if has_modifiers then
                List.concat [ [ my_text "(" ], view_compound datums, [ my_text ")" ] ]
            else
                view_compound datums


view_datum_usage : DatumUsage -> List (Html msg)
view_datum_usage datum_usage =
    let
        has_modifiers =
            case datum_usage.modifiers of
                [] ->
                    False

                _ ->
                    True
    in
        List.concat
            [ view_datum_reference has_modifiers datum_usage.datum
            , List.map viewModifierSVG datum_usage.modifiers
            ]


view_drf_box : DatumUsage -> Html msg
view_drf_box content =
    viewFrame (view_datum_usage content)


viewDRF : Drf -> List (Html msg)
viewDRF drf =
    List.map view_drf_box drf


view_fcf_tier : Int -> Int -> Fcf -> Html msg
view_fcf_tier tier_count tier_index fcf =
    tr
        [ style "padding" "0"
        , style "margin" "0"
        ]
        (List.concat
            [ if tier_index == 0 then
                [viewFrameEx tier_count [ viewGDTTypeSVG fcf.typ ]]
              else 
                []
            , [ viewFrame (my_text fcf.usl :: List.map viewModifierSVG fcf.modifiers) ]              
            , viewDRF fcf.drf
            ]
        )


viewFullFCF : FullFcf -> Html msg
viewFullFCF full_fcf  =
    let
        tier_count = List.length full_fcf.tiers
    in    
        table
            [ style "border-collapse" "collapse"
            , style "font-family" "Arial, Helvetica, sans-serif"
            , style "vertical-align" "middle"
            , style "cellspacing" "0"
            , style "cellpadding" "0"
            , style "border" "0"
            , style "table-layout" "fixed"
            , style "padding" "0"
            , style "margin" "0"
            ]
            (List.indexedMap (view_fcf_tier tier_count) full_fcf.tiers)
