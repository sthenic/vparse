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

for net_type in NetTypeTokens:
   let raw = TokenKindToStr[net_type]
   run_test(format("Simple net declaration, $1", raw), format("""$1
foo;""", raw)):
      new_node(NkNetDecl, li(1, 1), @[
         new_identifier_node(NkType, li(1, 1), raw),
         new_identifier_node(NkIdentifier, li(2, 1), "foo"),
      ])


run_test("Signed net declaration", "wire signed mywire;"):
   new_node(NkNetDecl, li(1, 1), @[
      new_identifier_node(NkType, li(1, 1), "wire"),
      new_identifier_node(NkType, li(1, 6), "signed"),
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
