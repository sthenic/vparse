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


# Arithmetic '+'
run_test_no_context("Arithmetic (+) two terms, unsized",
   "1 + 1", new_inumber(TkIntLit, loc(0, 0, 0), 2, Base10, 32, "2"))

run_test_no_context("Arithmetic (+) three terms, unsized",
   "32 + 542 + 99", new_inumber(TkIntLit, loc(0, 0, 0), 673, Base10, 32, "673"))

run_test_no_context("Arithmetic (+) two terms, same size",
   "3'b101 + 3'd2", new_inumber(TkUIntLit, loc(0, 0, 0), 7, Base10, 3, "7"))

run_test_no_context("Arithmetic (+) two terms, different size",
   "3'b101 + 15'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, 15, "8"))

run_test_no_context("Arithmetic (+) three terms, different size",
   "32'd1 + 3'b101 + 15'o3", new_inumber(TkUIntLit, loc(0, 0, 0), 9, Base10, 32, "9"))

run_test_no_context("Arithmetic (+) two terms, both real",
   "1.1 + 3.14", new_fnumber(TkRealLit, loc(0, 0, 0), 4.24, "4.24"))

run_test_no_context("Arithmetic (+) two terms, one real",
   "2 + 3.7", new_fnumber(TkRealLit, loc(0, 0, 0), 5.7, "5.7"))

run_test_no_context("Arithmetic (+) three terms, one real",
   "2 + 3.7 + 4'b1000", new_fnumber(TkRealLit, loc(0, 0, 0), 13.7, "13.7"))

run_test_no_context("Arithmetic (+) two terms, one ambiguous",
   "2 + 4'bXX11", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 32, ""))

run_test_no_context("Arithmetic (+) three terms, one ambiguous and one real",
   "2 + 4'bXX11 + 3.44", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0.0, ""))

run_test_no_context("Arithmetic (+) unsized unsigned number",
   "2 + 'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 5, Base10, 32, "5"))

run_test_no_context("Arithmetic (+) signed operand",
   "4'd12 + 4'sd12", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, 4, "8"))

run_test_no_context("Arithmetic (+) signed operand, sign extension",
   "'sh8000_0000 + 40'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 0xFF_8000_0003, Base10, 40, "1097364144131"))

run_test_no_context("Arithmetic (+) underflow, unsigned result",
   "8'shFF + 'd0", new_inumber(TkUIntLit, loc(0, 0, 0), 4294967295, Base10, 32, "4294967295"))

run_test_no_context("Arithmetic (+) signed result, no underflow",
   "8'shFF + 0", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base10, 32, "-1"))

run_test_no_context("Arithmetic (+) overflow, carry truncated (1)",
   "4'd15 + 4'd15", new_inumber(TkUIntLit, loc(0, 0, 0), 14, Base10, 4, "14"))

run_test_no_context("Arithmetic (+) overflow, carry truncated (2)",
   "3'b101 + 3'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 3, "0"))

run_test_no_context("Arithmetic (+) keep carry w/ '+ 0' (1)",
   "3'b101 + 0 + 3'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, 32, "8"))

run_test_no_context("Arithmetic (+) keep carry w/ '+ 0' (2)",
   "3'b101 + 3'd3 + 0", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, 32, "8"))

run_test_no_context("Arithmetic (+) sized and unsized",
   "4'hF + 1", new_inumber(TkUIntLit, loc(0, 0, 0), 16, Base10, 32, "16"))

run_test_no_context("Arithmetic (+) sized and real",
   "1.0 + 4'hF", new_fnumber(TkRealLit, loc(0, 0, 0), 16.0, "16.0"))

run_test_no_context("Arithmetic (+) unsized signed and real",
   "'sh8000_0000 + 1.0", new_fnumber(TkRealLit, loc(0, 0, 0), -2147483647.0, "-2147483647.0"))

run_test_no_context("Arithmetic (-) underflow (1)",
   "8'h00 - 1", new_inumber(TkUIntLit, loc(0, 0, 0), 4294967295, Base10, 32, "4294967295"))

run_test_no_context("Arithmetic (-) underflow (2)",
   "8'h00 - 8'd01", new_inumber(TkUIntLit, loc(0, 0, 0), 255, Base10, 8, "255"))

run_test_no_context("Arithmetic (/) truncating, unsized",
   "65 / 64", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, 32, "1"))

run_test_no_context("Arithmetic (/) truncating, sized",
   "8'hFF / 8'h10", new_inumber(TkUIntLit, loc(0, 0, 0), 15, Base10, 8, "15"))

run_test_no_context("Arithmetic (/) ceiling integer",
   "(245 + 16 - 1) / 16", new_inumber(TkIntLit, loc(0, 0, 0), 16, Base10, 32, "16"))

run_test_no_context("Arithmetic (/) real operand (1)",
   "1.0 / 2", new_fnumber(TkRealLit, loc(0, 0, 0), 0.5, "0.5"))

run_test_no_context("Arithmetic (/) real operand (2)",
   "1 / 2.0", new_fnumber(TkRealLit, loc(0, 0, 0), 0.5, "0.5"))

run_test_no_context("Arithmetic (/) real operand (3)",
   "1.0 / 2.0", new_fnumber(TkRealLit, loc(0, 0, 0), 0.5, "0.5"))

run_test_no_context("Arithmetic (/) promotion to real",
   "1.0 / 2 + 33 / 32", new_fnumber(TkRealLit, loc(0, 0, 0), 1.53125, "1.53125"))

run_test_no_context("Arithmetic (/) ambiguous, unsized",
   "'hXF / 2", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 32, ""))

run_test_no_context("Arithmetic (/) ambiguous, unsized, signed",
   "'shXF / 2", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, 32, ""))

run_test_no_context("Arithmetic (/) ambiguous, sized",
   "8'hFF / 8'hz2", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 8, ""))

run_test_no_context("Arithmetic (/) division by zero (signed integer)",
   "32 / 0", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, 32, ""))

run_test_no_context("Arithmetic (/) division by zero (unsigned integer)",
   "'d32 / 0", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 32, ""))

run_test_no_context("Arithmetic (/) division by zero (real) (1)",
   "3.0 / 0", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0, ""))

run_test_no_context("Arithmetic (/) division by zero (real) (2)",
   "3 / 0.0", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0, ""))

run_test_no_context("Arithmetic (*) real operand",
   "1.0 * 4'hF", new_fnumber(TkRealLit, loc(0, 0, 0), 15.0, "15.0"))

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
