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
   let response = parse_specific_grammar(stimuli, cache, NtEventDecl)

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


run_test("Event declaration, single identifier", "event foo;"):
   new_node(NtEventDecl, li(1, 1), @[
      new_identifier_node(NtIdentifier, li(1, 7), "foo"),
   ])

run_test("Event declaration, multiple identifiers", "event foo, bar;"):
   new_node(NtEventDecl, li(1, 1), @[
      new_identifier_node(NtIdentifier, li(1, 7), "foo"),
      new_identifier_node(NtIdentifier, li(1, 12), "bar"),
   ])

run_test("Event declaration, dimension", "event foo[7:0];"):
   new_node(NtEventDecl, li(1, 1), @[
      new_node(NtArrayIdentifer, li(1, 7), @[
         new_identifier_node(NtIdentifier, li(1, 7), "foo"),
         new_node(NtRange, li(1, 10), @[
            new_inumber_node(NtIntLit, li(1, 11), 7, "7", Base10, -1),
            new_inumber_node(NtIntLit, li(1, 13), 0, "0", Base10, -1)
         ])
      ])
   ])

run_test("Event declaration, multiple dimensions", "event foo[7:0][3:0];"):
   new_node(NtEventDecl, li(1, 1), @[
      new_node(NtArrayIdentifer, li(1, 7), @[
         new_identifier_node(NtIdentifier, li(1, 7), "foo"),
         new_node(NtRange, li(1, 10), @[
            new_inumber_node(NtIntLit, li(1, 11), 7, "7", Base10, -1),
            new_inumber_node(NtIntLit, li(1, 13), 0, "0", Base10, -1)
         ]),
         new_node(NtRange, li(1, 15), @[
            new_inumber_node(NtIntLit, li(1, 16), 3, "3", Base10, -1),
            new_inumber_node(NtIntLit, li(1, 18), 0, "0", Base10, -1)
         ])
      ])
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
