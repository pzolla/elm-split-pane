module SplitPane exposing
    ( view, createViewConfig
    , update, subscriptions
    , State, init, configureSplitter, draggable
    , percentage, px
    , Msg, Orientation(..), SizeUnit(..), ViewConfig, UpdateConfig, CustomSplitter, HtmlDetails
    , customUpdate, createUpdateConfig, createCustomSplitter
    )

{-| This is a split pane view library. Can be used to split views into multiple parts with a splitter between them.

Check out the [examples] to see how it works.

[examples]: https://github.com/doodledood/elm-split-pane/tree/master/examples


# View

@docs view, createViewConfig


# Update

@docs update, subscriptions


# State

@docs State, init, configureSplitter, orientation, draggable


# Helpers

@docs percentage, px


# Definitions

@docs Msg, Orientation, SizeUnit, ViewConfig, UpdateConfig, CustomSplitter, HtmlDetails


# Customization

@docs customUpdate, createUpdateConfig, createCustomSplitter

-}
import Browser.Events
import Bound
    exposing
        ( Bounded
        , createBound
        , createBounded
        , getValue
        , updateValue
        )
import Html exposing (Attribute, Html, div, span)
import Html.Attributes exposing (class, style)
import Html.Events
import Json.Decode as Json exposing (at, field)
import Maybe



-- MODEL


{-| Size unit for setting slider - either percentage value between 0.0 and 1.0 or pixel value (> 0)
-}
type SizeUnit
    = Percentage (Bounded Float)
    | Px (Bounded Int)


{-| Orientation of pane.
-}
type Orientation
    = Horizontal
    | Vertical


{-| Keeps dimensions of pane.
-}
type alias PaneDOMInfo =
    { width : Int
    , height : Int
    }


{-| Keep relevant information for the drag operations.
-}
type alias DragInfo =
    { paneInfo : PaneDOMInfo
    , anchor : Position
    }


{-| Drag state information.
-}
type DragState
    = Draggable (Maybe DragInfo)
    | NotDraggable


{-| Tracks state of pane.
-}
type State
    = State
        { orientation : Orientation
        , splitterPosition : SizeUnit
        , dragState : DragState
        }


{-| Internal messages.
-}
type Msg
    = SplitterClick DOMInfo
    | SplitterMove Position
    | SplitterLeftAlone Position


{-| Describes a mouse/touch position
-}
type alias Position =
    { x : Int
    , y : Int
    }


{-| Sets whether the pane is draggable or not
-}
draggable : Bool -> State -> State
draggable isDraggable (State state) =
    State
        { state
            | dragState =
                if isDraggable then
                    Draggable Nothing

                else
                    NotDraggable
        }


{-| Changes orientation of the pane.
-}
orientation : Orientation -> State -> State
orientation o (State state) =
    State { state | orientation = o }


{-| Change the splitter position and limit
-}
configureSplitter : SizeUnit -> State -> State
configureSplitter newPosition (State state) =
    State
        { state
            | splitterPosition = newPosition
        }


{-| Creates a percentage size unit from a float
-}
percentage : Float -> Maybe ( Float, Float ) -> SizeUnit
percentage x bound =
    let
        newBound =
            case bound of
                Just ( lower, upper ) ->
                    createBound lower upper

                Nothing ->
                    createBound 0.0 1.0
    in
    Percentage <| createBounded x newBound


{-| Creates a pixel size unit from an int
-}
px : Int -> Maybe ( Int, Int ) -> SizeUnit
px x bound =
    let
        newBound =
            case bound of
                Just ( lower, upper ) ->
                    createBound lower upper

                Nothing ->
                    createBound 0 9999999999
    in
    Px <| createBounded x newBound



-- INIT


{-| Initialize a new model.

        init Horizontal

-}
init : Orientation -> State
init orientation1 =
    State
        { orientation = orientation1
        , splitterPosition = percentage 0.5 Nothing
        , dragState = Draggable Nothing
        }



-- UPDATE


domInfoToPosition : DOMInfo -> Position
domInfoToPosition { x, y, touchX, touchY } =
     case ( ( x, y ), ( touchX, touchY ) ) of
        ( ( _, _ ), ( Just posX, Just posY ) ) ->
            { x = posX, y = posY }

        ( ( Just posX, Just posY ), ( _, _ ) ) ->
            { x = posX, y = posY }

        _ ->
            { x = 0, y = 0 }


{-| Configuration for updates.
-}
type UpdateConfig msg
    = UpdateConfig
        { onResize : SizeUnit -> Maybe msg
        , onResizeStarted : Maybe msg
        , onResizeEnded : Maybe msg
        }


