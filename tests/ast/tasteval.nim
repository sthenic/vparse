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
   "1 + 1", new_inumber(TkIntLit, loc(0, 0, 0), 2, Base2, INTEGER_BITS, "00000000000000000000000000000010"))

run_test_no_context("Arithmetic (+) three terms, unsized",
   "32 + 542 + 99", new_inumber(TkIntLit, loc(0, 0, 0), 673, Base2, INTEGER_BITS, "00000000000000000000001010100001"))

run_test_no_context("Arithmetic (+) two terms, same size",
   "3'b101 + 3'd2", new_inumber(TkUIntLit, loc(0, 0, 0), 7, Base2, 3, "111"))

run_test_no_context("Arithmetic (+) two terms, different size",
   "3'b101 + 15'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base2, 15, "000000000001000"))

run_test_no_context("Arithmetic (+) three terms, different size",
   "32'd1 + 3'b101 + 15'o3", new_inumber(TkUIntLit, loc(0, 0, 0), 9, Base2, INTEGER_BITS, "00000000000000000000000000001001"))

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
   "2 + 'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 5, Base2, INTEGER_BITS, "00000000000000000000000000000101"))

run_test_no_context("Arithmetic (+) signed operand",
   "4'd12 + 4'sd12", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base2, 4, "1000"))

run_test_no_context("Arithmetic (+) signed operands, sign extension",
   "'sh8000_0000 + 40'sd3", new_inumber(TkIntLit, loc(0, 0, 0), -2147483645, Base2, 40, "1111111110000000000000000000000000000011"))

run_test_no_context("Arithmetic (+) unsigned result, no underflow",
   "8'shFF + 'd0", new_inumber(TkUIntLit, loc(0, 0, 0), 255, Base2, INTEGER_BITS, "00000000000000000000000011111111"))

run_test_no_context("Arithmetic (+) signed result, no underflow",
   "8'shFF + 0", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base2, INTEGER_BITS, "11111111111111111111111111111111"))

run_test_no_context("Arithmetic (+) overflow, carry truncated (1)",
   "4'd15 + 4'd15", new_inumber(TkUIntLit, loc(0, 0, 0), 14, Base2, 4, "1110"))

run_test_no_context("Arithmetic (+) overflow, carry truncated (2)",
   "3'b101 + 3'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 3, "000"))

run_test_no_context("Arithmetic (+) keep carry w/ '+ 0' (1)",
   "3'b101 + 0 + 3'd3", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base2, INTEGER_BITS, "00000000000000000000000000001000"))

run_test_no_context("Arithmetic (+) keep carry w/ '+ 0' (2)",
   "3'b101 + 3'd3 + 0", new_inumber(TkUIntLit, loc(0, 0, 0), 8, Base2, INTEGER_BITS, "00000000000000000000000000001000"))

run_test_no_context("Arithmetic (+) sized and unsized",
   "4'hF + 1", new_inumber(TkUIntLit, loc(0, 0, 0), 16, Base2, INTEGER_BITS, "00000000000000000000000000010000"))

run_test_no_context("Arithmetic (+) sized and real",
   "1.0 + 4'hF", new_fnumber(TkRealLit, loc(0, 0, 0), 16.0, "16.0"))

run_test_no_context("Arithmetic (+) unsized signed and real",
   "'sh8000_0000 + 1.0", new_fnumber(TkRealLit, loc(0, 0, 0), -2147483647.0, "-2147483647.0"))

run_test_no_context("Arithmetic (+) big numbers (1)",
   "68'h01_0000_0000_0000_0000 + 1",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 68, "00010000000000000000000000000000000000000000000000000000000000000001"))

run_test_no_context("Arithmetic (+) big numbers (2)",
   "68'shFF_0000_0000_0000_0000 + 3'sb101",
   new_inumber(TkIntLit, loc(0, 0, 0), 0, Base2, 68, "11101111111111111111111111111111111111111111111111111111111111111101"))

