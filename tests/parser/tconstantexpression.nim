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
   let response = parse_specific_grammar(stimuli, cache, NtConstantExpression)

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


run_test("Constant primary: numbers, decimal signed", "1234567890"):
   cprim(new_inumber_node(NtIntLit, li(1, 1), 1234567890, "1234567890", Base10, -1))

run_test("Constant primary: numbers, decimal number w/ base", "32'd2617"):
   cprim(new_inumber_node(NtUIntLit, li(1, 1), 2617, "2617", Base10, 32))

run_test("Constant primary: numbers, decimal number w/ base", "18'D32"):
   cprim(new_inumber_node(NtUIntLit, li(1, 1), 32, "32", Base10, 18))

run_test("Constant primary: numbers, decimal number w/ base", "'d77"):
   cprim(new_inumber_node(NtUIntLit, li(1, 1), 77, "77", Base10, -1))

run_test("Constant primary: numbers, decimal number w/ base", "'sd90"):
   cprim(new_inumber_node(NtIntLit, li(1, 1), 90, "90", Base10, -1))

run_test("Constant primary: numbers, decimal number w/ base", "'Sd100"):
   cprim(new_inumber_node(NtIntLit, li(1, 1), 100, "100", Base10, -1))

run_test("Constant primary: numbers, decimal number w/ base", "5'D 3"):
   cprim(new_inumber_node(NtUIntLit, li(1, 1), 3, "3", Base10, 5))

run_test("Constant primary: numbers, underscore", "2617_123_"):
   cprim(new_inumber_node(NtIntLit, li(1, 1), 2617123, "2617123", Base10, -1))

run_test("Constant primary: numbers, decimal X-digit", "16'dX_"):
   cprim(new_inumber_node(NtAmbUIntLit, li(1, 1), 0, "x", Base10, 16))

run_test("Constant primary: numbers, decimal Z-digit", "16'DZ_"):
   cprim(new_inumber_node(NtAmbUIntLit, li(1, 1), 0, "z", Base10, 16))

run_test("Constant primary: numbers, decimal Z-digit", "2'd?"):
   cprim(new_inumber_node(NtAmbUIntLit, li(1, 1), 0, "?", Base10, 2))

run_test("Constant primary: numbers, decimal negative (unary)", "-13"):
   cprim(new_node(NtPrefix, li(1, 1), @[
      new_identifier_node(NtIdentifier, li(1, 1), "-"),
      cprim(new_inumber_node(NtIntLit, li(1, 2), 13, "13", Base10, -1))
   ]))

run_test("Constant primary: numbers, decimal positive (unary)", "+3"):
   cprim(new_node(NtPrefix, li(1, 1), @[
      new_identifier_node(NtIdentifier, li(1, 1), "+"),
      cprim(new_inumber_node(NtIntLit, li(1, 2), 3, "3", Base10, -1))
   ]))

run_test("Constant primary: numbers, invalid decimal", "'dAF"):
   cprim(new_node(NtError, li(1, 1)))

run_test("Constant primary: numbers, simple real", "3.14159"):
   cprim(new_fnumber_node(NtRealLit, li(1, 1), 3.14159, "3.14159"))

run_test("Constant primary: numbers, real (positive exponent)", "1e2"):
   cprim(new_fnumber_node(NtRealLit, li(1, 1), 100, "1e2"))

run_test("Constant primary: numbers, real (negative exponent)", "1e-2"):
   cprim(new_fnumber_node(NtRealLit, li(1, 1), 0.01, "1e-2"))

run_test("Constant primary: numbers, binary", "8'B10000110"):
   cprim(new_inumber_node(NtUIntLit, li(1, 1), 134, "10000110", Base2, 8))

run_test("Constant primary: numbers, octal", "6'O6721"):
   cprim(new_inumber_node(NtUIntLit, li(1, 1), 3537, "6721", Base8, 6))

run_test("Constant primary: numbers, hex", "32'hFFFF_FFFF"):
   cprim(new_inumber_node(NtUIntLit, li(1, 1), (1 shl 32)-1, "FFFFFFFF", Base16, 32))

