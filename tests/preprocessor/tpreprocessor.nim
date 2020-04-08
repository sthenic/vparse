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

   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      inc(nof_passed)
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      inc(nof_failed)
      detailed_compare(response, reference)


proc new_identifier(kind: TokenKind, line, col: int, identifier: string): Token =
   # Wrap the call to the identifier constructor to avoid passing the global
   # cache variable everywhere.
   new_identifier(kind, line, col, identifier, cache)


# run_test("Default", """
# HELLO
# `define aMAZing FOO
# `aMAZing
# `define MYMACRO ahs delightful `aMAZing \
#    `aMAZing
# this is `MYMACRO
# `define aMAZing bar
# testing `MYMACRO
# """): [
#    new_identifier(TkSymbol, 1, 0, "HELLO"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
#    new_identifier(TkModule, 4, 0, "module"),
# ]


run_test("Nested arguments", """
`define CONSTANT ABC
`define bar(x, y) foo `CONSTANT x y
`bar(`bar(3, `CONSTANT), bAz) (2)
"""): [
   new_identifier(TkSymbol, 3, 0, "foo"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
   new_identifier(TkModule, 4, 0, "module"),
]


# Print summary
styledWriteLine(stdout, styleBright, "\n----- SUMMARY -----")
var test_str = "test"
if nof_passed == 1:
   test_str.add(' ')
else:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_passed:<4} ", test_str,
                fgGreen, " PASSED")

test_str = "test"
if nof_failed == 1:
   test_str.add(' ')
else:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_failed:<4} ", test_str,
                fgRed, " FAILED")

styledWriteLine(stdout, styleBright, "-------------------")

quit(nof_failed)
