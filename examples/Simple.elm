module Main exposing (Model, Msg(..), firstView, init, main, secondView, subscriptions, update, view, viewConfig)

import Browser
import Html exposing (..)
import Html.Attributes exposing (src, style)
import SplitPane exposing (Orientation(..), ViewConfig, createViewConfig)


main : Program () Model Msg
main =
    Browser.element
        { update = update
        , init = init
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    { pane : SplitPane.State
    }


type Msg
    = PaneMsg SplitPane.Msg



-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( { pane = SplitPane.init Horizontal
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd a )
update msg model =
    case msg of
        PaneMsg paneMsg ->
            ( { model | pane = SplitPane.update paneMsg model.pane }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
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


firstView : Html a
firstView =
    img [ src "http://4.bp.blogspot.com/-s3sIvuCfg4o/VP-82RkCOGI/AAAAAAAALSY/509obByLvNw/s1600/baby-cat-wallpaper.jpg" ] []


secondView : Html a
secondView =
    img [ src "http://2.bp.blogspot.com/-pATX0YgNSFs/VP-82AQKcuI/AAAAAAAALSU/Vet9e7Qsjjw/s1600/Cat-hd-wallpapers.jpg" ] []



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map PaneMsg <| SplitPane.subscriptions model.pane
