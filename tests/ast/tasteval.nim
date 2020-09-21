import terminal
import strformat
import math

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
   "1 + 1", new_inumber(TkIntLit, loc(0, 0, 0), 2, Base10, INTEGER_BITS, "2"))

run_test_no_context("Arithmetic (+) three terms, unsized",
   "32 + 542 + 99", new_inumber(TkIntLit, loc(0, 0, 0), 673, Base10, INTEGER_BITS, "673"))

run_test_no_context("Arithmetic (+) two terms, same size",
   "3'b101 + 3'd2", new_inumber(TkUIntLit, loc(0, 0, 0), 7, Base10, 3, "7"))

run_test_no_context("Arithmetic (+) two terms, different size",
   "3'b101 + 15'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, 15, "8"))

run_test_no_context("Arithmetic (+) three terms, different size",
   "32'd1 + 3'b101 + 15'o3", new_inumber(TkUIntLit, loc(0, 0, 0), 9, Base10, INTEGER_BITS, "9"))

run_test_no_context("Arithmetic (+) two terms, both real",
   "1.1 + 3.14", new_fnumber(TkRealLit, loc(0, 0, 0), 4.24, "4.24"))

run_test_no_context("Arithmetic (+) two terms, one real",
   "2 + 3.7", new_fnumber(TkRealLit, loc(0, 0, 0), 5.7, "5.7"))

run_test_no_context("Arithmetic (+) three terms, one real",
   "2 + 3.7 + 4'b1000", new_fnumber(TkRealLit, loc(0, 0, 0), 13.7, "13.7"))

run_test_no_context("Arithmetic (+) two terms, one ambiguous",
   "2 + 4'bXX11", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, ""))

run_test_no_context("Arithmetic (+) three terms, one ambiguous and one real",
   "2 + 4'bXX11 + 3.44", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0.0, ""))

run_test_no_context("Arithmetic (+) unsized unsigned number",
   "2 + 'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 5, Base10, INTEGER_BITS, "5"))

run_test_no_context("Arithmetic (+) signed operand",
   "4'd12 + 4'sd12", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, 4, "8"))

run_test_no_context("Arithmetic (+) signed operand, sign extension",
   "'sh8000_0000 + 40'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 0xFF_8000_0003, Base10, 40, "1097364144131"))

run_test_no_context("Arithmetic (+) underflow, unsigned result",
   "8'shFF + 'd0", new_inumber(TkUIntLit, loc(0, 0, 0), 4294967295, Base10, INTEGER_BITS, "4294967295"))

run_test_no_context("Arithmetic (+) signed result, no underflow",
   "8'shFF + 0", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base10, INTEGER_BITS, "-1"))

run_test_no_context("Arithmetic (+) overflow, carry truncated (1)",
   "4'd15 + 4'd15", new_inumber(TkUIntLit, loc(0, 0, 0), 14, Base10, 4, "14"))

run_test_no_context("Arithmetic (+) overflow, carry truncated (2)",
   "3'b101 + 3'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 3, "0"))

run_test_no_context("Arithmetic (+) keep carry w/ '+ 0' (1)",
   "3'b101 + 0 + 3'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, INTEGER_BITS, "8"))

run_test_no_context("Arithmetic (+) keep carry w/ '+ 0' (2)",
   "3'b101 + 3'd3 + 0", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base10, INTEGER_BITS, "8"))

run_test_no_context("Arithmetic (+) sized and unsized",
   "4'hF + 1", new_inumber(TkUIntLit, loc(0, 0, 0), 16, Base10, INTEGER_BITS, "16"))

run_test_no_context("Arithmetic (+) sized and real",
   "1.0 + 4'hF", new_fnumber(TkRealLit, loc(0, 0, 0), 16.0, "16.0"))

run_test_no_context("Arithmetic (+) unsized signed and real",
   "'sh8000_0000 + 1.0", new_fnumber(TkRealLit, loc(0, 0, 0), -2147483647.0, "-2147483647.0"))

run_test_no_context("Arithmetic (-) underflow (1)",
   "8'h00 - 1", new_inumber(TkUIntLit, loc(0, 0, 0), 4294967295, Base10, INTEGER_BITS, "4294967295"))

run_test_no_context("Arithmetic (-) underflow (2)",
   "8'h00 - 8'd01", new_inumber(TkUIntLit, loc(0, 0, 0), 255, Base10, 8, "255"))

run_test_no_context("Arithmetic (-) truncated first term",
   "4'hBA - 4'hA", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 4, "0"))