run_test_no_context("Arithmetic (+) big numbers (3)", """
    256'h0000_0000_0000_0000_0000_0000_0000_FFFF_0000_0000_0000_0000_0000_0000_0000_0000 +
    256'h00AA_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 256,
   "0000000010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001"))

run_test_no_context("Arithmetic (-) underflow (1)",
   "8'h00 - 1", new_inumber(TkUIntLit, loc(0, 0, 0), 4294967295, Base2, INTEGER_BITS, "11111111111111111111111111111111"))

run_test_no_context("Arithmetic (-) underflow (2)",
   "8'h00 - 8'd01", new_inumber(TkUIntLit, loc(0, 0, 0), 255, Base2, 8, "11111111"))

run_test_no_context("Arithmetic (-) truncated first term",
   "4'hBA - 4'hA", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 4, "0000"))

run_test_no_context("Arithmetic (-) big numbers (1)", """
   65'h1_0000_0000_0000_0000 - 1""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 65, "01111111111111111111111111111111111111111111111111111111111111111"))

run_test_no_context("Arithmetic (-) big numbers (2)", """
   1 - 65'sh1_0000_0000_0000_0000""",
   new_inumber(TkIntLit, loc(0, 0, 0), 0, Base2, 65, "10000000000000000000000000000000000000000000000000000000000000001"))

run_test_no_context("Arithmetic (-) big numbers (3)", """
    256'h0F00_0000_0000_0000_0000_0000_0000_FFFF_0000_0000_0000_0000_0000_0000_0000_0000 -
    256'h0000_0000_0000_0000_0000_0000_0000_FFFF_0000_0000_0000_0000_0000_0000_0000_1000""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 256,
   "0000111011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111000000000000"))

run_test_no_context("Arithmetic (/) truncating, unsized",
   "65 / 64", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, INTEGER_BITS, "00000000000000000000000000000001"))

run_test_no_context("Arithmetic (/) truncating, sized",
   "8'hFF / 8'h10", new_inumber(TkUIntLit, loc(0, 0, 0), 15, Base2, 8, "00001111"))

run_test_no_context("Arithmetic (/) ceiling integer",
   "(245 + 16 - 1) / 16", new_inumber(TkIntLit, loc(0, 0, 0), 16, Base2, INTEGER_BITS, "00000000000000000000000000010000"))

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

run_test_no_context("Arithmetic (/) big numbers (1)", """
   65'h1_0000_0000_0000_0000 / 2""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 65, "01000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Arithmetic (/) big numbers (2)", """
   65'sh1_0000_0000_0000_0000 / 2""",
   new_inumber(TkIntLit, loc(0, 0, 0), 0x8000000000000000, Base2, 65, "11000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Arithmetic (/) big numbers (3)", """
   65'h1_0000_0000_0000_0000 / 65'h0_0100_0000_0000_0000""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 256, Base2, 65, "00000000000000000000000000000000000000000000000000000000100000000"))

run_test_no_context("Arithmetic (/) big numbers (4)", """
    256'h0F00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 /
    256'h0000_0000_0400_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 16106127360, Base2, 256,
   "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000"))

run_test_no_context("Arithmetic (*) sized, overflow",
   "8'h80 * 8'd2", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 8, "00000000"))

run_test_no_context("Arithmetic (*) unsized, no overflow",
   "8'h80 * 2", new_inumber(TkUIntLit, loc(0, 0, 0), 256, Base2, INTEGER_BITS, "00000000000000000000000100000000"))

run_test_no_context("Arithmetic (*) real operand",
   "1.0 * 4'hF", new_fnumber(TkRealLit, loc(0, 0, 0), 15.0, "15.0"))