{-| Creates the update configuration.
Gives you the option to respond to various things that happen.

    For example:
    - Draw a different view when the pane is resized:

        updateConfig
            { onResize (\p -> Just (SwitchViews p))
            , onResizeStarted Nothing
            , onResizeEnded Nothing
            }

-}
createUpdateConfig :
    { onResize : SizeUnit -> Maybe msg
    , onResizeStarted : Maybe msg
    , onResizeEnded : Maybe msg
    }
    -> UpdateConfig msg
createUpdateConfig config =
    UpdateConfig config


{-| Updates internal model.
-}
update : Msg -> State -> State
update msg model =
    let
        ( updatedModel, _ ) =
            customUpdate
                (createUpdateConfig
                    { onResize = \_ -> Nothing
                    , onResizeStarted = Nothing
                    , onResizeEnded = Nothing
                    }
                )
                msg
                model
    in
    updatedModel


{-| Updates internal model using custom configuration.
-}
customUpdate : UpdateConfig msg -> Msg -> State -> ( State, Maybe msg )
customUpdate (UpdateConfig updateConfig) msg (State state) =
    case ( state.dragState, msg ) of
        ( Draggable Nothing, SplitterClick pos ) ->
            ( State
                { state
                    | dragState =
                        Draggable <|
                            Just
                                { paneInfo =
                                    { width = pos.parentWidth
                                    , height = pos.parentHeight
                                    }
                                , anchor =
                                    { x = Maybe.withDefault 0 pos.x
                                    , y = Maybe.withDefault 0 pos.y
                                    }
                                }
                }
            , updateConfig.onResizeStarted
            )

        ( Draggable (Just _), SplitterLeftAlone _ ) ->
            ( State { state | dragState = Draggable Nothing }
            , updateConfig.onResizeEnded
            )

        ( Draggable (Just { paneInfo, anchor }), SplitterMove newRequestedPosition ) ->
            let
                step =
                    { x = newRequestedPosition.x - anchor.x
                    , y = newRequestedPosition.y - anchor.y
                    }

                newSplitterPosition =
                    resize state.orientation state.splitterPosition step paneInfo.width paneInfo.height
            in
            ( State
                { state
                    | splitterPosition = newSplitterPosition
                    , dragState =
                        Draggable <|
                            Just
                                { paneInfo =
                                    { width = paneInfo.width
                                    , height = paneInfo.height
                                    }
                                , anchor =
                                    { x = newRequestedPosition.x
                                    , y = newRequestedPosition.y
                                    }
                                }
                }
            , updateConfig.onResize newSplitterPosition
            )

        _ ->
            ( State state, Nothing )


resize : Orientation -> SizeUnit -> Position -> Int -> Int -> SizeUnit
resize orientation2 splitterPosition step paneWidth paneHeight =
    case orientation2 of
        Horizontal ->
            case splitterPosition of
                Px px1 ->
                    Px <| updateValue (\v -> v + step.x) px1

                Percentage p ->
                    Percentage <| updateValue (\v -> v + toFloat step.x / toFloat paneWidth) p

        Vertical ->
            case splitterPosition of
                Px px1 ->
                    Px <| updateValue (\v -> v + step.y) px1

                Percentage p ->
                    Percentage <| updateValue (\v -> v + toFloat step.y / toFloat paneHeight) p



-- VIEW


{-| Lets you specify attributes such as style and children for the splitter element
-}
type alias HtmlDetails msg =
    { attributes : List (Attribute msg)
    , children : List (Html msg)
    }


{-| Describes a custom splitter
-}
type CustomSplitter msg
    = CustomSplitter (Html msg)


createDefaultSplitterDetails : Orientation -> DragState -> HtmlDetails msg
createDefaultSplitterDetails orientation3 dragState =
    case orientation3 of
        Horizontal ->
            { attributes =
                 defaultHorizontalSplitterStyle dragState
                
            , children = []
            }

        Vertical ->
            { attributes =
                 defaultVerticalSplitterStyle dragState
                
            , children = []
            }


{-| Creates a custom splitter.

        myCustomSplitter : CustomSplitter Msg
        myCustomSplitter =
            createCustomSplitter PaneMsg
                { attributes =
                    [ style
                        [ ( "width", "20px" )
                        , ( "height", "20px" )
                        ]
                    ]
                , children =
                    []
                }

-}
createCustomSplitter :
    (Msg -> msg)
    -> HtmlDetails msg
    -> CustomSplitter msg
createCustomSplitter toMsg details =
    CustomSplitter <|
        span
            (onMouseDown toMsg :: onTouchStart toMsg :: onTouchEnd toMsg :: onTouchMove toMsg :: onTouchCancel toMsg :: details.attributes)
            details.children


