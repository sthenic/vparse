import streams
import terminal
import strformat

include ../../vparse/lexer/lexer

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0
   lex: Lexer


template echo_response(title, stimuli: string) =
   var response: seq[Token] = @[]
   var tok: Token
   init(tok)
   open_lexer(lex, "test", new_string_stream(stimuli))
   while true:
      get_token(lex, tok)
      if tok.type == TokenType.TkEndOfFile:
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
   open_lexer(lex, "test", new_string_stream(stimuli))
   while true:
      get_token(lex, tok)
      if tok.type == TokenType.TkEndOfFile:
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


# Constructor for a new identifier token
template init(t: Token, tt: TokenType, line, col: int) =
   init(t)
   (t.line, t.col) = (line, col)
   t.type = tt


proc new_token(t: typedesc[Token], `type`: TokenType, line, col: int): Token =
   init(result, `type`, line, col)


proc new_comment(t: typedesc[Token], line, col: int, comment: string): Token =
   init(result, TkComment, line, col)
   result.literal = comment


proc new_string_literal(t: typedesc[Token], line, col: int,
                        literal: string): Token =
   init(result, TkStrLit, line, col)
   result.literal = literal

proc new_fnumber(t: typedesc[Token], `type`: TokenType, line, col: int,
                 fnumber: float, literal: string): Token =
   init(result, type, line, col)
   result.fnumber = fnumber
   result.base = Base10
   result.literal = literal


proc new_inumber(t: typedesc[Token], `type`: TokenType, line, col: int,
                 inumber: int, base: NumericalBase, size: int,
                 literal: string): Token =
   init(result, type, line, col)
   result.inumber = inumber
   result.base = base
   result.size = size
   result.literal = literal


proc new_identifier(t: typedesc[Token], `type`: TokenType, line, col: int,
                    identifier: string): Token =
   init(result, `type`, line, col)
   result.identifier = lex.cache.get_identifier(identifier)


# Run test cases
run_test("One line comment", """
// ** This is a one line comment **
""", @[
   Token.new_comment(1, 0, "** This is a one line comment **")
])


run_test("Multi line comment", """
/* This is a multi line comment //
 * continuing over
 * here */
""", @[
   Token.new_comment(1, 0, """
This is a multi line comment //
 * continuing over
 * here""")
])

run_test("Unary operators", "+ - ! ~ & ~& | ~| ^ ~^ ^~", @[
   Token.new_identifier(TkOperator, 1, 0, "+"),
   Token.new_identifier(TkOperator, 1, 2, "-"),
   Token.new_identifier(TkOperator, 1, 4, "!"),
   Token.new_identifier(TkOperator, 1, 6, "~"),
   Token.new_identifier(TkOperator, 1, 8, "&"),
   Token.new_identifier(TkOperator, 1, 10, "~&"),
   Token.new_identifier(TkOperator, 1, 13, "|"),
   Token.new_identifier(TkOperator, 1, 15, "~|"),
   Token.new_identifier(TkOperator, 1, 18, "^"),
   Token.new_identifier(TkOperator, 1, 20, "~^"),
   Token.new_identifier(TkOperator, 1, 23, "^~")
])

run_test("Binary operators", "+ - * / % == != === !== && || ** < <= > >= & | ^ ^~ ~^ >> << >>> <<<", @[
   Token.new_identifier(TkOperator, 1, 0, "+"),
   Token.new_identifier(TkOperator, 1, 2, "-"),
   Token.new_identifier(TkOperator, 1, 4, "*"),
   Token.new_identifier(TkOperator, 1, 6, "/"),
   Token.new_identifier(TkOperator, 1, 8, "%"),
   Token.new_identifier(TkOperator, 1, 10, "=="),
   Token.new_identifier(TkOperator, 1, 13, "!="),
   Token.new_identifier(TkOperator, 1, 16, "==="),
   Token.new_identifier(TkOperator, 1, 20, "!=="),
   Token.new_identifier(TkOperator, 1, 24, "&&"),
   Token.new_identifier(TkOperator, 1, 27, "||"),
   Token.new_identifier(TkOperator, 1, 30, "**"),
   Token.new_identifier(TkOperator, 1, 33, "<"),
   Token.new_identifier(TkOperator, 1, 35, "<="),
   Token.new_identifier(TkOperator, 1, 38, ">"),
   Token.new_identifier(TkOperator, 1, 40, ">="),
   Token.new_identifier(TkOperator, 1, 43, "&"),
   Token.new_identifier(TkOperator, 1, 45, "|"),
   Token.new_identifier(TkOperator, 1, 47, "^"),
   Token.new_identifier(TkOperator, 1, 49, "^~"),
   Token.new_identifier(TkOperator, 1, 52, "~^"),
   Token.new_identifier(TkOperator, 1, 55, ">>"),
   Token.new_identifier(TkOperator, 1, 58, "<<"),
   Token.new_identifier(TkOperator, 1, 61, ">>>"),
   Token.new_identifier(TkOperator, 1, 65, "<<<")
])

