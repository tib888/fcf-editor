module Main exposing (..)

import Browser exposing (document, Document)
--import Browser.Navigation

import Html exposing (Html, Attribute, div, br, input, textarea, span)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)
import FCF exposing (..)
import FCFView exposing (viewFullFCF)
import FCFEditor exposing (viewFCFeditor, Model, Msg, buildRequest)
import Http exposing (..)
import Json.Encode exposing (..)
import Json.Decode exposing (errorToString)
import Debug exposing (log)

type Msg
    = EditFCF FCFEditor.Msg
    | GotFCFtiers (Result Http.Error FullFcf)
    | RequestFCF
    | TypedFcf String


type alias Model =
    { fcf_editor: FCFEditor.Model   
    , typing: Bool 
    }

example_fcf : FullFcf
example_fcf =
    { tiers = 
    [ { typ = Position
        , usl = "0.1"
        , modifiers = [ MMC ]
        , drf =
            [ { datum =
                    Compound
                        [ { datum =
                                Compound
                                    [ { datum = Single (Datum "A"), modifiers = [ MMC ] }
                                    , { datum = Single (Datum "B"), modifiers = [ MMC ] }
                                    ]
                            , modifiers = [ SL ]
                            }
                        , { datum =
                                Compound
                                    [ { datum = Single (Datum "C"), modifiers = [ MMC ] }
                                    , { datum = Single (Datum "D"), modifiers = [ MMC ] }
                                    ]
                            , modifiers = [ SL ]
                            }
                        ]
                , modifiers = []
                }
            , { datum = Single (Datum "E"), modifiers = [] }
            , { datum = Single (Datum "G"), modifiers = [ LMC ] }
            ]
        }
    , { typ = Position
        , usl = "0.1"
        , modifiers = [ MMC ]
        , drf =
            [ { datum =
                    Compound
                        [ { datum =
                                Compound
                                    [ { datum = Single (Datum "A"), modifiers = [ MMC ] }
                                    , { datum = Single (Datum "B"), modifiers = [ MMC ] }
                                    ]
                            , modifiers = [ SL ]
                            }
                        , { datum =
                                Compound
                                    [ { datum = Single (Datum "C"), modifiers = [ MMC ] }
                                    , { datum = Single (Datum "D"), modifiers = [ MMC ] }
                                    ]
                            , modifiers = [ SL ]
                            }
                        ]
                , modifiers = []
                }
            , { datum = Single (Datum "E"), modifiers = [] }
            ]
        }
    ],
    human_readable = "" }

init : () -> (Model, Cmd Msg)
init flags = 
    ({  fcf_editor = 
        { full_fcf = { tiers = [], human_readable = "" }
        , datum_letters = [ "A", "B", "C", "D", "E", "F", "..." ]
        , allowed_modifiers = [ NoModifier, MMC, LMC, SL ]
        }
      , typing = False
        }
    , getFCF )

-- VIEW


view : Model -> Document Msg
view model =    
    Document 
        "FCF editor"
        [
        div [ style "font-size" "40px" ]
            [ Html.map EditFCF (viewFCFeditor model.fcf_editor)
            , br [] []
            , viewFullFCF model.fcf_editor.full_fcf
            , br [] []
            , textarea 
                [ style "width" "100%"
                , value model.fcf_editor.full_fcf.human_readable
                , onInput TypedFcf
                ] 
                []            
            ]
        ]


-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        EditFCF message ->            
            ( { model | typing = False }, editFCF (Http.jsonBody (buildRequest message)))
            -- in "offline" case this would be: ( { model | editor = FCFEditor.update message model.editor} , Cmd.none )
                
        GotFCFtiers (Ok json) ->
            let
                typed = model.fcf_editor.full_fcf.human_readable
                e = model.fcf_editor 
                f = e.full_fcf
            in
                ( { model | 
                        fcf_editor = { e | 
                            full_fcf = 
                                if model.typing then 
                                     { json | human_readable = typed } 
                                else json 
                        }
                  } , Cmd.none )

        GotFCFtiers (Err (BadBody error)) ->
            ( log ("GotFCFtiers Error = " ++ error) model, Cmd.none ) 
        
        GotFCFtiers (Err error) ->
            ( model, Cmd.none )     --todo log error?

        RequestFCF ->
            ( model, getFCF )

        TypedFcf new_value ->           
            let
                e = model.fcf_editor 
                f = e.full_fcf
            in                        
                ( { model | typing = True, fcf_editor = { e | full_fcf = { f | human_readable = new_value}} } , typeFCF new_value )

editFCF : Body -> Cmd Msg       
editFCF parameters =
    Http.post
        { url = "/api/v1/EditFCF" 
        , body = parameters
        , expect = Http.expectJson GotFCFtiers decodeFullFcf
        }

getFCF : Cmd Msg       
getFCF =
    Http.get
        { url = "/api/v1/GetFCF" 
        , expect = Http.expectJson GotFCFtiers decodeFullFcf
        }

typeFCF : String -> Cmd Msg       
typeFCF txt =
    Http.post
        { url = "/api/v1/TypeFCF" 
        , body = Http.jsonBody (Json.Encode.string txt)
        , expect = Http.expectJson GotFCFtiers decodeFullFcf
        }

-- MAIN

subscriptions : Model -> Sub Msg
subscriptions model = 
    Sub.none

main =
    Browser.document 
    { init = init 
    , view = view
    , update = update
    , subscriptions = subscriptions 
    }