run_test_no_context("Arithmetic (/) truncating, unsized",
   "65 / 64", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, INTEGER_BITS, "1"))

run_test_no_context("Arithmetic (/) truncating, sized",
   "8'hFF / 8'h10", new_inumber(TkUIntLit, loc(0, 0, 0), 15, Base10, 8, "15"))

run_test_no_context("Arithmetic (/) ceiling integer",
   "(245 + 16 - 1) / 16", new_inumber(TkIntLit, loc(0, 0, 0), 16, Base10, INTEGER_BITS, "16"))

run_test_no_context("Arithmetic (/) real operand (1)",
   "1.0 / 2", new_fnumber(TkRealLit, loc(0, 0, 0), 0.5, "0.5"))

run_test_no_context("Arithmetic (/) real operand (2)",
   "1 / 2.0", new_fnumber(TkRealLit, loc(0, 0, 0), 0.5, "0.5"))

run_test_no_context("Arithmetic (/) real operand (3)",
   "1.0 / 2.0", new_fnumber(TkRealLit, loc(0, 0, 0), 0.5, "0.5"))

run_test_no_context("Arithmetic (/) promotion to real",
   "1.0 / 2 + 33 / 32", new_fnumber(TkRealLit, loc(0, 0, 0), 1.53125, "1.53125"))

run_test_no_context("Arithmetic (/) ambiguous, unsized",
   "'hXF / 2", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, ""))

run_test_no_context("Arithmetic (/) ambiguous, unsized, signed",
   "'shXF / 2", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, ""))

run_test_no_context("Arithmetic (/) ambiguous, sized",
   "8'hFF / 8'hz2", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 8, ""))

run_test_no_context("Arithmetic (/) division by zero (signed integer)",
   "32 / 0", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, ""))

run_test_no_context("Arithmetic (/) division by zero (unsigned integer)",
   "'d32 / 0", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, ""))

run_test_no_context("Arithmetic (/) division by zero (real) (1)",
   "3.0 / 0", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0, ""))

run_test_no_context("Arithmetic (/) division by zero (real) (2)",
   "3 / 0.0", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0, ""))

run_test_no_context("Arithmetic (*) sized, overflow",
   "8'h80 * 8'd2", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 8, "0"))

run_test_no_context("Arithmetic (*) unsized, no overflow",
   "8'h80 * 2", new_inumber(TkUIntLit, loc(0, 0, 0), 256, Base10, INTEGER_BITS, "256"))

run_test_no_context("Arithmetic (*) real operand",
   "1.0 * 4'hF", new_fnumber(TkRealLit, loc(0, 0, 0), 15.0, "15.0"))

run_test_no_context("Arithmetic (%) unsized, signed",
   "15 % 32", new_inumber(TkIntLit, loc(0, 0, 0), 15, Base10, INTEGER_BITS, "15"))

run_test_no_context("Arithmetic (%) unsized, unsigned",
   "'hA % 8", new_inumber(TkUIntLit, loc(0, 0, 0), 2, Base10, INTEGER_BITS, "2"))

run_test_no_context("Arithmetic (%) sized, signed, negative",
   "4'sb1011 % 4'd2", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base10, 4, "-1"))

run_test_no_context("Arithmetic (%) sized, signed, positive",
   "4'b0101 % 4'sb1110", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 4, "1"))

run_test_no_context("Arithmetic (%) real operand (error)", "15.0 % 32", Token(), true)

run_test_no_context("Arithmetic (**) unsized",
   "5 ** 2", new_inumber(TkIntLit, loc(0, 0, 0), 25, Base10, INTEGER_BITS, "25"))

run_test_no_context("Arithmetic (**) sized (only depends on first operand)",
   "6'd2 ** 5", new_inumber(TkUIntLit, loc(0, 0, 0), 32, Base10, 6, "32"))

run_test_no_context("Arithmetic (**) sized, signed -> negative (kind only depends on first operand)",
   "4'sb1110 ** 'd1", new_inumber(TkIntLit, loc(0, 0, 0), -2, Base10, 4, "-2"))

run_test_no_context("Arithmetic (**) sized, signed -> even",
   "4'sb1110 ** 'd2", new_inumber(TkIntLit, loc(0, 0, 0), 4, Base10, 4, "4"))