run_test("Constant primary: identifier", "FOO"):
   cprim(new_identifier_node(NtIdentifier, li(1, 1), "FOO"))

run_test("Constant primary: identifier w/ range", "bar[WIDTH-1:0]"):
   new_node(NtRangedIdentifier, li(1, 1), @[
      new_identifier_node(NtIdentifier, li(1, 1), "bar"),
      new_node(NtConstantRangeExpression, li(1, 4), @[
         new_node(NtInfix, li(1, 10), @[
            new_identifier_node(NtIdentifier, li(1, 10), "-"),
            cprim(new_identifier_node(NtIdentifier, li(1, 5), "WIDTH")),
            cprim(new_inumber_node(NtIntLit, li(1, 11), 1, "1", Base10, -1))
         ]),
         cprim(new_inumber_node(NtIntLit, li(1, 13), 0, "0", Base10, -1))
      ])
   ])

run_test("Constant primary: concatenation", "{64, 32, foobar}"):
   cprim(new_node(NtConstantConcat, li(1, 1), @[
      cprim(new_inumber_node(NtIntLit, li(1, 2), 64, "64", Base10, -1)),
      cprim(new_inumber_node(NtIntLit, li(1, 6), 32, "32", Base10, -1)),
      cprim(new_identifier_node(NtIdentifier, li(1, 10), "foobar"))
   ]))

run_test("Constant primary: multiple concatenation", "{32{2'b01}}"):
   cprim(new_node(NtConstantMultipleConcat, li(1, 1), @[
      cprim(new_inumber_node(NtIntLit, li(1, 2), 32, "32", Base10, -1)),
      new_node(NtConstantConcat, li(1, 4), @[
         cprim(new_inumber_node(NtUIntLit, li(1, 5), 1, "01", Base2, 2)),
      ])
   ]))

run_test("Constant primary: function call", "myfun (* attr = val *) (2, 3, MYCONST)"):
   cprim(new_node(NtConstantFunctionCall, li(1, 1), @[
      new_identifier_node(NtIdentifier, li(1, 1), "myfun"),
      new_node(NtAttributeInst, li(1, 7), @[
         new_identifier_node(NtAttributeName, li(1, 10), "attr"),
         cprim(new_identifier_node(NtIdentifier, li(1, 17), "val"))
      ]),
      cprim(new_inumber_node(NtIntLit, li(1, 25), 2, "2", Base10, -1)),
      cprim(new_inumber_node(NtIntLit, li(1, 28), 3, "3", Base10, -1)),
      cprim(new_identifier_node(NtIdentifier, li(1, 31), "MYCONST"))
   ]))

run_test("Constant primary: system function call", "$clog2(2, 3, MYCONST)"):
   cprim(new_node(NtConstantSystemFunctionCall, li(1, 1), @[
      new_identifier_node(NtIdentifier, li(1, 1), "clog2"),
      cprim(new_inumber_node(NtIntLit, li(1, 8), 2, "2", Base10, -1)),
      cprim(new_inumber_node(NtIntLit, li(1, 11), 3, "3", Base10, -1)),
      cprim(new_identifier_node(NtIdentifier, li(1, 14), "MYCONST"))
   ]))

run_test("Constant primary: mintypmax", "(2'b00:8'd32:MYMAX)"):
   new_node(NtParenthesis, li(1, 1), @[
      cprim(new_node(NtConstantMinTypMaxExpression, li(1, 2), @[
         cprim(new_inumber_node(NtUIntLit, li(1, 2), 0, "00", Base2, 2)),
         cprim(new_inumber_node(NtUIntLit, li(1, 8), 32, "32", Base10, 8)),
         cprim(new_identifier_node(NtIdentifier, li(1, 14), "MYMAX"))
      ]))
   ])

run_test("Constant primary: string", """"This is a string""""):
   cprim(new_str_lit_node(li(1, 1), "This is a string"))


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
