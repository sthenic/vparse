import streams
import terminal
import strformat

include ../../src/lexer/lexer

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0

template run_test(title, stimuli: string; reference: seq[Token],
                  debug: bool = false) =
   var response: seq[Token] = @[]
   var lex: Lexer
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


proc new_symbol(t: typedesc[Token], line, col: int, ident: string): Token =
   init(result, TkSymbol, line, col)
   result.ident = ident


proc new_comment(t: typedesc[Token], line, col: int, comment: string): Token =
   init(result, TkComment, line, col)
   result.literal = comment


proc new_keyword(t: typedesc[Token], `type`: TokenType, line, col: int): Token =
   init(result, `type`, line, col)
   result.ident = TokenTypeToStr[`type`]


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