run_test_no_context("Arithmetic (**) sized, signed, overflow",
   "4'sb1001 ** 'd2 // (-7)^2 mod 16", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, 4, "1"))

run_test_no_context("Arithmetic (**) x < -1, y == 0",
   "4'sb1110 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, 4, "1"))

run_test_no_context("Arithmetic (**) x < -1, y < 0",
   "4'sb1110 ** 4'sb1110", new_inumber(TkIntLit, loc(0, 0, 0), 0, Base10, 4, "0"))

run_test_no_context("Arithmetic (**) x == -1, y > 0, odd",
   "2'sb11 ** 3", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base10, 2, "-1"))

run_test_no_context("Arithmetic (**) x == -1, y > 0, even",
   "2'sb11 ** 4", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, 2, "1"))

run_test_no_context("Arithmetic (**) x == -1, y == 0",
   "2'sb11 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, 2, "1"))

run_test_no_context("Arithmetic (**) x == -1, y < 0, odd",
   "2'sb11 ** 4'sb1101", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base10, 2, "-1"))

run_test_no_context("Arithmetic (**) x == -1, y < 0, even",
   "2'sb11 ** 4'sb1100", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, 2, "1"))

run_test_no_context("Arithmetic (**) x == 0, y > 0",
   "0 ** 2", new_inumber(TkIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, "0"))

run_test_no_context("Arithmetic (**) x == 0, y == 0",
   "0 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, INTEGER_BITS, "1"))

run_test_no_context("Arithmetic (**) x == 0, y < 0",
   "0 ** 4'sb1110", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, ""))

run_test_no_context("Arithmetic (**) x == 1, y > 0",
   "1 ** 2", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, INTEGER_BITS, "1"))

run_test_no_context("Arithmetic (**) x == 1, y == 0",
   "1 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, INTEGER_BITS, "1"))

run_test_no_context("Arithmetic (**) x == 1, y < 0",
   "1 ** 4'sb1110", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, INTEGER_BITS, "1"))

run_test_no_context("Arithmetic (**) x > 1, y == 0",
   "32 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base10, INTEGER_BITS, "1"))

run_test_no_context("Arithmetic (**) x > 1, y < 0",
   "43 ** 4'sb1110", new_inumber(TkIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, "0"))

run_test_no_context("Arithmetic (**) x real, y real",
   "2.0 ** 0.5", new_fnumber(TkRealLit, loc(0, 0, 0), pow(2.0, 0.5), "1.414213562373095"))

run_test_no_context("Arithmetic (**) x == 0.0, y < 0.0",
   "0.0 ** -5.0", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0.0, ""))

run_test_no_context("Arithmetic (**) x < 0.0, y real",
   "-2.0 ** 2.0", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0.0, ""))

run_test_no_context("Arithmetic (**) x real, y integer",
   "2.0 ** 2", new_fnumber(TkRealLit, loc(0, 0, 0), 4.0, "4.0"))

run_test_no_context("Arithmetic (**) x == 0.0, y < 0",
   "0.0 ** 4'sb1110", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0.0, ""))

run_test_no_context("Arithmetic (**) x < 0.0, y integer",
   "-2.0 ** 2", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0.0, ""))

run_test_no_context("Arithmetic (**) x integer, y real",
   "2 ** 2.0", new_fnumber(TkRealLit, loc(0, 0, 0), 4.0, "4.0"))

run_test_no_context("Arithmetic (**) x < 0, y real",
   "4'sb1100 ** 2.0", new_fnumber(TkAmbRealLit, loc(0, 0, 0), 0.0, ""))

run_test_no_context("Arithmetic (**) x == 0.0, y == 0.0",
   "0.0 ** 0.0", new_fnumber(TkRealLit, loc(0, 0, 0), 1.0, "1.0"))

run_test_no_context("Arithmetic (**) x == 0.0, y > 0",
   "0.0 ** 3", new_fnumber(TkRealLit, loc(0, 0, 0), 0.0, "0.0"))

run_test_no_context("Arithmetic (**) real reciprocal",
   "2.0 ** 2'sb11", new_fnumber(TkRealLit, loc(0, 0, 0), 0.5, "0.5"))

run_test_no_context("Arithmetic (**) truncated reciprocal",
   "2 ** 2'sb11", new_inumber(TkIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, "0"))

run_test_no_context("Arithmetic (**) real square root",
   "9.0 ** 0.5", new_fnumber(TkRealLit, loc(0, 0, 0), 3.0, "3.0"))

