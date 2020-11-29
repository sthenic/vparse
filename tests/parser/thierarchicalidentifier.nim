import terminal
import strformat

import ../../src/vparsepkg/parser

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test(title: string, allow_bracket_tail: bool, stimuli: string, reference: PNode) =
   cache = new_ident_cache()
   let response = parse_specific_grammar(stimuli, cache, NkHierarchicalIdentifier, allow_bracket_tail)

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
run_test("Simple identifier", false, """
   an_identifier
"""):
   new_identifier_node(NkIdentifier, li(1, 4), "an_identifier")


run_test("Simple identifier w/ constant (allowed)", true, """
   foo[5])
"""):
   new_node(NkBracketExpression, li(1, 4), @[
      new_identifier_node(NkIdentifier, li(1, 4), "foo"),
      new_inumber_node(NkIntLit, li(1, 8), "5", Base10, -1),
   ])


run_test("Simple identifier w/ range (not allowed)", false, """
   foo[5:0]
"""):
   new_node(NkBracketExpression, li(1, 4), @[
      new_identifier_node(NkIdentifier, li(1, 4), "foo"),
      new_node(NkInfix, li(1, 9), @[
         new_identifier_node(NkIdentifier, li(1, 9), ":"),
         new_inumber_node(NkIntLit, li(1, 8), "5", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 10), "0", Base10, -1)
      ]),
      new_node(NkExpectError, li(2, 1), @[
         new_error_node(NkTokenError, li(2, 1), "", "Expected token Symbol, got '[EOF]'")
      ])
   ])


run_test("Simple identifier w/ range (allowed)", true, """
   foo[5:0]
"""):
   new_node(NkBracketExpression, li(1, 4), @[
      new_identifier_node(NkIdentifier, li(1, 4), "foo"),
      new_node(NkInfix, li(1, 9), @[
         new_identifier_node(NkIdentifier, li(1, 9), ":"),
         new_inumber_node(NkIntLit, li(1, 8), "5", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 10), "0", Base10, -1)
      ])
   ])


run_test("Simple identifier w/ range, two infix nodes", true, """
   foo[FOO-1][5:0]
"""):
   new_node(NkBracketExpression, li(1, 4), @[
      new_node(NkBracketExpression, li(1, 4), @[
         new_identifier_node(NkIdentifier, li(1, 4), "foo"),
         new_node(NkInfix, li(1, 11), @[
            new_identifier_node(NkIdentifier, li(1, 11), "-"),
            new_identifier_node(NkIdentifier, li(1, 8), "FOO"),
            new_inumber_node(NkIntLit, li(1, 12), "1", Base10, -1)
         ]),
      ]),
      new_node(NkInfix, li(1, 16), @[
         new_identifier_node(NkIdentifier, li(1, 16), ":"),
         new_inumber_node(NkIntLit, li(1, 15), "5", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 17), "0", Base10, -1)
      ])
   ])


run_test("Simple identifier w/ range, two ranges (stops at first)", true, """
   foo[3:0][5:0]
"""):
   new_node(NkBracketExpression, li(1, 4), @[
      new_identifier_node(NkIdentifier, li(1, 4), "foo"),
      new_node(NkInfix, li(1, 9), @[
         new_identifier_node(NkIdentifier, li(1, 9), ":"),
         new_inumber_node(NkIntLit, li(1, 8), "3", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 10), "0", Base10, -1)
      ])
   ])


run_test("Simple identifier w/ range '+:'", true, """
   foo[FOO-1][0 +: 3][4]
"""):
   new_node(NkBracketExpression, li(1, 4), @[
      new_node(NkBracketExpression, li(1, 4), @[
         new_identifier_node(NkIdentifier, li(1, 4), "foo"),
         new_node(NkInfix, li(1, 11), @[
            new_identifier_node(NkIdentifier, li(1, 11), "-"),
            new_identifier_node(NkIdentifier, li(1, 8), "FOO"),
            new_inumber_node(NkIntLit, li(1, 12), "1", Base10, -1)
         ]),
      ]),
      new_node(NkInfix, li(1, 17), @[
         new_identifier_node(NkIdentifier, li(1, 17), "+:"),
         new_inumber_node(NkIntLit, li(1, 15), "0", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 20), "3", Base10, -1)
      ])
   ])


