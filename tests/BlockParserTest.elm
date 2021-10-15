module BlockParserTest exposing (suiteL1BlockParser)

import Block.Block exposing (BlockStatus(..), SBlock(..))
import Block.Parser
import Expect
import Lang.Lang exposing (Lang(..))
import Test exposing (..)


run lang str =
    Block.Parser.run lang 0 (String.lines str) |> .committed


suiteL1BlockParser : Test
suiteL1BlockParser =
    describe "parsing L1 blocks"
        [ test "(1) " <|
            \_ ->
                run L1 "ABC"
                    |> Expect.equal
                        [ SParagraph [ "ABC" ] { status = BlockComplete, begin = 0, end = 0, id = "0", indent = 0 } ]
        , test "(2) " <|
            \_ ->
                run L1 "ABC\nDEF"
                    |> Expect.equal [ SParagraph [ "ABC", "DEF" ] { status = BlockComplete, begin = 0, end = 1, id = "0", indent = 0 } ]
        , test "(3) " <|
            \_ ->
                run L1 "ABC\nDEF\n\nXYZ"
                    |> Expect.equal
                        [ SParagraph [ "ABC", "DEF", "" ] { status = BlockComplete, begin = 0, end = 2, id = "0", indent = 0 }
                        , SParagraph [ "XYZ" ]
                            { status = BlockComplete, begin = 3, end = 3, id = "1", indent = 0 }
                        ]
        , test "(4) " <|
            \_ ->
                run L1 "ABC\nDEF\n\n\nXYZ"
                    |> Expect.equal [ SParagraph [ "ABC", "DEF", "" ] { status = BlockComplete, begin = 0, end = 2, id = "0", indent = 0 }, SParagraph [ "XYZ" ] { status = BlockComplete, begin = 4, end = 4, id = "1", indent = 0 } ]
        , test "(5) " <|
            \_ ->
                run L1 "| indent\n   abc\n   def\nxyz"
                    |> Expect.equal
                        [ SBlock "indent"
                            [ SParagraph [ "   abc", "   def" ] { status = BlockComplete, begin = 1, end = 2, id = "1", indent = 3 } ]
                            { status = BlockComplete, begin = 0, end = 2, id = "0", indent = 0 }
                        , SParagraph [ "xyz" ]
                            { status = BlockComplete, begin = 3, end = 3, id = "1", indent = 0 }
                        ]
        , test "(6) " <|
            \_ ->
                run L1 "|| code\n   a[i] = 0"
                    |> Expect.equal [ SVerbatimBlock "code" [ "   a[i] = 0" ] { status = BlockComplete, begin = 0, end = 1, id = "0", indent = 0 } ]
        , test "(7) " <|
            \_ ->
                run L1 "|| code\n   a[i] = 0\n      b[i] = 1\n\nabc"
                    |> Expect.equal
                        [ SVerbatimBlock "code" [ "   a[i] = 0", "      b[i] = 1" ] { status = BlockComplete, begin = 0, end = 2, id = "0", indent = 0 }
                        , SParagraph [ "abc" ]
                            { status = BlockComplete, begin = 4, end = 4, id = "1", indent = 0 }
                        ]
        , test
            "(8) Nested blocks"
          <|
            \_ ->
                run L1 "| foo\n   a\n   b\n   | bar\n      c\n      d"
                    |> Expect.equal
                        [ SBlock "foo"
                            [ SParagraph [ "   a", "   b" ] { status = BlockComplete, begin = 1, end = 2, id = "1", indent = 3 } ]
                            { status = BlockComplete, begin = 0, end = 2, id = "0", indent = 0 }
                        , SBlock "bar"
                            [ SParagraph [ "      c", "      d" ]
                                { status = BlockComplete, begin = 4, end = 5, id = "4", indent = 6 }
                            ]
                            { status = BlockComplete, begin = 3, end = 5, id = "1", indent = 3 }
                        ]
        , test
            "(9) Nested blocks"
          <|
            \_ ->
                run L1 "| foo\n   AAA\n      PQR"
                    |> Expect.equal
                        [ SBlock "foo"
                            [ SParagraph [ "   AAA" ] { status = BlockComplete, begin = 1, end = 1, id = "1", indent = 3 }
                            , SParagraph [ "      PQR" ]
                                { status = BlockComplete, begin = 2, end = 2, id = "1", indent = 6 }
                            ]
                            { status = BlockComplete, begin = 0, end = 1, id = "0", indent = 0 }
                        ]
        ]
