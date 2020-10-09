port module Main exposing (Model, Msg, init, subscriptions, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, placeholder, preload, value)
import Html.Events exposing (onClick, onInput)
import Task exposing (Task)
import Time exposing (Month(..), Posix, Weekday(..), Zone, millisToPosix, posixToMillis)


port saveData : String -> Cmd msg


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Course =
    { id : String
    , name : String
    , weekday : Int
    , period : ( Int, Int )
    , room : String
    , weeks : List Int
    }


type State
    = InputRaw String
    | ViewCourses (List Course)


type alias Model =
    { state : State
    , currentTime : ( Posix, Zone )
    }


type alias Flags =
    String


init : Flags -> ( Model, Cmd Msg )
init raw =
    let
        state =
            case raw |> rawToCourses of
                [] ->
                    InputRaw ""

                courses ->
                    ViewCourses courses
    in
    ( Model state ( Time.millisToPosix 0, Time.utc )
    , Task.perform GotTime Time.now
    )



-- UPDATE


type Msg
    = SaveData String
    | GotRaw String
    | GotTime Posix
    | GotZone Zone
    | NextWeek
    | PrevWeek


dayToMillis : Int -> Int
dayToMillis day =
    day * 86400000


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SaveData raw ->
            ( { model
                | state = ViewCourses (raw |> rawToCourses)
              }
            , saveData raw
            )

        GotRaw raw ->
            ( { model
                | state = InputRaw (String.trim raw)
              }
            , Cmd.none
            )

        GotTime posix ->
            ( { model | currentTime = ( posix, Tuple.second model.currentTime ) }, Cmd.none )

        GotZone zone ->
            ( { model | currentTime = ( Tuple.first model.currentTime, zone ) }, Cmd.none )

        NextWeek ->
            ( { model
                | currentTime =
                    model.currentTime
                        |> Tuple.mapFirst
                            (\posix ->
                                millisToPosix (posixToMillis posix + dayToMillis 7)
                            )
              }
            , Cmd.none
            )

        PrevWeek ->
            ( { model
                | currentTime =
                    model.currentTime
                        |> Tuple.mapFirst
                            (\posix ->
                                millisToPosix (posixToMillis posix - dayToMillis 7)
                            )
              }
            , Cmd.none
            )


rawToCourses : String -> List Course
rawToCourses raw =
    String.split "\n" raw
        |> List.filterMap
            (\line ->
                case String.split "\t" line of
                    [ id, name, _, _, _, rawWeekday, rawPeriod, _, room, _, rawWeeks ] ->
                        let
                            defaultZero =
                                String.toInt >> Maybe.withDefault 0

                            weeks =
                                rawWeeks |> String.split "|" |> List.filterMap String.toInt

                            weekday =
                                defaultZero rawWeekday

                            period =
                                case String.split "-" rawPeriod of
                                    [ begin, end ] ->
                                        ( defaultZero begin, defaultZero end )

                                    _ ->
                                        ( 0, 0 )
                        in
                        Just (Course id name weekday period room weeks)

                    _ ->
                        Nothing
            )



-- SUBSCRIPTION


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


example : String
example =
    """MI1003\tGiáo dục quốc phòng\t--\t--\tL02\t--\t0-0\t0:00 - 0:00\t------\tBK-CS1\t--|--|--|--|--|--|45|46|47|48|
..."""


view : Model -> Html Msg
view model =
    div [ class "min-h-screen min-w-screen" ]
        [ case model.state of
            InputRaw raw ->
                div [ class "mx-16" ]
                    [ label []
                        [ text "Copy nguyên cái bảng vào đây"
                        , textarea
                            [ value raw
                            , placeholder example
                            , onInput GotRaw
                            , class "block w-full p-1 h-56 border"
                            ]
                            []
                        ]
                    , button
                        [ onClick (SaveData raw)
                        , class "bg-red-500 mt-2 p-1 text-white"
                        ]
                        [ text "Lưu" ]
                    ]

            ViewCourses courses ->
                let
                    thisWeek =
                        posixToWeekNumber model.currentTime
                in
                div []
                    [ div [ class "flex flex-col items-center bg-blue-700 text-white p-2" ]
                        [ p [ class "text-2xl font-bold" ]
                            [ text ("Tuần " ++ String.fromInt thisWeek)
                            ]
                        , div [ class "flex gap-3" ]
                            [ button
                                [ class "p-1 rounded text-sm bg-white bg-blue-500 border-r-2 border-b-2 border-white"
                                , onClick PrevWeek
                                ]
                                [ text "Tuần trước" ]
                            , button
                                [ class "p-1 rounded text-sm bg-white bg-blue-500 border-r-2 border-b-2 border-white"
                                , onClick NextWeek
                                ]
                                [ text "Tuần sau" ]
                            ]
                        ]
                    , div
                        [ class "grid grid-cols-8 grid-rows-13 gap-2 w-auto h-full"
                        ]
                        (viewWeekdays model.currentTime
                            ++ viewPeriods
                            ++ List.map viewCourse (List.filter (.weeks >> List.member thisWeek) courses)
                        )
                    , div [ class "flex flex-col items-center bg-blue-700 text-white p-2" ]
                     [ button [ onClick (GotRaw "") ] [ text "Nhập lại TKB tại đây" ]]
                    ]
        ]