run_test("Assigment operator", "=", @[
   Token.new_token(TkEquals, 1, 0)
])

run_test("Range width operator", "+: -:", @[
   Token.new_identifier(TkPlusColon, 1, 0, "+:"),
   Token.new_identifier(TkMinusColon, 1, 3, "-:")
])

run_test("Decimal number: signed", "1234567890 231", @[
   Token.new_inumber(TkIntLit, 1, 0, 1234567890, Base10, -1, "1234567890"),
   Token.new_inumber(TkIntLit, 1, 11, 231, Base10, -1, "231")
])

run_test("Decimal number: with base", "32'd2617 18'D32 'd77 'sd90 'Sd100 5'D 3", @[
   Token.new_inumber(TkUIntLit, 1, 0, 2617, Base10, 32, "2617"),
   Token.new_inumber(TkUIntLit, 1, 9, 32, Base10, 18, "32"),
   Token.new_inumber(TkUIntLit, 1, 16, 77, Base10, -1, "77"),
   Token.new_inumber(TkIntLit, 1, 21, 90, Base10, -1, "90"),
   Token.new_inumber(TkIntLit, 1, 27, 100, Base10, -1, "100"),
   Token.new_inumber(TkUIntLit, 1, 34, 3, Base10, 5, "3"),
])

run_test("Decimal number: underscore", "2617_123_", @[
   Token.new_inumber(TkIntLit, 1, 0, 2617123, Base10, -1, "2617123")
])

run_test("Decimal number: X-digit", "8'dX 7'dx 16'dX_", @[
   Token.new_inumber(TkAmbUIntLit, 1, 0, 0, Base10, 8, "x"),
   Token.new_inumber(TkAmbUIntLit, 1, 5, 0, Base10, 7, "x"),
   Token.new_inumber(TkAmbUIntLit, 1, 10, 0, Base10, 16, "x")
])

run_test("Decimal number: Z-digit", "8'dZ 7'dz 16'dZ_ 2'd?", @[
   Token.new_inumber(TkAmbUIntLit, 1, 0, 0, Base10, 8, "z"),
   Token.new_inumber(TkAmbUIntLit, 1, 5, 0, Base10, 7, "z"),
   Token.new_inumber(TkAmbUIntLit, 1, 10, 0, Base10, 16, "z"),
   Token.new_inumber(TkAmbUIntLit, 1, 17, 0, Base10, 2, "?")
])

run_test("Decimal number: negative (unary)", "-13", @[
   Token.new_identifier(TkOperator, 1, 0, "-"),
   Token.new_inumber(TkIntLit, 1, 1, 13, Base10, -1, "13")
])

run_test("Decimal number: positive (unary)", "+2", @[
   Token.new_identifier(TkOperator, 1, 0, "+"),
   Token.new_inumber(TkIntLit, 1, 1, 2, Base10, -1, "2")
])

run_test("Decimal number: invalid", "'dAF", @[
   Token.new_inumber(TkInvalid, 1, 0, 0, Base10, -1, ""),
   Token.new_identifier(TkSymbol, 1, 2, "AF")
])

run_test("Real number: simple", "3.14159", @[
   Token.new_fnumber(TkRealLit, 1, 0, 3.14159, "3.14159")
])

run_test("Real number: positive exponent", "3e2 14E2", @[
   Token.new_fnumber(TkRealLit, 1, 0, 300, "3e2"),
   Token.new_fnumber(TkRealLit, 1, 4, 1400, "14E2")
])

run_test("Real number: negative exponent", "1e-3 5E-1", @[
   Token.new_fnumber(TkRealLit, 1, 0, 0.001, "1e-3"),
   Token.new_fnumber(TkRealLit, 1, 5, 0.5, "5E-1")
])

run_test("Real number: underscore", "2_33.9_6e-2_", @[
   Token.new_fnumber(TkRealLit, 1, 0, 2.3396, "233.96e-2")
])

run_test("Real number: full", "221.45e-2", @[
   Token.new_fnumber(TkRealLit, 1, 0, 2.2145, "221.45e-2")
])

run_test("Real number: invalid (point)", "3.", @[
   Token.new_fnumber(TkInvalid, 1, 0, 0.0, "3.")
])

