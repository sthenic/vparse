import streams
import terminal
import strformat

import ../../src/vparsepkg/lexer
import ./constructors

var response: seq[string] = @[]
var nof_passed = 0
var nof_failed = 0
var lex: Lexer
var cache = new_ident_cache()


template echo_response(title, stimuli: string) =
   var response: seq[Token] = @[]
   var tok: Token
   init(tok)
   open_lexer(lex, "test", new_string_stream(stimuli))
   while true:
      get_token(lex, tok)
      if tok.kind == TokenKind.TkEndOfFile:
         break
      add(response, tok)
   close_lexer(lex)

   styledWriteLine(stdout, styleBright, fgYellow, "[!] ",
                   fgWhite, "Response '",  title, "'")
   for t in response:
      echo t


template run_test(title, stimuli: string; reference: seq[Token],
                  debug: bool = false) =
   var response: seq[Token] = @[]
   var tok: Token
   init(tok)
   open_lexer(lex, cache, "", new_string_stream(stimuli))
   while true:
      get_token(lex, tok)
      if tok.kind == TokenKind.TkEndOfFile:
         break
      add(response, tok)
   close_lexer(lex)

   try:
      for i in 0..<response.len:
         if debug:
            echo pretty(response[i])
            echo pretty(reference[i])
         do_assert(response[i] == reference[i], "'" & $response[i] & "'")
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   except AssertionError:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
   except IndexError:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'", #resetStyle,
                      " (missing reference data)")
      nof_failed += 1


proc new_identifier(kind: TokenKind, line, col: int, identifier: string): Token =
   # Wrap the call to the identifier constructor to avoid passing the global
   # cache variable everywhere.
   new_identifier(kind, line, col, identifier, cache)


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: Lexer
-----------------""")

# Run test cases
run_test("One line comment", """
// ** This is a one line comment **
""", @[
   new_comment(TkComment, 1, 0, " ** This is a one line comment **")
])


run_test("Multi line comment", """
/* This is a multi line comment //
 * continuing over
 * here */
""", @[
   new_comment(TkBlockComment, 1, 0, """