viewCourse : Course -> Html Msg
viewCourse { name, period, weekday, room } =
    div
        [ class (infoToClass weekday period)
        , class "flex flex-col p-2 rounded text-white"
        , class "bg-gradient-to-r from-blue-400 to-blue-500"
        ]
        [ span [ class "font-semibold" ] [ text name ]
        , span [ class "text-sm" ] [ text ("Tại " ++ room) ]
        ]


infoToClass : Int -> ( Int, Int ) -> String
infoToClass weekday ( begin, end ) =
    if begin <= 0 || end <= 0 || weekday < 2 then
        "hidden"

    else
        weekdayToClass weekday
            ++ " col-span-1 "
            ++ periodToClass ( begin, end )


viewPeriods : List (Html Msg)
viewPeriods =
    let
        periodToTime period =
            case period of
                1 ->
                    "06:00 - 06:50"

                2 ->
                    "07:00 - 07:50"

                3 ->
                    "08:00 - 08:50"

                4 ->
                    "09:00 - 09:50"

                5 ->
                    "10:00 - 10:50"

                6 ->
                    "11:00 - 11:50"

                7 ->
                    "12:00 - 12:50"

                8 ->
                    "13:00 - 13:50"

                9 ->
                    "14:00 - 14:50"

                10 ->
                    "15:00 - 15:50"

                11 ->
                    "16:00 - 16:50"

                _ ->
                    "Tiết này ngộ à nha..."
    in
    List.range 1 11
        |> List.map
            (\period ->
                [ div
                    [ class "col-start-1 col-span-8"
                    , if remainderBy 2 period == 1 then
                        class "bg-blue-100"

                      else
                        class ""
                    , class (periodToClass ( period, period ))
                    ]
                    []
                , div
                    [ class "col-start-1"
                    , class (periodToClass ( period, period ))
                    , class "flex flex-col items-center"
                    ]
                    [ span [ class "uppercase font-semibold tracking-wide" ]
                        [ text
                            ("TIẾT "
                                ++ String.fromInt period
                            )
                        ]
                    , span [ class "text-blue-500 text-sm" ] [ text (periodToTime period) ]
                    ]
                ]
            )
        |> List.concat


viewWeekdays : ( Posix, Zone ) -> List (Html Msg)
viewWeekdays ( posix, zone ) =
    let
        weekdayToText weekday =
            case weekday of
                2 ->
                    "Thứ 2"

                3 ->
                    "Thứ 3"

                4 ->
                    "Thứ 4"

                5 ->
                    "Thứ 5"

                6 ->
                    "Thứ 6"

                7 ->
                    "Thứ 7"

                8 ->
                    "Chủ nhật"

                _ ->
                    "Thứ gì ngộ dị"
    in
    List.range 2 8
        |> List.map
            (\weekday ->
                div
                    [ class "flex flex-col justify-end row-start-1"
                    , class (weekdayToClass weekday)
                    , class "text-center"
                    ]
                    [ span [ class "font-semibold uppercase tracking-wide" ] [ text (weekdayToText weekday) ]
                    , viewDate
                        ( millisToPosix (posixToMillis posix + dayToMillis (weekday - 1 - dayOfWeek ( posix, zone )))
                        , zone
                        )
                    ]
            )


