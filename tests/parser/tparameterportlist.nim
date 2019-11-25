import terminal
import strformat
import strutils

import ../../src/parser/parser
import ../../src/parser/ast
import ../../src/lexer/identifier
import ../../src/lexer/lexer

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test(title, stimuli: string, reference: PNode) =
   # var response: PNode
   cache = new_ident_cache()
   let response = parse_specific_grammar(stimuli, cache, NtListOfPorts)

   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
      detailed_compare(response, reference)


proc li(line: uint16, col: int16): TLineInfo =
   result = new_line_info(line, col - 1)


# Wrapper for a constant primary expression
template cprim(n: PNode): PNode =
   n


template new_identifier_node(kind: NodeType, info: TLineInfo, str: string): untyped =
   new_identifier_node(kind, info, get_identifier(cache, str))


run_test("test_0", """
#(
   parameter signed [10:50]
      myparam = 2,
      param2 = {3,2,1},
      multi = (2:1:2),
      binpar = {MY_MAN{3'b01X}},
   parameter [7:0] stuff = AMAZING,
   parameter real N_sa$ICE = 3.4e-1,
   parameter signed A_func = myfunc(4, 5, SOMETHING),
   parameter [myparam-1:0] infantry = (32'd2),
   parameter MYPAR = ((THING == 9) ? AWESOME : STUFF) - 8'h5A,
   parameter /*blocking comment */ THING = &(* noice *) 8,
   // This is a comment
   parameter SECOND = 7 + (*impressive*) (thing - (*with *) (78))
)""", nil)


run_test("test_1", """
#(
   parameter ABC = &3 + -10 / 45
)""", nil)


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
