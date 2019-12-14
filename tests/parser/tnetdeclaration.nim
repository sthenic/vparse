import terminal
import strformat
import strutils

import ../../vparse/parser/parser
import ../../vparse/parser/ast
import ../../vparse/lexer/identifier
import ../../vparse/lexer/lexer

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test(title, stimuli: string, reference: PNode) =
   # var response: PNode
   cache = new_ident_cache()
   let response = parse_specific_grammar(stimuli, cache, NkNetDecl)

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


template new_identifier_node(kind: NodeKind, info: TLineInfo, str: string): untyped =
   new_identifier_node(kind, info, get_identifier(cache, str))


run_test("Simple wire declaration", "wire foo;"):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkIdentifier, li(1, 6), "foo"),
   ])

run_test("Simple wire declaration", "trireg (small) vectored [7:0] foo, bar[2:0], baz[5:MIN+2];"):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkIdentifier, li(1, 6), "foo"),
   ])

run_test("Simple wire declaration", "wire a = 23, b = 2, c = 2;"):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkIdentifier, li(1, 6), "foo"),
   ])


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