run_test("Real number: invalid (exponent)", "3e", @[
   Token.new_fnumber(TkInvalid, 1, 0, 0.0, "3e")
])

run_test("Real number: invalid (malformed)", "3e++", @[
   Token.new_fnumber(TkInvalid, 1, 0, 0.0, "3e+"),
   Token.new_identifier(TkOperator, 1, 3, "+")
])

run_test("Binary number: simple", "'b1010 'B0110 'Sb10 'sB11", @[
   Token.new_inumber(TkUIntLit, 1, 0, 10, Base2, -1, "1010"),
   Token.new_inumber(TkUIntLit, 1, 7, 6, Base2, -1, "0110"),
   Token.new_inumber(TkIntLit, 1, 14, 2, Base2, -1, "10"),
   Token.new_inumber(TkIntLit, 1, 20, 3, Base2, -1, "11")
])

run_test("Binary number: size", "4'b1100 8'B10000110", @[
   Token.new_inumber(TkUIntLit, 1, 0, 12, Base2, 4, "1100"),
   Token.new_inumber(TkUIntLit, 1, 8, 134, Base2, 8, "10000110"),
])

run_test("Binary number: underscore", "8'B1001_0110_", @[
   Token.new_inumber(TkUIntLit, 1, 0, 150, Base2, 8, "10010110"),
])

run_test("Binary number: invalid", "8'B 8'b11", @[
   Token.new_inumber(TkInvalid, 1, 0, 0, Base2, 8, ""),
   Token.new_inumber(TkUIntLit, 1, 4, 3, Base2, 8, "11")
])

run_test("Binary number: Z-digit", "2'b0Z 2'bz1 2'b??", @[
   Token.new_inumber(TkAmbUIntLit, 1, 0, 0, Base2, 2, "0z"),
   Token.new_inumber(TkAmbUIntLit, 1, 6, 0, Base2, 2, "z1"),
   Token.new_inumber(TkAmbUIntLit, 1, 12, 0, Base2, 2, "??"),
])

run_test("Binary number: X-digit", "2'b0X 2'bx1 2'b1_X", @[
   Token.new_inumber(TkAmbUIntLit, 1, 0, 0, Base2, 2, "0x"),
   Token.new_inumber(TkAmbUIntLit, 1, 6, 0, Base2, 2, "x1"),
   Token.new_inumber(TkAmbUIntLit, 1, 12, 0, Base2, 2, "1x"),
])

run_test("Octal number: simple", "'o072 'O0176 'so7 'SO4", @[
   Token.new_inumber(TkUIntLit, 1, 0, 58, Base8, -1, "072"),
   Token.new_inumber(TkUIntLit, 1, 6, 126, Base8, -1, "0176"),
   Token.new_inumber(TkIntLit, 1, 13, 7, Base8, -1, "7"),
   Token.new_inumber(TkIntLit, 1, 18, 4, Base8, -1, "4")
])

run_test("Octal number: size", "2'o77 6'O6721", @[
   Token.new_inumber(TkUIntLit, 1, 0, 63, Base8, 2, "77"),
   Token.new_inumber(TkUIntLit, 1, 6, 3537, Base8, 6, "6721"),
])

run_test("Octal number: underscore", "8'O54_71_02_31_", @[
   Token.new_inumber(TkUIntLit, 1, 0, 11767961, Base8, 8, "54710231"),
])

run_test("Octal number: invalid", "8'O", @[
   Token.new_inumber(TkInvalid, 1, 0, 0, Base8, 8, "")
])

run_test("Octal number: Z-digit", "2'o0Z 2'oz1 2'o??", @[
   Token.new_inumber(TkAmbUIntLit, 1, 0, 0, Base8, 2, "0z"),
   Token.new_inumber(TkAmbUIntLit, 1, 6, 0, Base8, 2, "z1"),
   Token.new_inumber(TkAmbUIntLit, 1, 12, 0, Base8, 2, "??"),
])

run_test("Octal number: X-digit", "2'o0X 2'ox1 2'o1_X", @[
   Token.new_inumber(TkAmbUIntLit, 1, 0, 0, Base8, 2, "0x"),
   Token.new_inumber(TkAmbUIntLit, 1, 6, 0, Base8, 2, "x1"),
   Token.new_inumber(TkAmbUIntLit, 1, 12, 0, Base8, 2, "1x"),
])