run_test_no_context("Arithmetic (*) big numbers (1)", """
   65'h0_4000_0000_0000_0000 * 4""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 65, "10000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Arithmetic (*) big numbers (2)", """
   65'sh0_4000_0000_0000_0000 * 4""",
   new_inumber(TkIntLit, loc(0, 0, 0), 0, Base2, 65, "10000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Arithmetic (*) big numbers (3)", """
    256'h0F00_0000_0000_0000_0000_0000_0000_000F_0000_0000_0000_0000_0000_0000_0000_0000 *
    256'h0000_0000_0000_0000_0000_0000_0000_0000_4000_0000_0000_0000_0000_0000_0000_0000""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 256,
   "1100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Arithmetic (%) unsized, signed",
   "15 % 32", new_inumber(TkIntLit, loc(0, 0, 0), 15, Base2, INTEGER_BITS, "00000000000000000000000000001111"))

run_test_no_context("Arithmetic (%) unsized, unsigned",
   "'hA % 8", new_inumber(TkUIntLit, loc(0, 0, 0), 2, Base2, INTEGER_BITS, "00000000000000000000000000000010"))

run_test_no_context("Arithmetic (%) sized, signed converted to unsigned",
   "4'sb1011 % 4'd2 // 11 % 2 = 1", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 4, "0001"))

run_test_no_context("Arithmetic (%) unsized, signed converted to unsigned",
   "-5 % 4'd2 // 4294967291 % 2", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 32, "00000000000000000000000000000001"))

run_test_no_context("Arithmetic (%) sized, signed, negative",
   "-5 % 2", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base2, 32, "11111111111111111111111111111111"))

run_test_no_context("Arithmetic (%) sized, signed, negative",
   "5 % -2", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, 32, "00000000000000000000000000000001"))

run_test_no_context("Arithmetic (%) real operand (error)", "15.0 % 32", Token(), true)

run_test_no_context("Arithmetic (%) big numbers (1)", """
   65'h0_4000_800F_0000_0002 % 4""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 2, Base2, 65, "00000000000000000000000000000000000000000000000000000000000000010"))

run_test_no_context("Arithmetic (%) big numbers (2)", """
   -65'sh0_0001_0000_0000_0001 % 4""",
   new_inumber(TkIntLit, loc(0, 0, 0), -1, Base2, 65, "11111111111111111111111111111111111111111111111111111111111111111"))

run_test_no_context("Arithmetic (%) big numbers (3)", """
    256'h0F00_0000_0000_0000_0000_0000_0000_000F_0000_0000_0000_FFFF_0000_0000_0000_0000 %
    256'h0000_0000_0000_0000_0000_0000_0000_0000_4000_0000_0000_0000_0000_0000_0000_0000""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 256,
   "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111111111110000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Arithmetic (**) unsized",
   "5 ** 2", new_inumber(TkIntLit, loc(0, 0, 0), 25, Base2, INTEGER_BITS, "00000000000000000000000000011001"))

run_test_no_context("Arithmetic (**) sized (only depends on first operand)",
   "6'd2 ** 5", new_inumber(TkUIntLit, loc(0, 0, 0), 32, Base2, 6, "100000"))

run_test_no_context("Arithmetic (**) sized, signed -> negative (kind only depends on first operand)",
   "4'sb1110 ** 'd1", new_inumber(TkIntLit, loc(0, 0, 0), -2, Base2, 4, "1110"))

run_test_no_context("Arithmetic (**) sized, signed -> even",
   "4'sb1110 ** 'd2", new_inumber(TkIntLit, loc(0, 0, 0), 4, Base2, 4, "0100"))

run_test_no_context("Arithmetic (**) sized, signed, overflow",
   "4'sb1001 ** 'd2 // (-7)^2 mod 16", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, 4, "0001"))

run_test_no_context("Arithmetic (**) x < -1, y == 0",
   "4'sb1110 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, 4, "0001"))

run_test_no_context("Arithmetic (**) x < -1, y < 0",
   "4'sb1110 ** 4'sb1110", new_inumber(TkIntLit, loc(0, 0, 0), 0, Base2, 4, "0000"))

run_test_no_context("Arithmetic (**) x == -1, y > 0, odd",
   "2'sb11 ** 3", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base2, 2, "11"))

run_test_no_context("Arithmetic (**) x == -1, y > 0, even",
   "2'sb11 ** 4", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, 2, "01"))

run_test_no_context("Arithmetic (**) x == -1, y == 0",
   "2'sb11 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, 2, "01"))

run_test_no_context("Arithmetic (**) x == -1, y < 0, odd",
   "2'sb11 ** 4'sb1101", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base2, 2, "11"))

run_test_no_context("Arithmetic (**) x == -1, y < 0, even",
   "2'sb11 ** 4'sb1100", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, 2, "01"))

run_test_no_context("Arithmetic (**) x == 0, y > 0",
   "0 ** 2", new_inumber(TkIntLit, loc(0, 0, 0), 0, Base2, INTEGER_BITS, "00000000000000000000000000000000"))

run_test_no_context("Arithmetic (**) x == 0, y == 0",
   "0 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, INTEGER_BITS, "00000000000000000000000000000001"))

run_test_no_context("Arithmetic (**) x == 0, y < 0",
   "0 ** 4'sb1110", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, INTEGER_BITS, ""))

run_test_no_context("Arithmetic (**) x == 1, y > 0",
   "1 ** 2", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, INTEGER_BITS, "00000000000000000000000000000001"))

run_test_no_context("Arithmetic (**) x == 1, y == 0",
   "1 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, INTEGER_BITS, "00000000000000000000000000000001"))

run_test_no_context("Arithmetic (**) x == 1, y < 0",
   "1 ** 4'sb1110", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, INTEGER_BITS, "00000000000000000000000000000001"))

run_test_no_context("Arithmetic (**) x > 1, y == 0",
   "32 ** 0", new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, INTEGER_BITS, "00000000000000000000000000000001"))

run_test_no_context("Arithmetic (**) x > 1, y < 0",
   "43 ** 4'sb1110", new_inumber(TkIntLit, loc(0, 0, 0), 0, Base2, INTEGER_BITS, "00000000000000000000000000000000"))

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
   "2 ** 2'sb11", new_inumber(TkIntLit, loc(0, 0, 0), 0, Base2, INTEGER_BITS, "00000000000000000000000000000000"))

run_test_no_context("Arithmetic (**) real square root",
   "9.0 ** 0.5", new_fnumber(TkRealLit, loc(0, 0, 0), 3.0, "3.0"))

run_test_no_context("Arithmetic (**) exponent truncated to zero",
   "9.0 ** (1/2)", new_fnumber(TkRealLit, loc(0, 0, 0), 1.0, "1.0"))

run_test_no_context("Arithmetic ** big numbers (1)", """
   129'h0_0000_0000_0001_0000 ** 8""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 129, "100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Arithmetic (**) big numbers (2)", """
   64'shFFFF_FFFF_0000_0001 ** 4""",
   new_inumber(TkIntLit, loc(0, 0, 0), -17179869183, Base2, 64, "1111111111111111111111111111110000000000000000000000000000000001"))

run_test_no_context("Arithmetic (**) big numbers (2)", """
   -64'shFFFF_FFFF_0000_0001 ** 0""",
   new_inumber(TkIntLit, loc(0, 0, 0), 1, Base2, 64, "0000000000000000000000000000000000000000000000000000000000000001"))

run_test_no_context("Arithmetic (%) big numbers (3)", """
    256'h0000_0000_0000_0000_0000_0000_0000_000F_0000_0000_0000_FFFF_0000_0000_0000_0000 ** 3""",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 256,
   "0000000000000000111111111111110100000000000000101111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Prefix (+) integer",
   "+3", new_inumber(TkIntLit, loc(0, 0, 0), 3, Base2, INTEGER_BITS, "00000000000000000000000000000011"))

run_test_no_context("Prefix (+) integer, sized",
   "+3'd2", new_inumber(TkUIntLit, loc(0, 0, 0), 2, Base2, 3, "010"))

run_test_no_context("Prefix (+) real",
   "+9.1", new_fnumber(TkRealLit, loc(0, 0, 0), 9.1, "9.1"))

run_test_no_context("Prefix (+) ambiguous (1)",
   "+3'b0X1", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 3, ""))

run_test_no_context("Prefix (+) ambiguous (2)",
   "+3'sb?01", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, 3, ""))

