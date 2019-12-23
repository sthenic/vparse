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
   let response = parse_specific_grammar(stimuli, cache, NkRegDecl)

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


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: variable declaration
--------------------------------""")

# Run tests
run_test("Simple reg declaration", "reg foo;"):
   new_node(NkRegDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 5), "foo"),
   ])


run_test("Signed reg declaration", """
reg signed signed_reg;
"""):
   new_node(NkRegDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 5), "signed"),
      new_identifier_node(NkIdentifier, li(1, 12), "signed_reg"),
   ])


run_test("Ranged reg declaration", """
reg [7:0] ranged_reg;
"""):
   new_node(NkRegDecl, li(1, 1), @[
      new_node(NkRange, li(1, 5), @[
         new_inumber_node(NkIntLit, li(1, 6), 7, "7", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 8), 0, "0", Base10, -1)
      ]),
      new_identifier_node(NkIdentifier, li(1, 11), "ranged_reg")
   ])


run_test("Signed, ranged reg declaration", """
reg signed [ADDR-1:0] full_reg;
"""):
   new_node(NkRegDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 5), "signed"),
      new_node(NkRange, li(1, 12), @[
         new_node(NkInfix, li(1, 17), @[
            new_identifier_node(NkIdentifier, li(1, 17), "-"),
            new_identifier_node(NkIdentifier, li(1, 13), "ADDR"),
            new_inumber_node(NkIntLit, li(1, 18), 1, "1", Base10, -1)
         ]),
         new_inumber_node(NkIntLit, li(1, 20), 0, "0", Base10, -1)
      ]),
      new_identifier_node(NkIdentifier, li(1, 23), "full_reg")
   ])


run_test("Multiple registers in one declaration", """
reg foo, bar, baz;
"""):
   new_node(NkRegDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 5), "foo"),
      new_identifier_node(NkIdentifier, li(1, 10), "bar"),
      new_identifier_node(NkIdentifier, li(1, 15), "baz")
   ])


run_test("Variable types: assignment (default value)", """
reg with_default = 1'b0;
"""):
   new_node(NkRegDecl, li(1, 1), @[
      new_node(NkAssignment, li(1, 5), @[
         new_identifier_node(NkIdentifier, li(1, 5), "with_default"),
         new_inumber_node(NkUIntLit, li(1, 20), 0, "0", Base2, 1)
      ]),
   ])


run_test("Variable types: dimension (array)", """
reg array[7:0][2:0];
"""):
   new_node(NkRegDecl, li(1, 1), @[
      new_node(NkArrayIdentifer, li(1, 5), @[
         new_identifier_node(NkIdentifier, li(1, 5), "array"),
         new_node(NkRange, li(1, 10), @[
            new_inumber_node(NkIntLit, li(1, 11), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 13), 0, "0", Base10, -1)
         ]),
         new_node(NkRange, li(1, 15), @[
            new_inumber_node(NkIntLit, li(1, 16), 2, "2", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 18), 0, "0", Base10, -1)
         ]),
      ]),
   ])


# Integer declarations
run_test("Integer declaration, single identifier", "integer foo;"):
   new_node(NkIntegerDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 9), "foo"),
   ])


run_test("Integer declaration, multiple identifiers", "integer FOO, BAR;"):
   new_node(NkIntegerDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 9), "FOO"),
      new_identifier_node(NkIdentifier, li(1, 14), "BAR")
   ])


run_test("Integer declaration, assignment", "integer foo = 8 + 8;"):
   new_node(NkIntegerDecl, li(1, 1), @[
      new_node(NkAssignment, li(1, 9), @[
         new_identifier_node(NkIdentifier, li(1, 9), "foo"),
         new_node(NkInfix, li(1, 17), @[
            new_identifier_node(NkIdentifier, li(1, 17), "+"),
            new_inumber_node(NkIntLit, li(1, 15), 8, "8", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 19), 8, "8", Base10, -1)
         ])
      ])
   ])


run_test("Integer declaration, dimension", "integer i_ranged[7:0];"):
   new_node(NkIntegerDecl, li(1, 1), @[
      new_node(NkArrayIdentifer, li(1, 9), @[
         new_identifier_node(NkIdentifier, li(1, 9), "i_ranged"),
         new_node(NkRange, li(1, 17), @[
            new_inumber_node(NkIntLit, li(1, 18), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 20), 0, "0", Base10, -1)
         ])
      ])
   ])


run_test("Integer declaration, hybrid", "integer i = 0, j[7:0][3:0];"):
   new_node(NkIntegerDecl, li(1, 1), @[
      new_node(NkAssignment, li(1, 9), @[
         new_identifier_node(NkIdentifier, li(1, 9), "i"),
         new_inumber_node(NkIntLit, li(1, 13), 0, "0", Base10, -1),
      ]),
      new_node(NkArrayIdentifer, li(1, 16), @[
         new_identifier_node(NkIdentifier, li(1, 16), "j"),
         new_node(NkRange, li(1, 17), @[
            new_inumber_node(NkIntLit, li(1, 18), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 20), 0, "0", Base10, -1)
         ]),
         new_node(NkRange, li(1, 22), @[
            new_inumber_node(NkIntLit, li(1, 23), 3, "3", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 25), 0, "0", Base10, -1)
         ])
      ])
   ])


# Real declarations
run_test("Real declaration, single identifier", "real foo;"):
   new_node(NkRealDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 6), "foo"),
   ])


run_test("Real declaration, multiple identifiers", "real FOO, BAR;"):
   new_node(NkRealDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 6), "FOO"),
      new_identifier_node(NkIdentifier, li(1, 11), "BAR")
   ])


run_test("Real declaration, assignment", "real foo = 8 + 8;"):
   new_node(NkRealDecl, li(1, 1), @[
      new_node(NkAssignment, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 6), "foo"),
         new_node(NkInfix, li(1, 14), @[
            new_identifier_node(NkIdentifier, li(1, 14), "+"),
            new_inumber_node(NkIntLit, li(1, 12), 8, "8", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 16), 8, "8", Base10, -1)
         ])
      ])
   ])


run_test("Real declaration, dimension", "real i_ranged[7:0];"):
   new_node(NkRealDecl, li(1, 1), @[
      new_node(NkArrayIdentifer, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 6), "i_ranged"),
         new_node(NkRange, li(1, 14), @[
            new_inumber_node(NkIntLit, li(1, 15), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 17), 0, "0", Base10, -1)
         ])
      ])
   ])


run_test("Real declaration, hybrid", "real i = 0, j[7:0][3:0];"):
   new_node(NkRealDecl, li(1, 1), @[
      new_node(NkAssignment, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 6), "i"),
         new_inumber_node(NkIntLit, li(1, 10), 0, "0", Base10, -1),
      ]),
      new_node(NkArrayIdentifer, li(1, 13), @[
         new_identifier_node(NkIdentifier, li(1, 13), "j"),
         new_node(NkRange, li(1, 14), @[
            new_inumber_node(NkIntLit, li(1, 15), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 17), 0, "0", Base10, -1)
         ]),
         new_node(NkRange, li(1, 19), @[
            new_inumber_node(NkIntLit, li(1, 20), 3, "3", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 22), 0, "0", Base10, -1)
         ])
      ])
   ])


# Realtime declarations
run_test("Realtime declaration, single identifier", "realtime foo;"):
   new_node(NkRealtimeDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 10), "foo"),
   ])


run_test("Realtime declaration, multiple identifiers", "realtime FOO, BAR;"):
   new_node(NkRealtimeDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 10), "FOO"),
      new_identifier_node(NkIdentifier, li(1, 15), "BAR")
   ])


run_test("Realtime declaration, assignment", "realtime foo = 8 + 8;"):
   new_node(NkRealtimeDecl, li(1, 1), @[
      new_node(NkAssignment, li(1, 10), @[
         new_identifier_node(NkIdentifier, li(1, 10), "foo"),
         new_node(NkInfix, li(1, 18), @[
            new_identifier_node(NkIdentifier, li(1, 18), "+"),
            new_inumber_node(NkIntLit, li(1, 16), 8, "8", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 20), 8, "8", Base10, -1)
         ])
      ])
   ])


run_test("Realtime declaration, dimension", "realtime i_ranged[7:0];"):
   new_node(NkRealtimeDecl, li(1, 1), @[
      new_node(NkArrayIdentifer, li(1, 10), @[
         new_identifier_node(NkIdentifier, li(1, 10), "i_ranged"),
         new_node(NkRange, li(1, 18), @[
            new_inumber_node(NkIntLit, li(1, 19), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 21), 0, "0", Base10, -1)
         ])
      ])
   ])


run_test("Realtime declaration, hybrid", "realtime i = 0, j[7:0][3:0];"):
   new_node(NkRealtimeDecl, li(1, 1), @[
      new_node(NkAssignment, li(1, 10), @[
         new_identifier_node(NkIdentifier, li(1, 10), "i"),
         new_inumber_node(NkIntLit, li(1, 14), 0, "0", Base10, -1),
      ]),
      new_node(NkArrayIdentifer, li(1, 17), @[
         new_identifier_node(NkIdentifier, li(1, 17), "j"),
         new_node(NkRange, li(1, 18), @[
            new_inumber_node(NkIntLit, li(1, 19), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 21), 0, "0", Base10, -1)
         ]),
         new_node(NkRange, li(1, 23), @[
            new_inumber_node(NkIntLit, li(1, 24), 3, "3", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 26), 0, "0", Base10, -1)
         ])
      ])
   ])


# Time declarations
run_test("Time declaration, single identifier", "time foo;"):
   new_node(NkTimeDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 6), "foo"),
   ])


run_test("Time declaration, multiple identifiers", "time FOO, BAR;"):
   new_node(NkTimeDecl, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 6), "FOO"),
      new_identifier_node(NkIdentifier, li(1, 11), "BAR")
   ])


run_test("Time declaration, assignment", "time foo = 8 + 8;"):
   new_node(NkTimeDecl, li(1, 1), @[
      new_node(NkAssignment, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 6), "foo"),
         new_node(NkInfix, li(1, 14), @[
            new_identifier_node(NkIdentifier, li(1, 14), "+"),
            new_inumber_node(NkIntLit, li(1, 12), 8, "8", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 16), 8, "8", Base10, -1)
         ])
      ])
   ])


run_test("Time declaration, dimension", "time i_ranged[7:0];"):
   new_node(NkTimeDecl, li(1, 1), @[
      new_node(NkArrayIdentifer, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 6), "i_ranged"),
         new_node(NkRange, li(1, 14), @[
            new_inumber_node(NkIntLit, li(1, 15), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 17), 0, "0", Base10, -1)
         ])
      ])
   ])


run_test("Time declaration, hybrid", "time i = 0, j[7:0][3:0];"):
   new_node(NkTimeDecl, li(1, 1), @[
      new_node(NkAssignment, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 6), "i"),
         new_inumber_node(NkIntLit, li(1, 10), 0, "0", Base10, -1),
      ]),
      new_node(NkArrayIdentifer, li(1, 13), @[
         new_identifier_node(NkIdentifier, li(1, 13), "j"),
         new_node(NkRange, li(1, 14), @[
            new_inumber_node(NkIntLit, li(1, 15), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 17), 0, "0", Base10, -1)
         ]),
         new_node(NkRange, li(1, 19), @[
            new_inumber_node(NkIntLit, li(1, 20), 3, "3", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 22), 0, "0", Base10, -1)
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