This is a multi line comment //
 * continuing over
 * here""")
])

run_test("Unary operators", "+ - ! ~ & ~& | ~| ^ ~^ ^~", @[
   new_identifier(TkOperator, 1, 0, "+"),
   new_identifier(TkOperator, 1, 2, "-"),
   new_identifier(TkOperator, 1, 4, "!"),
   new_identifier(TkOperator, 1, 6, "~"),
   new_identifier(TkOperator, 1, 8, "&"),
   new_identifier(TkOperator, 1, 10, "~&"),
   new_identifier(TkOperator, 1, 13, "|"),
   new_identifier(TkOperator, 1, 15, "~|"),
   new_identifier(TkOperator, 1, 18, "^"),
   new_identifier(TkOperator, 1, 20, "~^"),
   new_identifier(TkOperator, 1, 23, "^~")
])

run_test("Binary operators", "+ - * / % == != === !== && || ** < <= > >= & | ^ ^~ ~^ >> << >>> <<<", @[
   new_identifier(TkOperator, 1, 0, "+"),
   new_identifier(TkOperator, 1, 2, "-"),
   new_identifier(TkOperator, 1, 4, "*"),
   new_identifier(TkOperator, 1, 6, "/"),
   new_identifier(TkOperator, 1, 8, "%"),
   new_identifier(TkOperator, 1, 10, "=="),
   new_identifier(TkOperator, 1, 13, "!="),
   new_identifier(TkOperator, 1, 16, "==="),
   new_identifier(TkOperator, 1, 20, "!=="),
   new_identifier(TkOperator, 1, 24, "&&"),
   new_identifier(TkOperator, 1, 27, "||"),
   new_identifier(TkOperator, 1, 30, "**"),
   new_identifier(TkOperator, 1, 33, "<"),
   new_identifier(TkOperator, 1, 35, "<="),
   new_identifier(TkOperator, 1, 38, ">"),
   new_identifier(TkOperator, 1, 40, ">="),
   new_identifier(TkOperator, 1, 43, "&"),
   new_identifier(TkOperator, 1, 45, "|"),
   new_identifier(TkOperator, 1, 47, "^"),
   new_identifier(TkOperator, 1, 49, "^~"),
   new_identifier(TkOperator, 1, 52, "~^"),
   new_identifier(TkOperator, 1, 55, ">>"),
   new_identifier(TkOperator, 1, 58, "<<"),
   new_identifier(TkOperator, 1, 61, ">>>"),
   new_identifier(TkOperator, 1, 65, "<<<")
])

run_test("Assigment operator", "=", @[
   new_token(TkEquals, 1, 0)
])

run_test("Range width operator", "+: -:", @[
   new_identifier(TkPlusColon, 1, 0, "+:"),
   new_identifier(TkMinusColon, 1, 3, "-:")
])

run_test("Decimal number: signed", "1234567890 231", @[
   new_inumber(TkIntLit, 1, 0, 1234567890, Base10, -1, "1234567890"),
   new_inumber(TkIntLit, 1, 11, 231, Base10, -1, "231")
])

run_test("Decimal number: with base", "32'd2617 18'D32 'd77 'sd90 'Sd100 5'D 3", @[
   new_inumber(TkUIntLit, 1, 0, 2617, Base10, 32, "2617"),
   new_inumber(TkUIntLit, 1, 9, 32, Base10, 18, "32"),
   new_inumber(TkUIntLit, 1, 16, 77, Base10, -1, "77"),
   new_inumber(TkIntLit, 1, 21, 90, Base10, -1, "90"),
   new_inumber(TkIntLit, 1, 27, 100, Base10, -1, "100"),
   new_inumber(TkUIntLit, 1, 34, 3, Base10, 5, "3"),
])

run_test("Decimal number: underscore", "2617_123_", @[
   new_inumber(TkIntLit, 1, 0, 2617123, Base10, -1, "2617123")
])

run_test("Decimal number: X-digit", "8'dX 7'dx 16'dX_", @[
   new_inumber(TkAmbUIntLit, 1, 0, 0, Base10, 8, "x"),
   new_inumber(TkAmbUIntLit, 1, 5, 0, Base10, 7, "x"),
   new_inumber(TkAmbUIntLit, 1, 10, 0, Base10, 16, "x")
])

run_test("Decimal number: Z-digit", "8'dZ 7'dz 16'dZ_ 2'd?", @[
   new_inumber(TkAmbUIntLit, 1, 0, 0, Base10, 8, "z"),
   new_inumber(TkAmbUIntLit, 1, 5, 0, Base10, 7, "z"),
   new_inumber(TkAmbUIntLit, 1, 10, 0, Base10, 16, "z"),
   new_inumber(TkAmbUIntLit, 1, 17, 0, Base10, 2, "?")
])

run_test("Decimal number: negative (unary)", "-13", @[
   new_identifier(TkOperator, 1, 0, "-"),
   new_inumber(TkIntLit, 1, 1, 13, Base10, -1, "13")
])

run_test("Decimal number: positive (unary)", "+2", @[
   new_identifier(TkOperator, 1, 0, "+"),
   new_inumber(TkIntLit, 1, 1, 2, Base10, -1, "2")
])

run_test("Decimal number: invalid", "'dAF", @[
   new_inumber(TkInvalid, 1, 0, 0, Base10, -1, ""),
   new_identifier(TkSymbol, 1, 2, "AF")
])

run_test("Real number: simple", "3.14159", @[
   new_fnumber(TkRealLit, 1, 0, 3.14159, "3.14159")
])

run_test("Real number: positive exponent", "3e2 14E2", @[
   new_fnumber(TkRealLit, 1, 0, 300, "3e2"),
   new_fnumber(TkRealLit, 1, 4, 1400, "14E2")
])

run_test("Real number: negative exponent", "1e-3 5E-1", @[
   new_fnumber(TkRealLit, 1, 0, 0.001, "1e-3"),
   new_fnumber(TkRealLit, 1, 5, 0.5, "5E-1")
])

run_test("Real number: underscore", "2_33.9_6e-2_", @[
   new_fnumber(TkRealLit, 1, 0, 2.3396, "233.96e-2")
])

run_test("Real number: full", "221.45e-2", @[
   new_fnumber(TkRealLit, 1, 0, 2.2145, "221.45e-2")
])

run_test("Real number: invalid (point)", "3.", @[
   new_fnumber(TkInvalid, 1, 0, 0.0, "3.")
])

run_test("Real number: invalid (exponent)", "3e", @[
   new_fnumber(TkInvalid, 1, 0, 0.0, "3e")
])

run_test("Real number: invalid (malformed)", "3e++", @[
   new_fnumber(TkInvalid, 1, 0, 0.0, "3e+"),
   new_identifier(TkOperator, 1, 3, "+")
])

run_test("Binary number: simple", "'b1010 'B0110 'Sb10 'sB11", @[
   new_inumber(TkUIntLit, 1, 0, 10, Base2, -1, "1010"),
   new_inumber(TkUIntLit, 1, 7, 6, Base2, -1, "0110"),
   new_inumber(TkIntLit, 1, 14, 2, Base2, -1, "10"),
   new_inumber(TkIntLit, 1, 20, 3, Base2, -1, "11")
])

run_test("Binary number: size", "4'b1100 8'B10000110", @[
   new_inumber(TkUIntLit, 1, 0, 12, Base2, 4, "1100"),
   new_inumber(TkUIntLit, 1, 8, 134, Base2, 8, "10000110"),
])

run_test("Binary number: underscore", "8'B1001_0110_", @[
   new_inumber(TkUIntLit, 1, 0, 150, Base2, 8, "10010110"),
])

run_test("Binary number: invalid", "8'B 8'b11", @[
   new_inumber(TkInvalid, 1, 0, 0, Base2, 8, ""),
   new_inumber(TkUIntLit, 1, 4, 3, Base2, 8, "11")
])

run_test("Binary number: Z-digit", "2'b0Z 2'bz1 2'b??", @[
   new_inumber(TkAmbUIntLit, 1, 0, 0, Base2, 2, "0z"),
   new_inumber(TkAmbUIntLit, 1, 6, 0, Base2, 2, "z1"),
   new_inumber(TkAmbUIntLit, 1, 12, 0, Base2, 2, "??"),
])

run_test("Binary number: X-digit", "2'b0X 2'bx1 2'b1_X", @[
   new_inumber(TkAmbUIntLit, 1, 0, 0, Base2, 2, "0x"),
   new_inumber(TkAmbUIntLit, 1, 6, 0, Base2, 2, "x1"),
   new_inumber(TkAmbUIntLit, 1, 12, 0, Base2, 2, "1x"),
])

run_test("Octal number: simple", "'o072 'O0176 'so7 'SO4", @[
   new_inumber(TkUIntLit, 1, 0, 58, Base8, -1, "072"),
   new_inumber(TkUIntLit, 1, 6, 126, Base8, -1, "0176"),
   new_inumber(TkIntLit, 1, 13, 7, Base8, -1, "7"),
   new_inumber(TkIntLit, 1, 18, 4, Base8, -1, "4")
])

run_test("Octal number: size", "2'o77 6'O6721", @[
   new_inumber(TkUIntLit, 1, 0, 63, Base8, 2, "77"),
   new_inumber(TkUIntLit, 1, 6, 3537, Base8, 6, "6721"),
])

run_test("Octal number: underscore", "8'O54_71_02_31_", @[
   new_inumber(TkUIntLit, 1, 0, 11767961, Base8, 8, "54710231"),
])

run_test("Octal number: invalid", "8'O", @[
   new_inumber(TkInvalid, 1, 0, 0, Base8, 8, "")
])

run_test("Octal number: Z-digit", "2'o0Z 2'oz1 2'o??", @[
   new_inumber(TkAmbUIntLit, 1, 0, 0, Base8, 2, "0z"),
   new_inumber(TkAmbUIntLit, 1, 6, 0, Base8, 2, "z1"),
   new_inumber(TkAmbUIntLit, 1, 12, 0, Base8, 2, "??"),
])

run_test("Octal number: X-digit", "2'o0X 2'ox1 2'o1_X", @[
   new_inumber(TkAmbUIntLit, 1, 0, 0, Base8, 2, "0x"),
   new_inumber(TkAmbUIntLit, 1, 6, 0, Base8, 2, "x1"),
   new_inumber(TkAmbUIntLit, 1, 12, 0, Base8, 2, "1x"),
])

run_test("Hex number: simple", "'hFF 'H64 'sH77 'ShAC 'h 837FF", @[
   new_inumber(TkUIntLit, 1, 0, 255, Base16, -1, "FF"),
   new_inumber(TkUIntLit, 1, 5, 100, Base16, -1, "64"),
   new_inumber(TkIntLit, 1, 10, 119, Base16, -1, "77"),
   new_inumber(TkIntLit, 1, 16, 172, Base16, -1, "AC"),
   new_inumber(TkUIntLit, 1, 22, 538623, Base16, -1, "837FF"),
])

run_test("Hex number: size", "2'hC8 4'H2301", @[
   new_inumber(TkUIntLit, 1, 0, 200, Base16, 2, "C8"),
   new_inumber(TkUIntLit, 1, 6, 8961, Base16, 4, "2301"),
])

run_test("Hex number: underscore", "32'hFFFF_FFFF", @[
   new_inumber(TkUIntLit, 1, 0, (1 shl 32)-1, Base16, 32, "FFFFFFFF"),
])

run_test("Hex number: invalid", "8'H", @[
   new_inumber(TkInvalid, 1, 0, 0, Base16, 8, "")
])

# This does not generate an invalid token. Instead it gets interpreted as a
# signed decimal number and an identifier.
run_test("Hex number: illegal", "4af", @[
   new_inumber(TkIntLit, 1, 0, 4, Base10, -1, "4"),
   new_identifier(TkSymbol, 1, 1, "af")
])

run_test("Hex number: Z-digit", "2'h0Z 2'hz1 2'h??", @[
   new_inumber(TkAmbUIntLit, 1, 0, 0, Base16, 2, "0z"),
   new_inumber(TkAmbUIntLit, 1, 6, 0, Base16, 2, "z1"),
   new_inumber(TkAmbUIntLit, 1, 12, 0, Base16, 2, "??"),
])

run_test("Hex number: X-digit", "2'h0X 2'hx1 2'h1_X", @[
   new_inumber(TkAmbUIntLit, 1, 0, 0, Base16, 2, "0x"),
   new_inumber(TkAmbUIntLit, 1, 6, 0, Base16, 2, "x1"),
   new_inumber(TkAmbUIntLit, 1, 12, 0, Base16, 2, "1x"),
])

run_test("String literal: pangram", """"The quick brown fox jumps over the lazy dog"""", @[
   new_string_literal(1, 0, "The quick brown fox jumps over the lazy dog"),
])

run_test("String literal: special characters", """",<.>/?;:'[{]}\|`~1!2@3#4$5%6^7&8*9(0)-_=+"""", @[
   new_string_literal(1, 0, """,<.>/?;:'[{]}\|`~1!2@3#4$5%6^7&8*9(0)-_=+"""),
])

