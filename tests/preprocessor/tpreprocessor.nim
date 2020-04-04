import streams
import terminal
import strformat

import ../../src/vparsepkg/preprocessor
import ../lexer/constructors


var nof_passed = 0
var nof_failed = 0
var pp: Preprocessor
var cache = new_ident_cache()


template run_test(title, stimuli: string, reference: openarray[Token]) =
   var response: seq[Token] = @[]
   var tok: Token
   init(tok)
   open_preprocessor(pp, cache, "test_default", [""], new_string_stream(stimuli))
   while true:
      get_token(pp, tok)
      if tok.kind == TkEndOfFile:
         break
      add(response, tok)
   close_preprocessor(pp)
   detailed_compare(response, reference)


proc new_identifier(kind: TokenKind, line, col: int, identifier: string): Token =
   # Wrap the call to the identifier constructor to avoid passing the global
   # cache variable everywhere.
   new_identifier(kind, line, col, identifier, cache)


run_test("Default", """
HELLO
`define() thing
"""): [
   new_identifier(TkSymbol, 1, 0, "HELLO"),
   new_identifier(TkDirective, 2, 0, "define"),
   new_token(TkLparen, 2, 7),
   new_token(TkRparen, 2, 8),
   new_identifier(TkSymbol, 2, 10, "thing"),
]

