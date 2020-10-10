import terminal
import strformat

import ../../src/vparsepkg/parser

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test(title, stimuli: string, reference: PNode) =
   cache = new_ident_cache()
   let response = parse_specific_grammar(stimuli, cache, NkHierarchicalIdentifier)

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

Test suite: hierarchical identifier
-----------------------------------""")

# Run tests
run_test("Simple identifier", """
   an_identifier
"""):
   new_node(NkHierarchicalIdentifier, li(1, 4), @[
      new_identifier_node(NkIdentifier, li(1, 4), "an_identifier"),
   ])


run_test("Dot expressions", """
   global.local0.local1
"""):
   new_node(NkHierarchicalIdentifier, li(1, 4), @[
      new_node(NkDotExpression, li(1, 17), @[
         new_node(NkDotExpression, li(1, 10), @[
            new_identifier_node(NkIdentifier, li(1, 4), "global"),
            new_identifier_node(NkIdentifier, li(1, 11), "local0"),
         ]),
         new_identifier_node(NkIdentifier, li(1, 18), "local1"),
      ])
   ])


run_test("Complex identifier", """
   a[0].b.c[FOO].d
"""):
   new_node(NkHierarchicalIdentifier, li(1, 4), @[
      new_node(NkDotExpression, li(1, 17), @[
         new_node(NkBracketExpression, li(1, 12), @[
            new_node(NkDotExpression, li(1, 10), @[
               new_node(NkDotExpression, li(1, 8), @[
                  new_node(NkBracketExpression, li(1, 5), @[
                     new_identifier_node(NkIdentifier, li(1, 4), "a"),
                     new_inumber_node(NkIntLit, li(1, 6), "0", Base10, -1)
                  ]),
                  new_identifier_node(NkIdentifier, li(1, 9), "b"),
               ]),
               new_identifier_node(NkIdentifier, li(1, 11), "c"),
            ]),
            new_identifier_node(NkIdentifier, li(1, 13), "FOO"),
         ]),
         new_identifier_node(NkIdentifier, li(1, 18), "d"),
      ])
   ])


run_test("Complex identifier, ends w/ bracket expression (error)", """
   a.b[80].c.d[FOO]
"""):
   new_node(NkHierarchicalIdentifier, li(1, 4), @[
      new_node(NkDotExpression, li(2, 1), @[
         new_node(NkBracketExpression, li(1, 15), @[
            new_node(NkDotExpression, li(1, 13), @[
               new_node(NkDotExpression, li(1, 11), @[
                  new_node(NkBracketExpression, li(1, 7), @[
                     new_node(NkDotExpression, li(1, 5), @[
                        new_identifier_node(NkIdentifier, li(1, 4), "a"),
                        new_identifier_node(NkIdentifier, li(1, 6), "b"),
                     ]),
                     new_inumber_node(NkIntLit, li(1, 8), "80", Base10, -1)
                  ]),
                  new_identifier_node(NkIdentifier, li(1, 12), "c"),
               ]),
               new_identifier_node(NkIdentifier, li(1, 14), "d"),
            ]),
            new_identifier_node(NkIdentifier, li(1, 16), "FOO"),
         ]),
         new_node(NkExpectError, li(2, 1), @[
            new_error_node(NkTokenError, li(2, 1), "", "Expected token Symbol, got '[EOF]'")
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
