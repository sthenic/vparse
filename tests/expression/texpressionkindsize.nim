import terminal
import strutils
import strformat

import ../../src/vparsepkg/parser
import ../../src/vparsepkg/expression

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test_no_context(title, stimuli: string, reference: tuple[kind: TokenKind, size: int], expect_error: bool = false) =
   cache = new_ident_cache()
   let n = parse_specific_grammar(stimuli, cache, NkConstantExpression)

   try:
      let response = determine_kind_and_size(n, @[])
      if response == reference:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                         fgWhite, "Test '",  title, "'")
         nof_passed += 1
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                         fgWhite, "Test '",  title, "'")
         nof_failed += 1
         echo response
         echo reference
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


# Arithmetic operators w/ size as max(LHS, RHS)
for op in ["+", "-", "*", "/"]:
   run_test_no_context(
      format("Arithmetic ($1) two terms, unsized", op),
      format("1 $1 1", op),
      (TkIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) three terms, unsized", op),
      format("32 $1 542 $1 99", op),
      (TkIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) two terms, sized", op),
      format("3'b101 $1 3'd2", op),
      (TkUIntLit, 3)
   )
   run_test_no_context(
      format("Arithmetic ($1) two terms, unsigned, different size", op),
      format("3'b101 $1 15'd3", op),
      (TkUIntLit, 15)
   )
   run_test_no_context(
      format("Arithmetic ($1) two terms, signed, different size", op),
      format("3'sb101 $1 15'sd3", op),
      (TkIntLit, 15)
   )
   run_test_no_context(
      format("Arithmetic ($1) three terms, different size", op),
      format("32'd1 $1 3'b101 $1 15'o3", op),
      (TkUIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) two terms, both real", op),
      format("1.1 $1 3.14", op),
      (TkRealLit, -1)
   )
   run_test_no_context(
      format("Arithmetic ($1) two terms, one real", op),
      format("2 $1 3.7", op),
      (TkRealLit, -1)
   )
   run_test_no_context(
      format("Arithmetic ($1) three terms, one real", op),
      format("2 $1 3.7 $1 4'b1000", op),
      (TkRealLit, -1)
   )
   run_test_no_context(
      format("Arithmetic ($1) two terms, one ambiguous", op),
      format("2 $1 4'bXX11", op),
      (TkAmbUIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) three terms, one ambiguous and one real", op),
      format("2 $1 4'bXX11 $1 3.44", op),
      (TkAmbRealLit, -1)
   )
   run_test_no_context(
      format("Arithmetic ($1) unsized unsigned number", op),
      format("2 $1 'd3", op),
      (TkUIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) signed operand", op),
      format("4'd12 $1 4'sd12", op),
      (TkUIntLit, 4)
   )
   run_test_no_context(
      format("Arithmetic ($1) signed operand, sign extension", op),
      format("'sh8000_0000 $1 40'd3", op),
      (TkUIntLit, 40)
   )
   run_test_no_context(
      format("Arithmetic ($1) underflow, unsigned result", op),
      format("8'shFF $1 'd0", op),
      (TkUIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) signed result, no underflow", op),
      format("8'shFF $1 0", op),
      (TkIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) overflow, carry truncated (1)", op),
      format("4'd15 $1 4'd15", op),
      (TkUIntLit, 4)
   )
   run_test_no_context(
      format("Arithmetic ($1) overflow, carry truncated (2)", op),
      format("3'b101 $1 3'd3", op),
      (TkUIntLit, 3)
   )
   run_test_no_context(
      format("Arithmetic ($1) keep carry w/ '$1 0' (1)", op),
      format("3'b101 $1 0 $1 3'd3", op),
      (TkUIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) keep carry w/ '$1 0' (2)", op),
      format("3'b101 $1 3'd3 $1 0", op),
      (TkUIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) sized and unsized", op),
      format("4'shF $1 1", op),
      (TkIntLit, 32)
   )
   run_test_no_context(
      format("Arithmetic ($1) sized and real", op),
      format("1.0 $1 4'hF", op),
      (TkRealLit, -1)
   )
   run_test_no_context(
      format("Arithmetic ($1) unsized signed and real", op),
      format("'sh8000_0000 $1 1.0", op),
      (TkRealLit, -1)
   )


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