run_test("String literal: newline (invalid)", "\"Ends abruptly\n", @[
   new_token(TkInvalid, 1, 0),
])

run_test("String literal: EOF (invalid)", "\"Ends abruptly", @[
   new_token(TkInvalid, 1, 0),
])

run_test("Special character: backslash", "\\", @[
   new_token(TkBackslash, 1, 0),
])

run_test("Special character: comma", ",", @[
   new_token(TkComma, 1, 0),
])

run_test("Special character: dot", ".", @[
   new_token(TkDot, 1, 0),
])

run_test("Special character: question mark", "?", @[
   new_token(TkQuestionMark, 1, 0),
])

run_test("Special character: semicolon", ";", @[
   new_token(TkSemicolon, 1, 0),
])

run_test("Special character: colon", ":", @[
   new_token(TkColon, 1, 0),
])

run_test("Special character: at", "@", @[
   new_token(TkAt, 1, 0),
])

run_test("Special character: hash", "#", @[
   new_token(TkHash, 1, 0),
])

run_test("Special character: left parenthesis", "(", @[
   new_token(TkLparen, 1, 0),
])

run_test("Special character: right parenthesis", ")", @[
   new_token(TkRparen, 1, 0),
])

run_test("Special character: left bracket", "[", @[
   new_token(TkLbracket, 1, 0),
])

