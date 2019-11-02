import streams
import terminal
import strformat

include ../../src/lexer/lexer

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0
   lex: Lexer

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
            echo response[i]
            echo reference[i]
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