run_test_no_context("Prefix (+) big number",
   "+256'h0000_0000_0000_0000_0000_0000_0000_000F_0000_0000_0000_FFFF_0000_0000_0000_0000",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 256,
   "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000011111111111111110000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Prefix (-) integer",
   "-3", new_inumber(TkIntLit, loc(0, 0, 0), -3, Base2, INTEGER_BITS, "11111111111111111111111111111101"))

run_test_no_context("Prefix (-) integer, sized, truncated",
   "-4'd12", new_inumber(TkUIntLit, loc(0, 0, 0), 4, Base2, 4, "0100"))

run_test_no_context("Prefix (-) real",
   "-9.1", new_fnumber(TkRealLit, loc(0, 0, 0), -9.1, "-9.1"))

run_test_no_context("Prefix (-) ambiguous (1)",
   "-3'b0X1", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 3, ""))

run_test_no_context("Prefix (-) ambiguous (2)",
   "-3'sb?01", new_inumber(TkAmbIntLit, loc(0, 0, 0), 0, Base10, 3, ""))

run_test_no_context("Prefix (-) in infix expression",
   "-5 - 2", new_inumber(TkIntLit, loc(0, 0, 0), -7, Base2, INTEGER_BITS, "11111111111111111111111111111001"))

run_test_no_context("Prefix (-) big number",
   "-256'sh0000_0000_0000_0000_0000_0000_0000_000F_0000_0000_0000_FFFF_0000_0000_0000_0000",
   new_inumber(TkIntLit, loc(0, 0, 0), 0, Base2, 256,
   "1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111000011111111111111111111111111111111111111111111111100000000000000010000000000000000000000000000000000000000000000000000000000000000"))