run_test("Special character: right bracket", "]", @[
   new_token(TkRbracket, 1, 0),
])

run_test("Special character: left brace", "{", @[
   new_token(TkLbrace, 1, 0),
])

run_test("Special character: right brace", "}", @[
   new_token(TkRbrace, 1, 0),
])

run_test("Special character: left attribute (begin)", "(*", @[
   new_token(TkLparenStar, 1, 0),
])

run_test("Special character: right attribute (end)", "*)", @[
   new_token(TkRparenStar, 1, 0),
])

run_test("Compiler directive: default_nettype", "`default_nettype wire", @[
   new_identifier(TkDirective, 1, 0, "default_nettype"),
   new_identifier(TkWire, 1, 17, "wire"),
])

run_test("Compiler directive: macro definition", "`define MyMacro(x) x * 2", @[
   new_identifier(TkDirective, 1, 0, "define"),
   new_identifier(TkSymbol, 1, 8, "MyMacro"),
   new_token(TkLparen, 1, 15),
   new_identifier(TkSymbol, 1, 16, "x"),
   new_token(TkRparen, 1, 17),
   new_identifier(TkSymbol, 1, 19, "x"),
   new_identifier(TkOperator, 1, 21, "*"),
   new_inumber(TkIntLit, 1, 23, 2, Base10, -1, "2"),
])

