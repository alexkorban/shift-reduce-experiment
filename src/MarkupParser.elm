module MarkupParser exposing (run)

import Either
import Markup.AST as AST
import Markup.Common exposing (Step(..), loop)
import Markup.Debugger exposing (..)
import Markup.L1 as L1
import Markup.Markdown as Markdown
import Markup.MiniLaTeX as MiniLaTeX
import Markup.State exposing (State)
import Markup.Token as Token exposing (Token)
import Markup.Tokenizer as Tokenizer exposing (Lang(..))



{-
   https://discourse.elm-lang.org/t/parsers-with-error-recovery/6262/3
   https://www.cocolab.com/products/cocktail/doc.pdf/ell.pdf
   https://github.com/Janiczek/elm-grammar/tree/master/src
   https://guide.elm-lang.org/appendix/types_as_sets.html
   https://www.schoolofhaskell.com/user/bartosz/understanding-algebras
-}
--{-| Assume that lines in block are not terminated by newlines.  Is this correct? -}
--parse : Lang -> AST.BlockData -> List {expr: AST.Expr, meta: AST.Meta}
--parse lang blockData =
--    let
--        expressions = run lang (String.join "\n" blockData.content)
--    in
--      List.map (\e -> )


{-|

    Run the parser on some input, returning a value of type state.
    The stack in the final state should be empty

    > MarkupParser.run "foo [i [j ABC]]"
    { committed = [GText ("foo "),GExpr "i" [GExpr "j" [GText "ABC"]]], end = 15, scanPointer = 15, sourceText = "foo [i [j ABC]]", stack = [] }

-}
run : Lang -> String -> State
run lang input =
    loop (init input) (nextState lang) |> debug3 "FINAL STATE"


init : String -> State
init str =
    { sourceText = str
    , scanPointer = 0
    , end = String.length str
    , stack = []
    , committed = []
    , count = 0
    }


{-|

    If scanPointer == end, you are done.
    Otherwise, get a new token from the source text, reduce the stack,
    and shift the new token onto the stack.

    NOTES:

        - The reduce function is applied in two places: the top-level
          function nextState and in the Loop branch of processToken.

        - In addition, there is the function reduceFinal, which is applied
          in the first branch of auxiliary function nextState_

        - Both reduce and reduceFinal call out to corresponding versions
          of these functions for the language being processed.  See folders
          L1, MiniLaTeX and Markdown

       - The dependency on language is via (1) the two reduce functions and
         (2) the tokenization function. In particular, there is no
         language dependency, other than the lang argument,
         in the main parser module (this module).

-}
nextState : Lang -> State -> Step State State
nextState lang state_ =
    { state_ | count = state_.count + 1 }
        |> debug2 ("STATE (" ++ String.fromInt (state_.count + 1) ++ ")")
        |> reduce lang
        |> nextState_ lang


nextState_ : Lang -> State -> Step State State
nextState_ lang state =
    if state.scanPointer >= state.end then
        finalize lang (reduceFinal lang state |> debug1 "reduceFinal (APPL)")

    else
        processToken lang state


finalize : Lang -> State -> Step State State
finalize lang state =
    if state.stack == [] then
        Done (state |> (\st -> { st | committed = List.reverse st.committed })) |> debug2 "ReduceFinal (1)"

    else
        recoverFromError lang state |> debug2 "ReduceFinal (2)"


processToken : Lang -> State -> Step State State
processToken lang state =
    case Tokenizer.get lang state.scanPointer (String.dropLeft state.scanPointer state.sourceText) of
        Err _ ->
            -- Oops, exit
            Done state

        Ok newToken ->
            -- Process the token: reduce the stack, then shift the token onto it.
            Loop (shift newToken (reduce lang state))


reduceFinal : Lang -> State -> State
reduceFinal lang =
    case lang of
        L1 ->
            L1.reduceFinal

        MiniLaTeX ->
            MiniLaTeX.reduceFinal

        Markdown ->
            Markdown.reduceFinal


recoverFromError : Lang -> State -> Step State State
recoverFromError lang state =
    case lang of
        L1 ->
            L1.recoverFromError state

        MiniLaTeX ->
            MiniLaTeX.recoverFromError state

        Markdown ->
            Markdown.recoverFromError state


{-|

    Shift the new token onto the stack and advance the scan pointer

-}
shift : Token -> State -> State
shift token state =
    { state | scanPointer = state.scanPointer + Token.length token, stack = Either.Left token :: state.stack }


{-|

    Function reduce matches patterns at the top of the stack, then from the given instance
    of that pattern creates a GExpr.  Let the stack be (a::b::..::rest).  If rest
    is empty, push the new GExpr onto state.committed.  If not, push (Right GExpr)
    onto rest.  The stack now reads (Right GExpr)::rest.

    Note that the stack has type List (Either Token GExpr).

    NOTE: The pattern -> action clauses below invert productions in the grammar and so
    one should be able to deduce them mechanically from the grammar.

-}
reduce : Lang -> State -> State
reduce lang state =
    case lang of
        L1 ->
            L1.reduce state

        MiniLaTeX ->
            MiniLaTeX.reduce state

        Markdown ->
            Markdown.reduce state