run_test_no_context("Arithmetic (**) exponent truncated to zero",
   "9.0 ** (1/2)", new_fnumber(TkRealLit, loc(0, 0, 0), 1.0, "1.0"))

run_test_no_context("Prefix (+) integer",
   "+3", new_inumber(TkIntLit, loc(0, 0, 0), 3, Base10, INTEGER_BITS, "3"))

run_test_no_context("Prefix (+) integer, sized",
   "+3'd2", new_inumber(TkUIntLit, loc(0, 0, 0), 2, Base10, 3, "2"))

run_test_no_context("Prefix (+) real",
   "+9.1", new_fnumber(TkRealLit, loc(0, 0, 0), 9.1, "9.1"))

run_test_no_context("Prefix (+) ambiguous (1)",
   "+3'b0X1", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 3, ""))

run_test_no_context("Prefix (+) ambiguous (2)",
   "+3'sb?01", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, 3, ""))

run_test_no_context("Prefix (-) integer",
   "-3", new_inumber(TkIntLit, loc(0, 0, 0), -3, Base10, INTEGER_BITS, "-3"))

run_test_no_context("Prefix (-) integer, sized, truncated",
   "-4'd12", new_inumber(TkUIntLit, loc(0, 0, 0), 4, Base10, 4, "4"))

run_test_no_context("Prefix (-) real",
   "-9.1", new_fnumber(TkRealLit, loc(0, 0, 0), -9.1, "-9.1"))

run_test_no_context("Prefix (-) ambiguous (1)",
   "-3'b0X1", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 3, ""))

run_test_no_context("Prefix (-) ambiguous (2)",
   "-3'sb?01", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, 3, ""))

run_test_no_context("Prefix (-) in infix expression",
   "-5 - 2", new_inumber(TkIntLit, loc(0, 0, 0), -7, Base10, INTEGER_BITS, "-7"))

run_test_no_context("Prefix (~) unsized",
   "~0", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base10, INTEGER_BITS, "-1"))

run_test_no_context("Prefix (~) sized, unsigned",
   "~3'b101", new_inumber(TkUIntLit, loc(0, 0, 0), 2, Base10, 3, "2"))

run_test_no_context("Prefix (~) sized, signed",
   "~3'sb010", new_inumber(TkIntLit, loc(0, 0, 0), -3, Base10, 3, "-3"))

run_test_no_context("Prefix (~) ambiguous binary",
   "~3'b?10", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base2, 3, "x01"))

run_test_no_context("Prefix (~) ambiguous octal",
   "~9'Ox73", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base8, 9, "x04"))

run_test_no_context("Prefix (~) ambiguous hexadecimal",
   "~16'hA_X71", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base16, 16, "5x8E"))

run_test_no_context("Prefix (~) ambiguous decimal",
   "~16'dx", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 16, "x"))

run_test_no_context("Prefix (!) zero value, unsized",
   "!0", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (!) zero value, sized",
   "!5'd0", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (!) nonzero value, unsized",
   "!32", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (!) nonzero value, sized",
   "!2'b10", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (!) real, zero value",
   "!0.0", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (!) real, zero value",
   "!4.2", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (!) ambiguous",
   "!2'bx1", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (&) unsized",
   "&32", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (&) sized",
   "&3'b111", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (&) ambiguous",
   "&12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (|) unsized",
   "|'b000", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (|) sized",
   "|8'h08", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (|) ambiguous",
   "|12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (^) unsized",
   "^'b100", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (^) sized, even ones",
   "^4'b0011", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (^) sized, odd ones",
   "^4'b1011", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (^) ambiguous",
   "^12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (~&) unsized",
   "~&32", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (~&) sized",
   "~&3'b111", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (~&) ambiguous",
   "~&12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (~|) unsized",
   "~|'b000", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (~|) sized",
   "~|8'h08", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (~|) ambiguous",
   "~|12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (~^) unsized",
   "~^'b100", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (~^) sized, even ones",
   "~^4'b0011", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (~^) sized, odd ones",
   "~^4'b1011", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (~^) ambiguous",
   "~^12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (^~) unsized",
   "^~'b100", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (^~) sized, even ones",
   "^~4'b0011", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base10, 1, "1"))

run_test_no_context("Prefix (^~) sized, odd ones",
   "^~4'b1011", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base10, 1, "0"))

run_test_no_context("Prefix (^~) ambiguous",
   "^~12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

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
