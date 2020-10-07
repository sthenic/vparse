import terminal
import strformat

import ../../src/vparsepkg/parser
import ../../src/vparsepkg/ast
import ../../src/vparsepkg/identifier
import ../../src/vparsepkg/lexer

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test(title, stimuli: string, reference: PNode) =
   # var response: PNode
   cache = new_ident_cache()
   let response = parse_specific_grammar(stimuli, cache, NkEventDecl)

   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
      detailed_compare(response, reference)


proc li(line: uint16, col: int16): Location =
   result = Location(file: 1, line: line, col: col - 1)


template new_identifier_node(kind: NodeKind, loc: Location, str: string): untyped =
   new_identifier_node(kind, loc, get_identifier(cache, str))

# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: event declaration
-----------------------------""")

# Run tests
run_test("Event declaration, single identifier", "event foo;"):
   new_node(NkEventDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 7), "foo"),
   ])

run_test("Event declaration, multiple identifiers", "event foo, bar;"):
   new_node(NkEventDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 7), "foo"),
      new_identifier_node(NkIdentifier, li(1, 12), "bar"),
   ])

run_test("Event declaration, dimension", "event foo[7:0];"):
   new_node(NkEventDecl, li(1, 1), @[
      new_node(NkArrayIdentifer, li(1, 7), @[
         new_identifier_node(NkIdentifier, li(1, 7), "foo"),
         new_node(NkRange, li(1, 10), @[
            new_inumber_node(NkIntLit, li(1, 11), "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 13), "0", Base10, -1)
         ])
      ])
   ])

run_test("Event declaration, multiple dimensions", "event foo[7:0][3:0];"):
   new_node(NkEventDecl, li(1, 1), @[
      new_node(NkArrayIdentifer, li(1, 7), @[
         new_identifier_node(NkIdentifier, li(1, 7), "foo"),
         new_node(NkRange, li(1, 10), @[
            new_inumber_node(NkIntLit, li(1, 11), "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 13), "0", Base10, -1)
         ]),
         new_node(NkRange, li(1, 15), @[
            new_inumber_node(NkIntLit, li(1, 16), "3", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 18), "0", Base10, -1)
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