run_test_no_context("Prefix (~) unsized",
   "~0", new_inumber(TkIntLit, loc(0, 0, 0), -1, Base2, INTEGER_BITS, "11111111111111111111111111111111"))

run_test_no_context("Prefix (~) sized, unsigned",
   "~3'b101", new_inumber(TkUIntLit, loc(0, 0, 0), 2, Base2, 3, "010"))

run_test_no_context("Prefix (~) sized, signed",
   "~3'sb010", new_inumber(TkIntLit, loc(0, 0, 0), -3, Base2, 3, "101"))

run_test_no_context("Prefix (~) ambiguous binary",
   "~3'b?10", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base2, 3, "x01"))

run_test_no_context("Prefix (~) ambiguous octal",
   "~9'Ox73", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base2, 9, "xxx000100"))

run_test_no_context("Prefix (~) ambiguous hexadecimal",
   "~16'hA_X71", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base2, 16, "0101xxxx10001110"))

run_test_no_context("Prefix (~) ambiguous decimal",
   "~16'dx", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base2, 16, "xxxxxxxxxxxxxxxx"))

run_test_no_context("Prefix (~) real (error)", "~9.0", Token(), true)

run_test_no_context("Prefix (~) big number",
   "~256'h0000_0000_0000_0000_0000_0000_0000_000F_0000_0000_0000_FFFF_0000_0000_0000_0000",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 256,
   "1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111000011111111111111111111111111111111111111111111111100000000000000001111111111111111111111111111111111111111111111111111111111111111"))