run_test("Hex number: simple", "'hFF 'H64 'sH77 'ShAC 'h 837FF", @[
   Token.new_inumber(TkUIntLit, 1, 0, 255, Base16, -1, "FF"),
   Token.new_inumber(TkUIntLit, 1, 5, 100, Base16, -1, "64"),
   Token.new_inumber(TkIntLit, 1, 10, 119, Base16, -1, "77"),
   Token.new_inumber(TkIntLit, 1, 16, 172, Base16, -1, "AC"),
   Token.new_inumber(TkUIntLit, 1, 22, 538623, Base16, -1, "837FF"),
])

run_test("Hex number: size", "2'hC8 4'H2301", @[
   Token.new_inumber(TkUIntLit, 1, 0, 200, Base16, 2, "C8"),
   Token.new_inumber(TkUIntLit, 1, 6, 8961, Base16, 4, "2301"),
])

run_test("Hex number: underscore", "32'hFFFF_FFFF", @[
   Token.new_inumber(TkUIntLit, 1, 0, (1 shl 32)-1, Base16, 32, "FFFFFFFF"),
])

run_test("Hex number: invalid", "8'H", @[
   Token.new_inumber(TkInvalid, 1, 0, 0, Base16, 8, "")
])

# This does not generate an invalid token. Instead it gets interpreted as a
# signed decimal number and an identifier.
run_test("Hex number: illegal", "4af", @[
   Token.new_inumber(TkIntLit, 1, 0, 4, Base10, -1, "4"),
   Token.new_identifier(TkSymbol, 1, 1, "af")
])

run_test("Hex number: Z-digit", "2'h0Z 2'hz1 2'h??", @[
   Token.new_inumber(TkAmbUIntLit, 1, 0, 0, Base16, 2, "0z"),
   Token.new_inumber(TkAmbUIntLit, 1, 6, 0, Base16, 2, "z1"),
   Token.new_inumber(TkAmbUIntLit, 1, 12, 0, Base16, 2, "??"),
])

run_test("Hex number: X-digit", "2'h0X 2'hx1 2'h1_X", @[
   Token.new_inumber(TkAmbUIntLit, 1, 0, 0, Base16, 2, "0x"),
   Token.new_inumber(TkAmbUIntLit, 1, 6, 0, Base16, 2, "x1"),
   Token.new_inumber(TkAmbUIntLit, 1, 12, 0, Base16, 2, "1x"),
])

run_test("String literal: pangram", """"The quick brown fox jumps over the lazy dog"""", @[
   Token.new_string_literal(1, 0, "The quick brown fox jumps over the lazy dog"),
])

run_test("String literal: special characters", """",<.>/?;:'[{]}\|`~1!2@3#4$5%6^7&8*9(0)-_=+"""", @[
   Token.new_string_literal(1, 0, """,<.>/?;:'[{]}\|`~1!2@3#4$5%6^7&8*9(0)-_=+"""),
])

run_test("String literal: newline (invalid)", "\"Ends abruptly\n", @[
   Token.new_token(TkInvalid, 1, 0),
])

run_test("String literal: EOF (invalid)", "\"Ends abruptly", @[
   Token.new_token(TkInvalid, 1, 0),
])

run_test("Special character: backslash", "\\", @[
   Token.new_token(TkBackslash, 1, 0),
])

run_test("Special character: comma", ",", @[
   Token.new_token(TkComma, 1, 0),
])

run_test("Special character: dot", ".", @[
   Token.new_token(TkDot, 1, 0),
])

run_test("Special character: question mark", "?", @[
   Token.new_token(TkQuestionMark, 1, 0),
])

run_test("Special character: semicolon", ";", @[
   Token.new_token(TkSemicolon, 1, 0),
])

run_test("Special character: colon", ":", @[
   Token.new_token(TkColon, 1, 0),
])

run_test("Special character: at", "@", @[
   Token.new_token(TkAt, 1, 0),
])

run_test("Special character: hash", "#", @[
   Token.new_token(TkHash, 1, 0),
])

run_test("Special character: left parenthesis", "(", @[
   Token.new_token(TkLparen, 1, 0),
])

run_test("Special character: right parenthesis", ")", @[
   Token.new_token(TkRparen, 1, 0),
])

run_test("Special character: left bracket", "[", @[
   Token.new_token(TkLbracket, 1, 0),
])

run_test("Special character: right bracket", "]", @[
   Token.new_token(TkRbracket, 1, 0),
])

run_test("Special character: left brace", "{", @[
   Token.new_token(TkLbrace, 1, 0),
])

run_test("Special character: right brace", "}", @[
   Token.new_token(TkRbrace, 1, 0),
])

run_test("Special character: left attribute (begin)", "(*", @[
   Token.new_token(TkLparenStar, 1, 0),
])