run_test("Compiler directive: macro definition, multiple lines",
"""`define MyMacro(x, y) \
      x & 8'h7F + y""", @[
   new_identifier(TkDirective, 1, 0, "define"),
   new_identifier(TkSymbol, 1, 8, "MyMacro"),
   new_token(TkLparen, 1, 15),
   new_identifier(TkSymbol, 1, 16, "x"),
   new_token(TkComma, 1, 17),
   new_identifier(TkSymbol, 1, 19, "y"),
   new_token(TkRparen, 1, 20),
   new_token(TkBackslash, 1, 22),
   new_identifier(TkSymbol, 2, 6, "x"),
   new_identifier(TkOperator, 2, 8, "&"),
   new_inumber(TkUIntLit, 2, 10, 127, Base16, 8, "7F"),
   new_identifier(TkOperator, 2, 16, "+"),
   new_identifier(TkSymbol, 2, 18, "y"),
])

run_test("Compiler directive: macro usage (no arguments)",
"""reg foo = `DEFAULT_FOO;""", @[
   new_identifier(TkReg, 1, 0, "reg"),
   new_identifier(TkSymbol, 1, 4, "foo"),
   new_token(TkEquals, 1, 8),
   new_identifier(TkDirective, 1, 10, "DEFAULT_FOO"),
   new_token(TkSemicolon, 1, 22),
])

run_test("Compiler directive: macro usage (with arguments)",
"""reg [`REGISTER_PAGE(1, 2)-1:0] bar;""", @[
   new_identifier(TkReg, 1, 0, "reg"),
   new_token(TkLbracket, 1, 4),
   new_identifier(TkDirective, 1, 5, "REGISTER_PAGE"),
   new_token(TkLparen, 1, 19),
   new_inumber(TkIntLit, 1, 20, 1, Base10, -1, "1"),
   new_token(TkComma, 1, 21),
   new_inumber(TkIntLit, 1, 23, 2, Base10, -1, "2"),
   new_token(TkRparen, 1, 24),
   new_identifier(TkOperator, 1, 25, "-"),
   new_inumber(TkIntLit, 1, 26, 1, Base10, -1, "1"),
   new_token(TkColon, 1, 27),
   new_inumber(TkIntLit, 1, 28, 0, Base10, -1, "0"),
   new_token(TkRbracket, 1, 29),
   new_identifier(TkSymbol, 1, 31, "bar"),
   new_token(TkSemicolon, 1, 34),
])

