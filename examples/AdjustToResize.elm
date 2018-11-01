module Main exposing (Model, Msg(..), ViewSize(..), chooseViewSizesBasedOnSplitterPosition, init, largeView, main, mediumView, smallView, subscriptions, toView, update, updateConfig, view, viewConfig)

import Browser
import Html exposing (..)
import Html.Attributes exposing (style)
import SplitPane
    exposing
        ( Orientation(..)
        , SizeUnit(..)
        , UpdateConfig
        , ViewConfig
        , createUpdateConfig
        , createViewConfig
        )


main : Program () Model Msg
main =
    Browser.element
        { update = update
        , init = init
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type ViewSize
    = Small
    | Medium
    | Large


type alias Model =
    { pane : SplitPane.State
    , leftViewSize : ViewSize
    , rightViewSize : ViewSize
    }


type Msg
    = PaneMsg SplitPane.Msg
    | ResizeViews SizeUnit



-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( { pane =
            SplitPane.init Horizontal
      , leftViewSize = Medium
      , rightViewSize = Medium
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd a )
update msg model =
    case msg of
        PaneMsg paneMsg ->
            let
                ( updatedPane, whatHappened ) =
                    SplitPane.customUpdate updateConfig paneMsg model.pane

                updatedModel =
                    { model | pane = updatedPane }
            in
            case whatHappened of
                Nothing ->
                    ( updatedModel, Cmd.none )

                Just m ->
                    update m updatedModel

        ResizeViews newPosition ->
            let
                ( leftViewNewSize, rightViewNewSize ) =
                    chooseViewSizesBasedOnSplitterPosition newPosition
            in
            ( { model
                | leftViewSize = leftViewNewSize
                , rightViewSize = rightViewNewSize
              }
            , Cmd.none
            )


updateConfig : UpdateConfig Msg
updateConfig =
    createUpdateConfig
        { onResize = \s -> Just (ResizeViews s)
        , onResizeStarted = Nothing
        , onResizeEnded = Nothing
        }


chooseViewSizesBasedOnSplitterPosition : SizeUnit -> ( ViewSize, ViewSize )
chooseViewSizesBasedOnSplitterPosition splitterPosition =
    case splitterPosition of
        Px ( p, _ ) ->
            if p < 200 then
                ( Small, Large )

            else if p < 600 then
                ( Medium, Medium )

            else
                ( Large, Small )

        Percentage ( p, _ ) ->
            if p < 0.25 then
                ( Small, Large )

            else if p < 0.75 then
                ( Medium, Medium )

            else
                ( Large, Small )



-- VIEW


view : Model -> Html Msg
view model =
    let
        ( firstView, secondView ) =
            ( toView model.leftViewSize, toView model.rightViewSize )
    in
    div
        [ style "width" "800px"
        , style "height" "600px"
        ]
        [ SplitPane.view viewConfig firstView secondView model.pane ]


viewConfig : ViewConfig Msg
viewConfig =
    createViewConfig
        { toMsg = PaneMsg
        , customSplitter = Nothing
        }


toView : ViewSize -> Html a
toView size =
    case size of
        Small ->
            smallView

        Medium ->
            mediumView

        Large ->
            largeView


smallView : Html a
smallView =
    div
        [ style "background" "lightblue"
        ]
        [ text "small" ]


mediumView : Html a
mediumView =
    div
        [ style "background" "lightgreen"
        ]
        [ text "medium" ]


largeView : Html a
largeView =
    div
        [ style "background" "lightcoral"
        ]
        [ text "large" ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map PaneMsg <| SplitPane.subscriptions model.pane