run_test("Special character: right attribute (end)", "*)", @[
   Token.new_token(TkRparenStar, 1, 0),
])

run_test("Compiler directive: default_nettype", "`default_nettype", @[
   Token.new_identifier(TkDirective, 1, 0, "default_nettype"),
])

run_test("Compiler directive: macro definition", "`define MyMacro(x) x * 2", @[
   Token.new_identifier(TkDirective, 1, 0, "define"),
   Token.new_identifier(TkSymbol, 1, 8, "MyMacro"),
   Token.new_token(TkLparen, 1, 15),
   Token.new_identifier(TkSymbol, 1, 16, "x"),
   Token.new_token(TkRparen, 1, 17),
   Token.new_identifier(TkSymbol, 1, 19, "x"),
   Token.new_identifier(TkOperator, 1, 21, "*"),
   Token.new_inumber(TkIntLit, 1, 23, 2, Base10, -1, "2")
])

run_test("Compiler directive: macro definition, multiple lines",
"""`define MyMacro(x, y) \
      x & 8'h7F + y""", @[
   Token.new_identifier(TkDirective, 1, 0, "define"),
   Token.new_identifier(TkSymbol, 1, 8, "MyMacro"),
   Token.new_token(TkLparen, 1, 15),
   Token.new_identifier(TkSymbol, 1, 16, "x"),
   Token.new_token(TkComma, 1, 17),
   Token.new_identifier(TkSymbol, 1, 19, "y"),
   Token.new_token(TkRparen, 1, 20),
   Token.new_token(TkBackslash, 1, 22),
   Token.new_identifier(TkSymbol, 2, 6, "x"),
   Token.new_identifier(TkOperator, 2, 8, "&"),
   Token.new_inumber(TkUIntLit, 2, 10, 127, Base16, 8, "7F"),
   Token.new_identifier(TkOperator, 2, 16, "+"),
   Token.new_identifier(TkSymbol, 2, 18, "y"),
])

run_test("System task or function: simple", "$display", @[
   Token.new_identifier(TkDollar, 1, 0, "display"),
])

run_test("System task or function: complex", "$$aVeryCoMpLeX_NaMe02$_", @[
   Token.new_identifier(TkDollar, 1, 0, "$aVeryCoMpLeX_NaMe02$_"),
])

run_test("Identifier: simple lowercase", "foo", @[
   Token.new_identifier(TkSymbol, 1, 0, "foo"),
])

run_test("Identifier: simple mixed case", "Foo", @[
   Token.new_identifier(TkSymbol, 1, 0, "Foo"),
])

run_test("Identifier: first character is underscore", "_bar", @[
   Token.new_identifier(TkSymbol, 1, 0, "_bar"),
])

run_test("Identifier: complex", "_MyPArAmeter10$_2$", @[
   Token.new_identifier(TkSymbol, 1, 0, "_MyPArAmeter10$_2$"),
])

run_test("Assign statement", "localparam foo = 123;", @[
   Token.new_identifier(TkLocalparam, 1, 0, "localparam"),
   Token.new_identifier(TkSymbol, 1, 11, "foo"),
   Token.new_token(TkEquals, 1, 15),
   Token.new_inumber(TkIntLit, 1, 17, 123, Base10, -1, "123"),
   Token.new_token(TkSemicolon, 1, 20),
])

run_test("Compact expression w/ integers and reals", "3+4-4.3e-3", @[
   Token.new_inumber(TkIntLit, 1, 0, 3, Base10, -1, "3"),
   Token.new_identifier(TkOperator, 1, 1, "+"),
   Token.new_inumber(TkIntLit, 1, 2, 4, Base10, -1, "4"),
   Token.new_identifier(TkOperator, 1, 3, "-"),
   Token.new_fnumber(TkRealLit, 1, 4, 0.0043, "4.3e-3")
])

run_test("Event trigger", "-> trig", @[
   Token.new_identifier(TkRightArrow, 1, 0, "->"),
   Token.new_identifier(TkSymbol, 1, 3, "trig")
])

run_test("Asynchronous event, clash w/ attribute begin", "@(*)", @[
   Token.new_token(TkAt, 1, 0),
   Token.new_token(TkLparenStar, 1, 1),
   Token.new_token(TkRparen, 1, 3),
])

run_test("Asynchronous event, whitespace separated", "@( * )", @[
   Token.new_token(TkAt, 1, 0),
   Token.new_token(TkLparen, 1, 1),
   Token.new_identifier(TkOperator, 1, 3, "*"),
   Token.new_token(TkRparen, 1, 5),
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
