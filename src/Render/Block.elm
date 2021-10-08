module Render.Block exposing (Settings, render)

import Block.State
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Markup.Block exposing (Block(..))
import Markup.Debugger exposing (debug3)
import Render.AST2
import Render.Math
import Render.MathMacro
import Render.Text
import Utility


type alias Settings =
    { width : Int }



-- Internal.MathMacro.evalStr latexState.mathMacroDictionary str


render : Int -> Settings -> Block.State.Accumulator -> List Block -> List (Element msg)
render generation settings accumulator blocks =
    List.map (renderBlock generation settings accumulator) blocks


renderBlock : Int -> Settings -> Block.State.Accumulator -> Block -> Element msg
renderBlock generation settings accumulator block =
    case block of
        Paragraph textList _ ->
            paragraph
                []
                (List.map (Render.Text.render generation settings accumulator) textList)

        VerbatimBlock name lines _ _ ->
            case Dict.get name verbatimBlockDict of
                Nothing ->
                    error ("Unimplemented verbatim block: " ++ name)

                Just f ->
                    f generation settings accumulator lines

        Block name blocks _ ->
            case Dict.get name blockDict of
                Nothing ->
                    error ("Unimplemented block: " ++ name)

                Just f ->
                    f generation settings accumulator blocks

        BError desc ->
            error desc


error str =
    paragraph [ Background.color (rgb255 250 217 215) ] [ text str ]


verbatimBlockDict : Dict String (Int -> Settings -> Block.State.Accumulator -> List String -> Element msg)
verbatimBlockDict =
    Dict.fromList
        [ ( "code", \g s a lines -> codeBlock g s a lines )
        , ( "math", \g s a lines -> mathBlock g s a lines )
        , ( "equation", \g s a lines -> equation g s a lines )
        , ( "align", \g s a lines -> aligned g s a lines )
        , ( "mathmacro", \g s a lines -> Element.none )
        ]


blockDict : Dict String (Int -> Settings -> Block.State.Accumulator -> List Block -> Element msg)
blockDict =
    Dict.fromList
        [ ( "quotation", \g s a blocks -> quotationBlock g s a blocks )
        , ( "item", \g s a blocks -> item g s a blocks )
        , ( "title", \g s a blocks -> Element.none )
        , ( "heading1", \g s a blocks -> heading1 g s a blocks )
        , ( "heading2", \g s a blocks -> heading2 g s a blocks )
        , ( "heading3", \g s a blocks -> heading3 g s a blocks )
        , ( "heading4", \g s a blocks -> heading4 g s a blocks )
        ]


heading1 : Int -> Settings -> Block.State.Accumulator -> List Block -> Element msg
heading1 g s a blocks =
    simpleElement [ Font.size 30, makeId blocks ] g s a blocks


heading2 : Int -> Settings -> Block.State.Accumulator -> List Block -> Element msg
heading2 g s a textList =
    simpleElement [ Font.size 22, makeId textList ] g s a textList


heading3 : Int -> Settings -> Block.State.Accumulator -> List Block -> Element msg
heading3 g s a textList =
    simpleElement [ Font.size 18, makeId textList ] g s a textList


heading4 : Int -> Settings -> Block.State.Accumulator -> List Block -> Element msg
heading4 g s a textList =
    simpleElement [ Font.size 14, Font.italic, Font.bold, makeId textList ] g s a textList


simpleElement formatList g s a blocks =
    Element.paragraph formatList (List.map (renderBlock g s a) (debug3 "XX, block in quotation" blocks))


makeId : List Block -> Element.Attribute msg
makeId blockList =
    Utility.elementAttribute "id" (Render.AST2.stringValueOfBlockList blockList |> makeSlug)


makeSlug : String -> String
makeSlug str =
    str |> String.toLower |> String.replace " " "-"


codeBlock : Int -> Settings -> Block.State.Accumulator -> List String -> Element msg
codeBlock generation settings accumulator textList =
    column
        [ Font.family
            [ Font.typeface "Inconsolata"
            , Font.monospace
            ]
        , Font.color codeColor
        , paddingEach { left = 0, right = 0, top = 0, bottom = 8 }
        , spacing 6
        ]
        (List.map (\t -> el [] (text t)) (List.map (String.dropLeft 0) textList))


mathBlock : Int -> Settings -> Block.State.Accumulator -> List String -> Element msg
mathBlock generation settings accumulator textList =
    Render.Math.mathText generation Render.Math.DisplayMathMode (String.join "\n" textList |> Render.MathMacro.evalStr accumulator.macroDict)



-- Internal.MathMacro.evalStr latexState.mathMacroDictionary str


prepareMathLines : Block.State.Accumulator -> List String -> String
prepareMathLines accumulator stringList =
    stringList
        |> List.filter (\line -> String.left 6 (String.trimLeft line) /= "\\label")
        |> String.join "\n"
        |> Render.MathMacro.evalStr accumulator.macroDict


equation : Int -> Settings -> Block.State.Accumulator -> List String -> Element msg
equation generation settings accumulator textList =
    -- Render.Math.mathText generation Render.Math.DisplayMathMode (String.join "\n" textList |> MiniLaTeX.MathMacro.evalStr accumulator.macroDict)
    Render.Math.mathText generation Render.Math.DisplayMathMode (prepareMathLines accumulator textList)


aligned : Int -> Settings -> Block.State.Accumulator -> List String -> Element msg
aligned generation settings accumulator textList =
    Render.Math.mathText generation Render.Math.DisplayMathMode ("\\begin{aligned}\n" ++ (String.join "\n" textList |> Render.MathMacro.evalStr accumulator.macroDict) ++ "\n\\end{aligned}")


quotationBlock : Int -> Settings -> Block.State.Accumulator -> List Block -> Element msg
quotationBlock generation settings accumulator blocks =
    column
        [ paddingEach { left = 18, right = 0, top = 0, bottom = 8 }
        ]
        (List.map (renderBlock generation settings accumulator) (debug3 "XX, block in quotation" blocks))


item : Int -> Settings -> Block.State.Accumulator -> List Block -> Element msg
item generation settings accumulator blocks =
    row [ width fill, paddingEach { left = 18, right = 0, top = 0, bottom = 0 } ]
        [ el [ height fill ] none
        , column [ width fill ]
            [ row [ width fill, spacing 8 ]
                [ itemSymbol
                , row [ width fill ] (List.map (renderBlock generation settings accumulator) blocks)
                ]
            ]
        ]


itemSymbol =
    el [ Font.bold, alignTop, moveUp 1, Font.size 18 ] (text "•")


codeColor =
    -- E.rgb 0.2 0.5 1.0
    rgb 0.4 0 0.8


notImplemented str =
    el [ Font.color (rgb255 40 40 255) ] (text <| "not implemented: " ++ str)