{-| Configuration for the view.
-}
type ViewConfig msg
    = ViewConfig
        { toMsg : Msg -> msg
        , splitter : Maybe (CustomSplitter msg)
        }


{-| Creates a configuration for the view.
-}
createViewConfig :
    { toMsg : Msg -> msg
    , customSplitter : Maybe (CustomSplitter msg)
    }
    -> ViewConfig msg
createViewConfig { toMsg, customSplitter } =
    ViewConfig
        { toMsg = toMsg
        , splitter = customSplitter
        }


{-| Creates a view.

        view : Model -> Html Msg
        view =
            SplitPane.view viewConfig firstView secondView


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

-}
view : ViewConfig msg -> Html msg -> Html msg -> State -> Html msg
view (ViewConfig viewConfig) firstView secondView (State state) =
    let
        splitter =
            getConcreteSplitter viewConfig state.orientation state.dragState
    in
    div
        ([ class "pane-container" ] ++ paneContainerStyle state.orientation)
        [ div
            ([ class "pane-first-view" ] ++ firstChildViewStyle (State state))
            [ firstView ]
        , splitter
        , div
            ([ class "pane-second-view" ] ++ secondChildViewStyle (State state))
            [ secondView ]
        ]


viewReversed : ViewConfig msg -> Html msg -> Html msg -> State -> Html msg
viewReversed (ViewConfig viewConfig) firstView secondView (State state) =
    let
        splitter =
            getConcreteSplitter viewConfig state.orientation state.dragState
    in
    div
        ([ class "pane-container" ] ++ paneContainerStyle state.orientation)
        [ div
            ([ class "pane-second-view" ] ++ secondChildViewStyle (State state))
            [ secondView ]
        , splitter
        , div
            ([ class "pane-first-view" ] ++ firstChildViewStyle (State state))
            [ firstView ]
        ]
        
getConcreteSplitter :
    { toMsg : Msg -> msg
    , splitter : Maybe (CustomSplitter msg)
    }
    -> Orientation
    -> DragState
    -> Html msg
getConcreteSplitter viewConfig orientation4 dragState =
    case viewConfig.splitter of
        Just (CustomSplitter splitter) ->
            splitter

        Nothing ->
            case createCustomSplitter viewConfig.toMsg <| createDefaultSplitterDetails orientation4 dragState of
                CustomSplitter defaultSplitter ->
                    defaultSplitter



-- STYLES


paneContainerStyle : Orientation -> List (Attribute msg)
paneContainerStyle orientation5 =
    [ style "overflow" "hidden"
    , style "display" "flex"
    , style "flexDirection"
        (case orientation5 of
            Horizontal ->
                "row"

            Vertical ->
                "column"
        )
    , style "justifyContent" "center"
    , style "alignItems" "center"
    , style "width" "100%"
    , style "height" "100%"
    , style "boxSizing" "border-box"
    ]


firstChildViewStyle : State -> List (Attribute msg)
firstChildViewStyle (State state) =
    case state.splitterPosition of
        Px px2 ->
            let
                v =
                    (String.fromFloat <| toFloat (getValue px2)) ++ "px"
            in
            case state.orientation of
                Horizontal ->
                    [ style "display" "flex"
                    , style "width" v
                    , style "height" "100%"
                    , style "overflow" "hidden"
                    , style "boxSizing" "border-box"
                    , style "position" "relative"
                    ]

                Vertical ->
                    [ style "display" "flex"
                    , style "width" "100%"
                    , style "height" v
                    , style "overflow" "hidden"
                    , style "boxSizing" "border-box"
                    , style "position" "relative"
                    ]

        Percentage p ->
            let
                v =
                    String.fromFloat <| getValue p
            in
            [ style "display" "flex"
            , style "flex" v
            , style "width" "100%"
            , style "height" "100%" -- pz edit
            , style "overflow" "hidden"
            , style "boxSizing" "border-box"
            , style "position" "relative"
            ]


secondChildViewStyle : State -> List (Attribute msg)
secondChildViewStyle (State state) =
    case state.splitterPosition of
        Px _ ->
            [ style "display" "flex"
            , style "flex" "1"
            , style "width" "100%"
            , style "height" "100%"
            , style "overflow" "hidden"
            , style "boxSizing" "border-box"
            , style "position" "relative"
            ]

        Percentage p ->
            let
                v =
                    String.fromFloat <| 1 - getValue p
            in
             [ style "display" "flex"
            , style "flex" v
            , style "width" "100%"
            , style "height" "100%"
            , style "overflow" "hidden"
            , style "boxSizing" "border-box"
            , style "position" "relative"
            ]