run_test("Simple identifier w/ range '+:'", true, """
   foo[FOO-1][15 -: 8][4]
"""):
   new_node(NkBracketExpression, li(1, 4), @[
      new_node(NkBracketExpression, li(1, 4), @[
         new_identifier_node(NkIdentifier, li(1, 4), "foo"),
         new_node(NkInfix, li(1, 11), @[
            new_identifier_node(NkIdentifier, li(1, 11), "-"),
            new_identifier_node(NkIdentifier, li(1, 8), "FOO"),
            new_inumber_node(NkIntLit, li(1, 12), "1", Base10, -1)
         ]),
      ]),
      new_node(NkInfix, li(1, 18), @[
         new_identifier_node(NkIdentifier, li(1, 18), "-:"),
         new_inumber_node(NkIntLit, li(1, 15), "15", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 21), "8", Base10, -1)
      ])
   ])


run_test("Dot expressions", false, """
   top.local0.local1
"""):
   new_node(NkDotExpression, li(1, 4), @[
      new_node(NkDotExpression, li(1, 4), @[
         new_identifier_node(NkIdentifier, li(1, 4), "top"),
         new_identifier_node(NkIdentifier, li(1, 8), "local0"),
      ]),
      new_identifier_node(NkIdentifier, li(1, 15), "local1"),
   ])


run_test("Error w/ keyword as the first identifier", false, """
   wire.foo
"""):
   new_node(NkExpectError, li(1, 4), @[
      new_error_node(NkTokenError, li(1, 4), "Expected token Symbol, got 'wire'.", ""),
      new_error_node(NkTokenError, li(1, 8), "Expected token Symbol, got '.'.", "")
   ])


run_test("Complex identifier", false, """
   a[0].b.c[FOO].d
"""):
   new_node(NkDotExpression, li(1, 4), @[
      new_node(NkBracketExpression, li(1, 4), @[
         new_node(NkDotExpression, li(1, 4), @[
            new_node(NkDotExpression, li(1, 4), @[
               new_node(NkBracketExpression, li(1, 4), @[
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


run_test("Complex identifier, ends w/ bracket expression (not allowed)", false, """
   a.b[80].c.d[FOO]
"""):
   new_node(NkBracketExpression, li(1, 4), @[
      new_node(NkDotExpression, li(1, 4), @[
         new_node(NkDotExpression, li(1, 4), @[
            new_node(NkBracketExpression, li(1, 4), @[
               new_node(NkDotExpression, li(1, 4), @[
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
      new_node(NkExpectError, li(2, 1), @[
         new_error_node(NkTokenError, li(2, 1), "", "Expected token Symbol, got '[EOF]'")
      ])
   ])


run_test("Complex identifier, ends w/ bracket expression (allowed)", true, """
   a.b[80].c.d[FOO][4][3][1+:16]
"""):
   new_node(NkBracketExpression, li(1, 4), @[
      new_node(NkBracketExpression, li(1, 4), @[
         new_node(NkBracketExpression, li(1, 4), @[
            new_node(NkBracketExpression, li(1, 4), @[
               new_node(NkDotExpression, li(1, 4), @[
                  new_node(NkDotExpression, li(1, 4), @[
                     new_node(NkBracketExpression, li(1, 4), @[
                        new_node(NkDotExpression, li(1, 4), @[
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
            new_inumber_node(NkIntLit, li(1, 21), "4", Base10, -1),
         ]),
         new_inumber_node(NkIntLit, li(1, 24), "3", Base10, -1),
      ]),
      new_node(NkInfix, li(1, 28), @[
         new_identifier_node(NkIdentifier, li(1, 28), "+:"),
         new_inumber_node(NkIntLit, li(1, 27), "1", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 30), "16", Base10, -1)
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