run_test_no_context("Prefix (!) zero value, unsized",
   "!0", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (!) zero value, sized",
   "!5'd0", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (!) nonzero value, unsized",
   "!32", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (!) nonzero value, sized",
   "!2'b10", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (!) real, zero value",
   "!0.0", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (!) real, zero value",
   "!4.2", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (!) ambiguous",
   "!2'bx1", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (~) big number (1)",
   "!256'h0000_0000_0000_0000_0000_0000_0000_000F_0000_0000_0000_FFFF_0000_0000_0000_0000",
   new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (~) big number (2)",
   "!256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000",
   new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (&) unsized",
   "&32", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (&) sized",
   "&3'b111", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (&) real (error)", "&3.14", Token(), true)

run_test_no_context("Prefix (&) ambiguous",
   "&12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (&) big number",
   "&256'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF",
   new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (|) unsized",
   "|'b000", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (|) sized",
   "|8'h08", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (|) ambiguous",
   "|12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (|) real (error)", "|2.14", Token(), true)

run_test_no_context("Prefix (|) big number",
   "|256'h0000_1000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000",
   new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (^) unsized",
   "^'b100", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (^) sized, even ones",
   "^4'b0011", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (^) sized, odd ones",
   "^4'b1011", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (^) ambiguous",
   "^12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (^) real (error)", "^0.14", Token(), true)

run_test_no_context("Prefix (^) big number",
   "^256'h0000_0000_0000_0010_0000_0000_0000_0000_0000_0008_0000_0000_0000_0000_0000_0001",
   new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (~&) unsized",
   "~&32", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (~&) sized",
   "~&3'b111", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (~&) ambiguous",
   "~&12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (~&) real (error)", "~&6.14", Token(), true)

run_test_no_context("Prefix (~|) unsized",
   "~|'b000", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (~|) sized",
   "~|8'h08", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (~|) ambiguous",
   "~|12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (~|) real (error)", "~|46.14", Token(), true)

run_test_no_context("Prefix (~^) unsized",
   "~^'b100", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (~^) sized, even ones",
   "~^4'b0011", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (~^) sized, odd ones",
   "~^4'b1011", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (~^) ambiguous",
   "~^12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (~^) real (error)", "~^0.5", Token(), true)

run_test_no_context("Prefix (^~) unsized",
   "^~'b100", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (^~) sized, even ones",
   "^~4'b0011", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Prefix (^~) sized, odd ones",
   "^~4'b1011", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Prefix (^~) ambiguous",
   "^~12'hx01", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Prefix (^~) real (error)", "^~0.5", Token(), true)

run_test_no_context("Infix (&&) integers, false",
   "1 && 0", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Infix (&&) integers, true",
   "1 && 1", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Infix (&&) integer/real, true",
   "16.5 && 1", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Infix (&&) integer/real, false",
   "0.0 && 1", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Infix (&&) ambiguous",
   "'dx && 1", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Infix (||) integers, false",
   "1 || 0", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Infix (||) integers, true",
   "0 || 0", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Infix (||) integer/real, true",
   "16.5 || 1", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Infix (||) integer/real, false",
   "0.0 || 0", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Infix (||) ambiguous",
   "'dx || 1", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Relational (>) unsized (1)",
   "7 > 0", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (>) unsized (2)",
   "7 > -1", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (>) unsized (3)",
   "7 > 7", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (>) sized, sign extended",
   "-3 > 3'sb100 // -3 > -4 (true)", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (>) real and converted integer",
   "0.1 > 3'sb111", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (>) ambiguous",
   "0.1 > 'dx", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Relational (>) big number and real",
   "16.0 < 256'h1000_0000_0000_0000_0000_0000_0000_0000_0000_0008_0000_0000_0000_0000_0000_0000",
   new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (>=) equality",
   "7 >= 7", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (<) unsized (1)",
   "7 < 0", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (<) unsized (2)",
   "7 < -1", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (<) unsized (3)",
   "7 < 7", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (<) sized, sign extended",
   "-3 < 3'sb100 // -3 < -4 (false)", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (<) real and converted integer",
   "0.1 < 3'sb111", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (<) ambiguous",
   "0.1 < 'dx", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Relational (>=) equality",
   "-4 <= -'d4", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (==) real and converted integer, equal",
   "45 == 45.0", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (==) sized, signed expansion (false)",
   "3'b111 == 4'sb1111", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (==) sized, signed expansion (true)",
   "3'sb111 == 4'sb1111", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (==) ambiguous",
   "'bx != 0", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Relational (!=) real and converted integer, equal",
   "45 != 45.0", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (!=) sized, signed expansion (true)",
   "3'b111 != 4'sb1111", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (!=) sized, signed expansion (false)",
   "3'sb111 != 4'sb1111", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (!=) ambiguous",
   "'bZ != 0", new_inumber(TkAmbUIntLit, loc(0, 0, 0), 0, Base10, 1, ""))

run_test_no_context("Relational (===) sized, signed expansion (false)",
   "3'b111 === 4'sb1111", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (===) sized, signed expansion (true)",
   "3'sb111 === 4'sb1111", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (===) real and converted integer",
   "33.0 === 33 ", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (===) ambiguous, no extension (false)",
   "3'b010 === 3'b?10", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))

run_test_no_context("Relational (===) ambiguous, no extension (true)",
   "6'b010xxx === 6'o2X", new_inumber(TkUIntLit, loc(0, 0, 0), 1, Base2, 1, "1"))

run_test_no_context("Relational (===) ambiguous, signed w/ extension (false)",
   "6'sb110 === 3'sbx10", new_inumber(TkUIntLit, loc(0, 0, 0), 0, Base2, 1, "0"))


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