viewDate : ( Posix, Zone ) -> Html Msg
viewDate ( posix, zone ) =
    let
        day =
            Time.toDay zone posix

        month =
            case Time.toMonth zone posix of
                Jan ->
                    1

                Feb ->
                    2

                Mar ->
                    3

                Apr ->
                    4

                May ->
                    5

                Jun ->
                    6

                Jul ->
                    7

                Aug ->
                    8

                Sep ->
                    9

                Oct ->
                    10

                Nov ->
                    11

                Dec ->
                    12

        toString =
            String.fromInt >> String.padLeft 2 '0'
    in
    span [ class "text-sm text-blue-500" ] [ text (toString day ++ "/" ++ toString month) ]



-- HELPERS


weekdayToClass : Int -> String
weekdayToClass weekday =
    case weekday of
        2 ->
            "col-start-2 col-span-1"

        3 ->
            "col-start-3 col-span-1"

        4 ->
            "col-start-4 col-span-1"

        5 ->
            "col-start-5 col-span-1"

        6 ->
            "col-start-6 col-span-1"

        7 ->
            "col-start-7 col-span-1"

        8 ->
            "col-start-8 col-span-1"

        _ ->
            "hidden"


periodToClass : ( Int, Int ) -> String
periodToClass ( begin, end ) =
    let
        beginClass =
            case begin of
                1 ->
                    "row-start-2"

                2 ->
                    "row-start-3"

                3 ->
                    "row-start-4"

                4 ->
                    "row-start-5"

                5 ->
                    "row-start-6"

                6 ->
                    "row-start-7"

                7 ->
                    "row-start-8"

                8 ->
                    "row-start-9"

                9 ->
                    "row-start-10"

                10 ->
                    "row-start-11"

                11 ->
                    "row-start-12"

                _ ->
                    "hidden"

        endClass =
            case end of
                1 ->
                    "row-end-3"

                2 ->
                    "row-end-4"

                3 ->
                    "row-end-5"

                4 ->
                    "row-end-6"

                5 ->
                    "row-end-7"

                6 ->
                    "row-end-8"

                7 ->
                    "row-end-9"

                8 ->
                    "row-end-10"

                9 ->
                    "row-end-11"

                10 ->
                    "row-end-12"

                11 ->
                    "row-end-13"

                _ ->
                    "hidden"
    in
    beginClass ++ " " ++ endClass


isLeapYear : Int -> Bool
isLeapYear year =
    if remainderBy 4 year /= 0 then
        False

    else if remainderBy 100 year /= 0 then
        True

    else if remainderBy 400 year /= 0 then
        False

    else
        True


dayOfWeek : ( Posix, Zone ) -> Int
dayOfWeek ( posix, zone ) =
    case Time.toWeekday zone posix of
        Mon ->
            1

        Tue ->
            2

        Wed ->
            3

        Thu ->
            4

        Fri ->
            5

        Sat ->
            6

        Sun ->
            7


posixToWeekNumber : ( Posix, Zone ) -> Int
posixToWeekNumber ( posix, zone ) =
    let
        year =
            Time.toYear zone posix

        p y =
            let
                yFloat =
                    toFloat y
            in
            (y + floor (yFloat / 4.0) - floor (yFloat / 100) + floor (yFloat / 400)) |> remainderBy 7

        weeks y =
            52
                + (if p y == 4 || p (y - 1) == 3 then
                    1

                   else
                    0
                  )

        leapYearOffset =
            if isLeapYear year then
                1

            else
                0

        dayOfMonth =
            Time.toDay zone posix

        dayOfYear =
            case Time.toMonth zone posix of
                Jan ->
                    dayOfMonth

                Feb ->
                    31 + dayOfMonth

                Mar ->
                    59 + leapYearOffset + dayOfMonth

                Apr ->
                    90 + leapYearOffset + dayOfMonth

                May ->
                    120 + leapYearOffset + dayOfMonth

                Jun ->
                    151 + leapYearOffset + dayOfMonth

                Jul ->
                    181 + leapYearOffset + dayOfMonth

                Aug ->
                    212 + leapYearOffset + dayOfMonth

                Sep ->
                    243 + leapYearOffset + dayOfMonth

                Oct ->
                    273 + leapYearOffset + dayOfMonth

                Nov ->
                    304 + leapYearOffset + dayOfMonth

                Dec ->
                    334 + leapYearOffset + dayOfMonth

        w =
            floor (toFloat (dayOfYear - dayOfWeek ( posix, zone ) + 10) / 7)
    in
    if w < 1 then
        weeks (year - 1)

    else if w > weeks year then
        1

    else
        w
