module SRParser exposing (run)

import Either exposing (Either(..))
import Grammar exposing (GExpr(..))
import Tokenizer exposing (Token(..))



{-
   https://discourse.elm-lang.org/t/parsers-with-error-recovery/6262/3
   https://www.cocolab.com/products/cocktail/doc.pdf/ell.pdf
   https://github.com/Janiczek/elm-grammar/tree/master/src
   https://guide.elm-lang.org/appendix/types_as_sets.html
   https://www.schoolofhaskell.com/user/bartosz/understanding-algebras
-}


type alias State =
    { sourceText : String
    , scanPointer : Int
    , end : Int
    , stack : List (Either Token GExpr)
    , committed : List GExpr
    }


{-|

    Run the parser on some input, returning a value of type state.
    The stack in the final state should be empty

    > SRParser.run "foo [i [j ABC]]"
    { committed = [GText ("foo "),GExpr "i" [GExpr "j" [GText "ABC"]]], end = 15, scanPointer = 15, sourceText = "foo [i [j ABC]]", stack = [] }

-}
run : String -> State
run input =
    loop (init input) nextState


init : String -> State
init str =
    { sourceText = str
    , scanPointer = 0
    , end = String.length str
    , stack = []
    , committed = []
    }


{-|

    If scanPointer == end, you are done.
    Otherwise, get a new token from the source text, reduce the stack,
    and shift the new token onto the stack.

    NOTE: the

-}
nextState : State -> Step State State
nextState state_ =
    let
        state =
            reduce (state_ |> Debug.log "STATE")
    in
    if state.scanPointer >= state.end then
        if state.stack == [] then
            Done (state |> (\st -> { st | committed = List.reverse st.committed }))

        else
            Loop (recoverFromError state)

    else
        case Tokenizer.get state.scanPointer (String.dropLeft state.scanPointer state.sourceText) of
            Err _ ->
                Done state

            Ok newToken ->
                Loop (shift newToken (reduce state))


recoverFromError state =
    case state.stack of
        (Left (Text str loc1)) :: (Left (Symbol "[" loc2)) :: rest ->
            { state
                | stack = Left (Symbol "]" loc1) :: state.stack
                , committed = GText "I corrected an unmatched '[' in the following expression: " :: state.committed
            }

        (Left (Symbol "[" loc1)) :: (Left (Text str loc2)) :: (Left (Symbol "[" loc3)) :: rest ->
            { state
                | stack = Left (Symbol "]" loc1) :: state.stack
                , scanPointer = loc1.begin
                , committed = GText "I corrected an unmatched '[' in the following expression: " :: state.committed
            }

        _ ->
            { state | stack = Left (Symbol "]" { begin = state.scanPointer, end = state.scanPointer + 1 }) :: state.stack, committed = GText "Error! I added a bracket at then end of what follows: " :: state.committed }


{-|

    Shift the new token onto the stack and advance the scan pointer

-}
shift : Token -> State -> State
shift token state =
    { state | scanPointer = state.scanPointer + Tokenizer.length token, stack = Either.Left token :: state.stack }


{-|

    Function reduce matches patterns at the top of the stack, then from the given instance
    of that pattern creates a GExpr.  Let the stack be (a::b::..::rest).  If rest
    is empty, push the new GExpr onto state.committed.  If not, push (Right GExpr)
    onto rest.  The stack now reads (Right GExpr)::rest.

    Note that the stack has type List (Either Token GExpr).

    NOTE: The pattern -> action clauses below invert productions in the grammar and so
    one should be able to deduce them mechanically from the grammar.

-}
reduce : State -> State
reduce state =
    case state.stack of
        (Left (Text str loc)) :: [] ->
            reduceAux (GText str) [] state

        (Left (Symbol "]" loc1)) :: (Left (Text str loc2)) :: (Left (Symbol "[" loc3)) :: rest ->
            reduceAux (makeGExpr str) rest state

        (Left (Symbol "]" loc1)) :: (Right gexpr) :: (Left (Text name loc2)) :: (Left (Symbol "[" loc3)) :: rest ->
            reduceAux (makeGExpr2 name gexpr) rest state

        _ ->
            state


makeGExpr2 name gexpr =
    GExpr (String.trim name) [ gexpr ]


makeGExpr str =
    let
        words =
            String.words str

        prefix =
            List.head words |> Maybe.withDefault "empty"
    in
    GExpr prefix (List.map GText (List.drop 1 words))


reduceAux newGExpr rest state =
    if rest == [] then
        { state | stack = [], committed = newGExpr :: state.committed }

    else
        { state | stack = Right newGExpr :: rest }


type Step state a
    = Loop state
    | Done a


loop : state -> (state -> Step state a) -> a
loop s f =
    case f s of
        Loop s_ ->
            loop s_ f

        Done b ->
            b