run_test("Compiler directive: macro usage (with arguments, nested parentheses)",
"""reg [`REGISTER_PAGE  ((1*`FOO), 2)-1:0] bar;""", @[
   new_identifier(TkReg, 1, 0, "reg"),
   new_token(TkLbracket, 1, 4),
   new_identifier(TkDirective, 1, 5, "REGISTER_PAGE"),
   new_token(TkLparen, 1, 21),
   new_token(TkLparen, 1, 22),
   new_inumber(TkIntLit, 1, 23, 1, Base10, -1, "1"),
   new_identifier(TkOperator, 1, 24, "*"),
   new_identifier(TkDirective, 1, 25, "FOO"),
   new_token(TkRparen, 1, 29),
   new_token(TkComma, 1, 30),
   new_inumber(TkIntLit, 1, 32, 2, Base10, -1, "2"),
   new_token(TkRparen, 1, 33),
   new_identifier(TkOperator, 1, 34, "-"),
   new_inumber(TkIntLit, 1, 35, 1, Base10, -1, "1"),
   new_token(TkColon, 1, 36),
   new_inumber(TkIntLit, 1, 37, 0, Base10, -1, "0"),
   new_token(TkRbracket, 1, 38),
   new_identifier(TkSymbol, 1, 40, "bar"),
   new_token(TkSemicolon, 1, 43),
])

run_test("System task or function: simple", "$display", @[
   new_identifier(TkDollar, 1, 0, "display"),
])

run_test("System task or function: complex", "$$aVeryCoMpLeX_NaMe02$_", @[
   new_identifier(TkDollar, 1, 0, "$aVeryCoMpLeX_NaMe02$_"),
])

run_test("Identifier: simple lowercase", "foo", @[
   new_identifier(TkSymbol, 1, 0, "foo"),
])

run_test("Identifier: simple mixed case", "Foo", @[
   new_identifier(TkSymbol, 1, 0, "Foo"),
])

run_test("Identifier: first character is underscore", "_bar", @[
   new_identifier(TkSymbol, 1, 0, "_bar"),
])

run_test("Identifier: complex", "_MyPArAmeter10$_2$", @[
   new_identifier(TkSymbol, 1, 0, "_MyPArAmeter10$_2$"),
])

run_test("Assign statement", "localparam foo = 123;", @[
   new_identifier(TkLocalparam, 1, 0, "localparam"),
   new_identifier(TkSymbol, 1, 11, "foo"),
   new_token(TkEquals, 1, 15),
   new_inumber(TkIntLit, 1, 17, 123, Base10, -1, "123"),
   new_token(TkSemicolon, 1, 20),
])

run_test("Compact expression w/ integers and reals", "3+4-4.3e-3", @[
   new_inumber(TkIntLit, 1, 0, 3, Base10, -1, "3"),
   new_identifier(TkOperator, 1, 1, "+"),
   new_inumber(TkIntLit, 1, 2, 4, Base10, -1, "4"),
   new_identifier(TkOperator, 1, 3, "-"),
   new_fnumber(TkRealLit, 1, 4, 0.0043, "4.3e-3")
])

run_test("Event trigger", "-> trig", @[
   new_identifier(TkRightArrow, 1, 0, "->"),
   new_identifier(TkSymbol, 1, 3, "trig")
])

run_test("Asynchronous event, clash w/ attribute begin", "@(*)", @[
   new_token(TkAt, 1, 0),
   new_token(TkLparenStar, 1, 1),
   new_token(TkRparen, 1, 3),
])

run_test("Asynchronous event, whitespace separated", "@( * )", @[
   new_token(TkAt, 1, 0),
   new_token(TkLparen, 1, 1),
   new_identifier(TkOperator, 1, 3, "*"),
   new_token(TkRparen, 1, 5),
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