defaultVerticalSplitterStyle : DragState -> List (Attribute msg)
defaultVerticalSplitterStyle dragState =
    baseDefaultSplitterStyles
        ++ [ style "height" "11px"
           , style "width" "100%"
           , style "margin" "-5px 0"
           , style "borderTop" "5px solid rgba(255, 255, 255, 0)"
           , style "borderBottom" "5px solid rgba(255, 255, 255, 0)"
           ]
        ++ (case dragState of
                Draggable _ ->
                    [ style "cursor" "row-resize" ]

                NotDraggable ->
                    []
           )


defaultHorizontalSplitterStyle : DragState -> List (Attribute msg)
defaultHorizontalSplitterStyle dragState =
     baseDefaultSplitterStyles
        ++ [ style "width" "11px"
           , style "height" "100%"
           , style "margin" "0 -5px"
           , style "borderLeft" "5px solid rgba(255, 255, 255, 0)"
           , style "borderRight" "5px solid rgba(255, 255, 255, 0)"
           ]
        ++ (case dragState of
                Draggable _ ->
                    [ style "cursor" "col-resize" ]

                NotDraggable ->
                    []
           )


baseDefaultSplitterStyles : List (Attribute msg)
baseDefaultSplitterStyles =
    [ style "width" "100%"
    , style "background" "#000"
    , style "boxSizing" "border-box"
    , style "opacity" ".2"
    , style "zIndex" "1"
    , style "webkitUserSelect" "none"
    , style "mozUserSelect" "none"
    , style "userSelect" "none"
    , style "backgroundClip" "padding-box"
    ]



-- EVENT HANDLERS


customRecord :
    Bool
    -> Bool
    -> msg
    ->
        { message : msg
        , stopPropagation : Bool
        , preventDefault : Bool
        }
customRecord stop prevent msg =
    { message = msg, stopPropagation = stop, preventDefault = prevent }


onMouseDown : (Msg -> msg) -> Attribute msg
onMouseDown toMsg =
    Html.Events.custom "mousedown" <|
        Json.map (customRecord False True << (toMsg << SplitterClick)) domInfo


onTouchStart : (Msg -> msg) -> Attribute msg
onTouchStart toMsg =
    Html.Events.custom "touchstart" <|
        Json.map (customRecord True True << (toMsg << SplitterClick)) domInfo


onTouchEnd : (Msg -> msg) -> Attribute msg
onTouchEnd toMsg =
    Html.Events.custom "touchend" <|
        Json.map (customRecord True True << (toMsg << SplitterLeftAlone << domInfoToPosition)) domInfo


onTouchCancel : (Msg -> msg) -> Attribute msg
onTouchCancel toMsg =
    Html.Events.custom "touchcancel" <|
        Json.map (customRecord True True << (toMsg << SplitterLeftAlone << domInfoToPosition)) domInfo


onTouchMove : (Msg -> msg) -> Attribute msg
onTouchMove toMsg =
    Html.Events.custom "touchmove" <|
        Json.map (customRecord True True << (toMsg << SplitterMove << domInfoToPosition)) domInfo


{-| The position of the touch relative to the whole document. So if you are
scrolled down a bunch, you are still getting a coordinate relative to the
very top left corner of the _whole_ document.
-}
type alias DOMInfo =
    { x : Maybe Int
    , y : Maybe Int
    , touchX : Maybe Int
    , touchY : Maybe Int
    , parentWidth : Int
    , parentHeight : Int
    }


{-| The decoder used to extract a `DOMInfo` from a JavaScript touch event.
-}
domInfo : Json.Decoder DOMInfo
domInfo =
    Json.map6 DOMInfo
        (Json.maybe (field "clientX" Json.int))
        (Json.maybe (field "clientY" Json.int))
        (Json.maybe (at [ "touches", "0", "clientX" ] Json.int))
        (Json.maybe (at [ "touches", "0", "clientY" ] Json.int))
        (at [ "currentTarget", "parentElement", "clientWidth" ] Json.int)
        (at [ "currentTarget", "parentElement", "clientHeight" ] Json.int)



-- SUBSCRIPTIONS


{-| Subscribes to relevant events for resizing
-}
subscriptions : State -> Sub Msg
subscriptions (State state) =
    case state.dragState of
        Draggable (Just _) ->
            Sub.batch
                [ Browser.Events.onMouseMove <| Json.map SplitterMove positionDecoder
                , Browser.Events.onMouseUp <| Json.map SplitterLeftAlone positionDecoder
                ]

        _ ->
            Sub.none


positionDecoder : Json.Decoder Position
positionDecoder =
    Json.map2 Position
        (Json.field "pageX" Json.int)
        (Json.field "pageY" Json.int)