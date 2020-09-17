import terminal
import strformat

import ../../src/vparsepkg/parser
import ../lexer/constructors

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test_no_context(title, stimuli: string, reference: Token, expect_error: bool = false) =
   cache = new_ident_cache()
   let n = parse_specific_grammar(stimuli, cache, NkConstantExpression)

   try:
      let response = evaluate_constant_expression(n, @[])
      if response == reference:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                         fgWhite, "Test '",  title, "'")
         nof_passed += 1
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                         fgWhite, "Test '",  title, "'")
         nof_failed += 1
         echo pretty(response)
         echo pretty(reference)
   except EvaluationError as e:
      if expect_error:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                         fgWhite, "Test '",  title, "'")
         nof_passed += 1
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                         fgWhite, "Test '",  title, "'")
         nof_failed += 1
         echo "Exception: ", e.msg

run_test_no_context("Constant infix: +, two terms, unsized",
   "1 + 1", new_inumber(TkIntLit, loc(0, 0, 0), 2, Base10, -1, "2"))

run_test_no_context("Constant infix: +, three terms, unsized",
   "32 + 542 + 99", new_inumber(TkIntLit, loc(0, 0, 0), 673, Base10, -1, "673"))

run_test_no_context("Constant infix: +, two terms, same size",
   "3'b101 + 3'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, 3, "8"))

run_test_no_context("Constant infix: +, two terms, different size",
   "3'b101 + 15'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, 15, "8"))

run_test_no_context("Constant infix: +, three terms, different size",
   "32'd1 + 3'b101 + 15'o3", new_inumber(TkUIntLit, loc(0, 0, 0), 9, Base10, 32, "9"))

run_test_no_context("Constant infix: +, two terms, both real",
   "1.1 + 3.14", new_fnumber(TkRealLit, loc(0, 0, 0), 4.24, "4.24"))

run_test_no_context("Constant infix: +, two terms, one real",
   "2 + 3.7", new_fnumber(TkRealLit, loc(0, 0, 0), 5.7, "5.7"))

run_test_no_context("Constant infix: +, three terms, one real",
   "2 + 3.7 + 4'b1000", new_fnumber(TkRealLit, loc(0, 0, 0), 13.7, "13.7"))

run_test_no_context("Constant infix: +, two terms, one ambiguous",
   "2 + 4'bXX11", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 4, "x"))

run_test_no_context("Constant infix: +, three terms, one ambiguous and one real",
   "2 + 4'bXX11 + 3.44", new_fnumber(TkRealLit, loc(0, 0, 0), 0.0, "x"))

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
