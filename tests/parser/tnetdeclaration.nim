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

# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: net declaration
---------------------------""")

# Run tests
for net_type in NetTypeTokens:
   let raw = TokenKindToStr[net_type]
   run_test(format("Simple net declaration, $1", raw), format("""$1
foo;""", raw)):
      new_node(NkNetDecl, li(1, 1), @[
         new_identifier_node(NkType, li(1, 1), raw),
         new_identifier_node(NkIdentifier, li(2, 1), "foo"),
      ])


run_test("Net declaration with missing semicolon", "wire foo"):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkIdentifier, li(1, 6), "foo"),
      new_node(NkExpectError, li(1, 9), @[
         new_error_node(NkTokenError, li(1, 9), "", ""),
      ]),
   ])


run_test("Signed net declaration", "wire signed mywire;"):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkType, li(1, 6), "signed"),
      new_identifier_node(NkIdentifier, li(1, 13), "mywire"),
   ])


run_test("Ranged net declaration", "wire [31:0] mywire;"):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_node(NkRange, li(1, 6), @[
         new_inumber_node(NkIntLit, li(1, 7), 31, "31", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 10), 0, "0", Base10, -1)
      ]),
      new_identifier_node(NkIdentifier, li(1, 13), "mywire"),
   ])


run_test("Net declaration with delay", "wire #3 mywire;"):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_node(NkDelay, li(1, 6), @[
         new_inumber_node(NkIntLit, li(1, 7), 3, "3", Base10, -1)
      ]),
      new_identifier_node(NkIdentifier, li(1, 9), "mywire"),
   ])


run_test("Net declaration with delay (three typ expressions)",
   "wire #(3, 4, 5) mywire;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_node(NkDelay, li(1, 6), @[
         new_node(NkParenthesis, li(1, 7), @[
            new_inumber_node(NkIntLit, li(1, 8), 3, "3", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 11), 4, "4", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 14), 5, "5", Base10, -1)
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 17), "mywire"),
   ])


run_test("Net declaration with delay (three min-typ-max expressions)",
   "wire #(0, (1:2:3), 5) mywire;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_node(NkDelay, li(1, 6), @[
         new_node(NkParenthesis, li(1, 7), @[
            new_inumber_node(NkIntLit, li(1, 8), 0, "0", Base10, -1),
            new_node(NkParenthesis, li(1, 11), @[
               new_node(NkConstantMinTypMaxExpression, li(1, 12), @[
                  new_inumber_node(NkIntLit, li(1, 12), 1, "1", Base10, -1),
                  new_inumber_node(NkIntLit, li(1, 14), 2, "2", Base10, -1),
                  new_inumber_node(NkIntLit, li(1, 16), 3, "3", Base10, -1),
               ]),
            ]),
            new_inumber_node(NkIntLit, li(1, 20), 5, "5", Base10, -1)
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 23), "mywire"),
   ])


run_test("Signed net declaration with delay (three min-typ-max expressions)",
   "wand signed #(0, (1:2:3), 5) mywire;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wand"),
      new_identifier_node(NkType, li(1, 6), "signed"),
      new_node(NkDelay, li(1, 13), @[
         new_node(NkParenthesis, li(1, 14), @[
            new_inumber_node(NkIntLit, li(1, 15), 0, "0", Base10, -1),
            new_node(NkParenthesis, li(1, 18), @[
               new_node(NkConstantMinTypMaxExpression, li(1, 19), @[
                  new_inumber_node(NkIntLit, li(1, 19), 1, "1", Base10, -1),
                  new_inumber_node(NkIntLit, li(1, 21), 2, "2", Base10, -1),
                  new_inumber_node(NkIntLit, li(1, 23), 3, "3", Base10, -1),
               ]),
            ]),
            new_inumber_node(NkIntLit, li(1, 27), 5, "5", Base10, -1)
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 30), "mywire"),
   ])


run_test("Simple net declarations, list of identifiers",
   "wire a, b, c, foo;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkIdentifier, li(1, 6), "a"),
      new_identifier_node(NkIdentifier, li(1, 9), "b"),
      new_identifier_node(NkIdentifier, li(1, 12), "c"),
      new_identifier_node(NkIdentifier, li(1, 15), "foo"),
   ])


run_test("Simple net declarations, list of assignments",
   "wire a = 1'b0, b = 1'b1, c = 1'b0;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_node(NkAssignment, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 6), "a"),
         new_inumber_node(NkUIntLit, li(1, 10), 0, "0", Base2, 1),
      ]),
      new_node(NkAssignment, li(1, 16), @[
         new_identifier_node(NkIdentifier, li(1, 16), "b"),
         new_inumber_node(NkUIntLit, li(1, 20), 1, "1", Base2, 1),
      ]),
      new_node(NkAssignment, li(1, 26), @[
         new_identifier_node(NkIdentifier, li(1, 26), "c"),
         new_inumber_node(NkUIntLit, li(1, 30), 0, "0", Base2, 1),
      ]),
   ])


run_test("Simple net declarations, mixed list of assignments and identifiers (not allowed)",
   "wire a = 1'b0, b, c = 1'b0;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_node(NkAssignment, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 6), "a"),
         new_inumber_node(NkUIntLit, li(1, 10), 0, "0", Base2, 1),
      ]),
      new_node(NkExpectError, li(1, 17), @[
         new_error_node(NkTokenError, li(1, 17), "", ""),
         new_error_node(NkTokenError, li(1, 19), "", ""),
         new_error_node(NkTokenErrorSync, li(1, 21), "", ""),
      ]),
      new_node(NkAssignment, li(1, 16), @[
         new_identifier_node(NkIdentifier, li(1, 16), "b"),
         new_inumber_node(NkUIntLit, li(1, 23), 0, "0", Base2, 1),
      ]),
   ])


run_test("Vectored net declaration",
   "wire vectored [31:0] my_vector_wire;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkType, li(1, 6), "vectored"),
      new_node(NkRange, li(1, 15), @[
         new_inumber_node(NkIntLit, li(1, 16), 31, "31", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 19), 0, "0", Base10, -1)
      ]),
      new_identifier_node(NkIdentifier, li(1, 22), "my_vector_wire"),
   ])


run_test("Scalared net declaration",
   "wire scalared [31:0] my_vector_wire;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkType, li(1, 6), "scalared"),
      new_node(NkRange, li(1, 15), @[
         new_inumber_node(NkIntLit, li(1, 16), 31, "31", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 19), 0, "0", Base10, -1)
      ]),
      new_identifier_node(NkIdentifier, li(1, 22), "my_vector_wire"),
   ])


run_test("Vectored net declaration without range (error)",
   "wire vectored my_vector_wire;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkType, li(1, 6), "vectored"),
      new_node(NkExpectError, li(1, 15), @[
         new_error_node(NkTokenError, li(1, 15), "", ""),
         new_error_node(NkTokenError, li(1, 29), "", ""),
         new_error_node(NkTokenError, li(1, 30), "", ""),
      ])
   ])


run_test("Net declaration with drive strength",
   "wire (supply0, supply1) my_strong_wire = 1'b1;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_node(NkDriveStrength, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 7), "supply0"),
         new_identifier_node(NkIdentifier, li(1, 16), "supply1"),
      ]),
      new_node(NkAssignment, li(1, 25), @[
         new_identifier_node(NkIdentifier, li(1, 25), "my_strong_wire"),
         new_inumber_node(NkUIntLit, li(1, 42), 1, "1", Base2, 1),
      ]),
   ])


run_test("Net declaration with charge strength (error)",
   "wire (large) my_strong_wire = 1'b1;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_node(NkDriveStrength, li(1, 6), @[
         new_error_node(NkTokenError, li(1, 7), "", ""),
      ]),
      new_node(NkExpectError, li(1, 12), @[
         new_error_node(NkTokenError, li(1, 12), "", ""),
         new_error_node(NkTokenErrorSync, li(1, 14), "", ""),
      ]),
      new_node(NkAssignment, li(1, 14), @[
         new_identifier_node(NkIdentifier, li(1, 14), "my_strong_wire"),
         new_inumber_node(NkUIntLit, li(1, 31), 1, "1", Base2, 1),
      ]),
   ])


run_test("Simple trireg declaration",
   "trireg foo;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "trireg"),
      new_identifier_node(NkIdentifier, li(1, 8), "foo"),
   ])


run_test("Ranged trireg declaration", "trireg [23:0] foo;"):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "trireg"),
      new_node(NkRange, li(1, 8), @[
         new_inumber_node(NkIntLit, li(1, 9), 23, "23", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 12), 0, "0", Base10, -1)
      ]),
      new_identifier_node(NkIdentifier, li(1, 15), "foo"),
   ])


run_test("Signed trireg declaration",
   "trireg signed foo;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "trireg"),
      new_identifier_node(NkType, li(1, 8), "signed"),
      new_identifier_node(NkIdentifier, li(1, 15), "foo"),
   ])



run_test("Trireg declaration with charge strength (list of identifiers)",
   "trireg (large) foo, bar, baz;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "trireg"),
      new_node(NkChargeStrength, li(1, 9), @[
         new_identifier_node(NkIdentifier, li(1, 9), "large"),
      ]),
      new_identifier_node(NkIdentifier, li(1, 16), "foo"),
      new_identifier_node(NkIdentifier, li(1, 21), "bar"),
      new_identifier_node(NkIdentifier, li(1, 26), "baz"),
   ])


run_test("Trireg declaration with drive strength (list of assignments)",
   "trireg (highz0, highz1) foo = 1'b1, bar = 1'b0, baz = 1'b1;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "trireg"),
      new_node(NkDriveStrength, li(1, 8), @[
         new_identifier_node(NkIdentifier, li(1, 9), "highz0"),
         new_identifier_node(NkIdentifier, li(1, 17), "highz1"),
      ]),
      new_node(NkAssignment, li(1, 25), @[
         new_identifier_node(NkIdentifier, li(1, 25), "foo"),
         new_inumber_node(NkUIntLit, li(1, 31), 1, "1", Base2, 1),
      ]),
      new_node(NkAssignment, li(1, 37), @[
         new_identifier_node(NkIdentifier, li(1, 37), "bar"),
         new_inumber_node(NkUIntLit, li(1, 43), 0, "0", Base2, 1),
      ]),
      new_node(NkAssignment, li(1, 49), @[
         new_identifier_node(NkIdentifier, li(1, 49), "baz"),
         new_inumber_node(NkUIntLit, li(1, 55), 1, "1", Base2, 1),
      ]),
   ])


run_test("Complex wire",
   "wire (highz0, supply1) vectored signed [7:0] #(1,2,3) first = 8'd0, second = 8'h23;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_node(NkDriveStrength, li(1, 6), @[
         new_identifier_node(NkIdentifier, li(1, 7), "highz0"),
         new_identifier_node(NkIdentifier, li(1, 15), "supply1"),
      ]),
      new_identifier_node(NkType, li(1, 24), "vectored"),
      new_identifier_node(NkType, li(1, 33), "signed"),
      new_node(NkRange, li(1, 40), @[
         new_inumber_node(NkIntLit, li(1, 41), 7, "7", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 43), 0, "0", Base10, -1)
      ]),
      new_node(NkDelay, li(1, 46), @[
         new_node(NkParenthesis, li(1, 47), @[
            new_inumber_node(NkIntLit, li(1, 48), 1, "1", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 50), 2, "2", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 52), 3, "3", Base10, -1),
         ]),
      ]),
      new_node(NkAssignment, li(1, 55), @[
         new_identifier_node(NkIdentifier, li(1, 55), "first"),
         new_inumber_node(NkUIntLit, li(1, 63), 0, "0", Base10, 8),
      ]),
      new_node(NkAssignment, li(1, 69), @[
         new_identifier_node(NkIdentifier, li(1, 69), "second"),
         new_inumber_node(NkUIntLit, li(1, 78), 35, "23", Base16, 8),
      ]),
   ])


run_test("Complex trireg",
   "trireg (small) scalared signed [7 : 0] #(1,2,3) first, second;"
):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "trireg"),
      new_node(NkChargeStrength, li(1, 9), @[
         new_identifier_node(NkIdentifier, li(1, 9), "small"),
      ]),
      new_identifier_node(NkType, li(1, 16), "scalared"),
      new_identifier_node(NkType, li(1, 25), "signed"),
      new_node(NkRange, li(1, 32), @[
         new_inumber_node(NkIntLit, li(1, 33), 7, "7", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 37), 0, "0", Base10, -1)
      ]),
      new_node(NkDelay, li(1, 40), @[
         new_node(NkParenthesis, li(1, 41), @[
            new_inumber_node(NkIntLit, li(1, 42), 1, "1", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 44), 2, "2", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 46), 3, "3", Base10, -1),
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 49), "first"),
      new_identifier_node(NkIdentifier, li(1, 56), "second"),
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
