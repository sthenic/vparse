import terminal
import strformat

import ../../src/parser/parser
import ../../src/parser/ast
import ../../src/lexer/identifier

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test(title, stimuli: string, reference: PNode) =
   # var response: PNode
   cache = new_ident_cache()
   let response = parse_specific_grammar(stimuli, cache, NtListOfPortDeclarations)

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


template new_identifier_node(kind: NodeType, info: TLineInfo, str: string): untyped =
   new_identifier_node(kind, info, get_identifier(cache, str))


run_test("Single port (input)", """(
   input clk_i
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "input"),
         new_identifier_node(NtPortIdentifier, li(2, 10), "clk_i"),
      ])
   ])

run_test("Single port (inout)", """(
   inout data_io
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "inout"),
         new_identifier_node(NtPortIdentifier, li(2, 10), "data_io"),
      ])
   ])

run_test("Single port (output)", """(
   output data_o
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "output"),
         new_identifier_node(NtPortIdentifier, li(2, 11), "data_o"),
      ])
   ])

run_test("Single port (empty)", "()"):
   new_node(NtListOfPortDeclarations, li(1, 2))


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
