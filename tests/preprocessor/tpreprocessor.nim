import streams
import terminal
import strformat

import ../../src/vparsepkg/preprocessor


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


template init(t: Token, kind: TokenKind, line, col: int) =
   init(t)
   t.line = line
   t.col = col
   t.kind = kind


proc new_identifier(kind: TokenKind, line, col: int, identifier: string): Token =
   init(result, kind, line, col)
   result.identifier = cache.get_identifier(identifier)


run_test("Default", """
HELLOz
"""): [
   new_identifier(TkSymbol, 1, 0, "HELLO")
]

