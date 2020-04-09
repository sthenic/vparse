import streams
import terminal
import strformat

import ../../src/vparsepkg/preprocessor
import ../lexer/constructors


var nof_passed = 0
var nof_failed = 0
var pp: Preprocessor
var cache = new_ident_cache()


template run_test(title, stimuli: string, reference: openarray[Token]) =
   var response: seq[Token] = @[]
   var tok: Token
   init(tok)
   open_preprocessor(pp, cache, "test_default", [""], new_string_stream(stimuli))
   while true:
      get_token(pp, tok)
      if tok.kind == TkEndOfFile:
         break
      add(response, tok)
   close_preprocessor(pp)

   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      inc(nof_passed)
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      inc(nof_failed)
      detailed_compare(response, reference)


proc new_identifier(kind: TokenKind, line, col: int, identifier: string): Token =
   # Wrap the call to the identifier constructor to avoid passing the global
   # cache variable everywhere.
   new_identifier(kind, line, col, identifier, cache)


run_test("Object-like macro", """
`define WIRE wire [7:0]
`WIRE my_wire;
"""): [
   new_identifier(TkWire, 1, 13, "wire"),
   new_token(TkLbracket, 1, 18),
   new_inumber(TkIntLit, 1, 19, 7, Base10, -1, "7"),
   new_token(TkColon, 1, 20),
   new_inumber(TkIntLit, 1, 21, 0, Base10, -1, "0"),
   new_token(TkRbracket, 1, 22),
   new_identifier(TkSymbol, 2, 6, "my_wire"),
   new_token(TkSemicolon, 2, 13),
]


run_test("Object-like macro, multiline", """
`define WIRE wire \
   [7:0]
`WIRE my_wire;
"""): [
   new_identifier(TkWire, 1, 13, "wire"),
   new_token(TkLbracket, 2, 3),
   new_inumber(TkIntLit, 2, 4, 7, Base10, -1, "7"),
   new_token(TkColon, 2, 5),
   new_inumber(TkIntLit, 2, 6, 0, Base10, -1, "0"),
   new_token(TkRbracket, 2, 7),
   new_identifier(TkSymbol, 3, 6, "my_wire"),
   new_token(TkSemicolon, 3, 13),
]


run_test("Object-like macro, multiline but next line is empty", """
`define WIRE wire \

   text
`WIRE my_wire;
"""): [
   new_identifier(TkSymbol, 3, 3, "text"),
   new_identifier(TkWire, 1, 13, "wire"),
   new_identifier(TkSymbol, 4, 6, "my_wire"),
   new_token(TkSemicolon, 4, 13),
]


run_test("Nested object-like macro", """
`define HIGH 7
`define WIRE wire [`HIGH:0]
`WIRE my_wire;
"""): [
   new_identifier(TkWire, 2,  13, "wire"),
   new_token(TkLbracket, 2,  18),
   new_inumber(TkIntLit, 1,  13, 7, Base10, -1, "7"),
   new_token(TkColon, 2,  24),
   new_inumber(TkIntLit, 2,  25, 0, Base10, -1,  "0"),
   new_token(TkRbracket, 2,  26),
   new_identifier(TkSymbol, 3, 6, "my_wire"),
   new_token(TkSemicolon, 3, 13),
]


run_test("Nested object-like macros, immediate expansion", """
`define FOO foo
`define BAR `FOO
`BAR
"""): [
   new_identifier(TkSymbol, 1, 12, "foo"),
]


run_test("Nested object-like macros, reverse order of definition", """
`define BAR `FOO
`define FOO foo
`BAR
"""): [
   new_identifier(TkSymbol, 2, 12, "foo"),
]


run_test("Propagate unknown directive tokens", """
`FOO
"""): [
   new_identifier(TkDirective, 1, 0, "FOO"),
]


run_test("Object-like macro, redefinition", """
`define WIRE wire [7:0]
`WIRE my_wire;
`define WIRE wire [1:0]
`WIRE smaller_wire;
"""): [
   new_identifier(TkWire, 1, 13, "wire"),
   new_token(TkLbracket, 1, 18),
   new_inumber(TkIntLit, 1, 19, 7, Base10, -1, "7"),
   new_token(TkColon, 1, 20),
   new_inumber(TkIntLit, 1, 21, 0, Base10, -1, "0"),
   new_token(TkRbracket, 1, 22),
   new_identifier(TkSymbol, 2, 6, "my_wire"),
   new_token(TkSemicolon, 2, 13),
   new_identifier(TkWire, 3, 13, "wire"),
   new_token(TkLbracket, 3, 18),
   new_inumber(TkIntLit, 3, 19, 1, Base10, -1, "1"),
   new_token(TkColon, 3, 20),
   new_inumber(TkIntLit, 3, 21, 0, Base10, -1, "0"),
   new_token(TkRbracket, 3, 22),
   new_identifier(TkSymbol, 4, 6, "smaller_wire"),
   new_token(TkSemicolon, 4, 18),
]

run_test("`undef macro before usage", """
`define WIRE wire [7:0]
`WIRE my_wire;
`undef WIRE
`WIRE smaller_wire;
"""): [
   new_identifier(TkWire, 1, 13, "wire"),
   new_token(TkLbracket, 1, 18),
   new_inumber(TkIntLit, 1, 19, 7, Base10, -1, "7"),
   new_token(TkColon, 1, 20),
   new_inumber(TkIntLit, 1, 21, 0, Base10, -1, "0"),
   new_token(TkRbracket, 1, 22),
   new_identifier(TkSymbol, 2, 6, "my_wire"),
   new_token(TkSemicolon, 2, 13),
   new_identifier(TkDirective, 4, 0, "WIRE"),
   new_identifier(TkSymbol, 4, 6, "smaller_wire"),
   new_token(TkSemicolon, 4, 18),
]


run_test("Function-like macro", """
`define REG(width) reg [width:0]
`REG(7) a_reg;
"""): [
   new_identifier(TkReg, 1, 19, "reg"),
   new_token(TkLbracket, 1, 23),
   new_inumber(TkIntLit, 2, 5, 7, Base10, -1, "7"),
   new_token(TkColon, 1, 29),
   new_inumber(TkIntLit, 1, 30, 0, Base10, -1, "0"),
   new_token(TkRbracket, 1, 31),
   new_identifier(TkSymbol, 2, 8, "a_reg"),
   new_token(TkSemicolon, 2, 13),
]


run_test("Incorrect spacing in function-like macro -> object-like", """
`define NOT_A_FUNCTION_MACRO (value) {(value){1'b0}}
`NOT_A_FUNCTION_MACRO(8);
"""): [
   new_token(TkLparen, 1, 29),
   new_identifier(TkSymbol, 1, 30, "value"),
   new_token(TkRparen, 1, 35),
   new_token(TkLbrace, 1, 37),
   new_token(TkLparen, 1, 38),
   new_identifier(TkSymbol, 1, 39, "value"),
   new_token(TkRparen, 1, 44),
   new_token(TkLbrace, 1, 45),
   new_inumber(TkUIntLit, 1, 46, 0, Base2, 1, "0"),
   new_token(TkRbrace, 1, 50),
   new_token(TkRbrace, 1, 51),
   new_token(TkLparen, 2, 21),
   new_inumber(TkIntLit, 2, 22, 8, Base10, -1, "8"),
   new_token(TkRparen, 2, 23),
   new_token(TkSemicolon, 2, 24),
]


run_test("Nested function- & object-like macros", """
`define CONSTANT ABC
`define bar(x, y) foo `CONSTANT x y
`bar(`bar(3, `CONSTANT), bAz) (2)
"""): [
   new_identifier(TkSymbol, 2, 18, "foo"),
   new_identifier(TkSymbol, 1, 17, "ABC"),
   new_identifier(TkSymbol, 2, 18, "foo"),
   new_identifier(TkSymbol, 1, 17, "ABC"),
   new_inumber(TkIntLit, 3, 10, 3, Base10, -1, "3"),
   new_identifier(TkSymbol, 1, 17, "ABC"),
   new_identifier(TkSymbol, 3, 25, "bAz"),
   new_token(TkLparen, 3, 30),
   new_inumber(TkIntLit, 3, 31, 2, Base10, -1, "2"),
   new_token(TkRparen, 3, 32),
]

run_test("Complex macro (sv-parser case 4)", """
`define disp(clk, exp, msg) \
    always @(posedge clk) begin \
        if (!(exp)) begin \
            $display msg; \
        end \
    end \

module a ();

`disp(
    clk,
    !(a[i] && c[i]),
    ("xxx(()[]]{}}}", a[i], c[i])
);
endmodule
"""): [
   new_identifier(TkModule, 8, 0, "module"),
   new_identifier(TkSymbol, 8, 7, "a"),
   new_token(TkLparen, 8, 9),
   new_token(TkRparen, 8, 10),
   new_token(TkSemicolon, 8, 11),
   new_identifier(TkAlways, 2, 4, "always"),
   new_token(TkAt, 2, 11),
   new_token(TkLparen, 2, 12),
   new_identifier(TkPosedge, 2, 13, "posedge"),
   new_identifier(TkSymbol, 11, 4, "clk"),
   new_token(TkRparen, 2, 24),
   new_identifier(TkBegin, 2, 26, "begin"),
   new_identifier(TkIf, 3, 8, "if"),
   new_token(TkLparen, 3, 11),
   new_identifier(TkOperator, 3, 12, "!"),
   new_token(TkLparen, 3, 13),
   new_identifier(TkOperator, 12, 4, "!"),
   new_token(TkLparen, 12, 5),
   new_identifier(TkSymbol, 12, 6, "a"),
   new_token(TkLbracket, 12, 7),
   new_identifier(TkSymbol, 12, 8, "i"),
   new_token(TkRbracket, 12, 9),
   new_identifier(TkOperator, 12, 11, "&&"),
   new_identifier(TkSymbol, 12, 14, "c"),
   new_token(TkLbracket, 12, 15),
   new_identifier(TkSymbol, 12, 16, "i"),
   new_token(TkRbracket, 12, 17),
   new_token(TkRparen, 12, 18),
   new_token(TkRparen, 3, 17),
   new_token(TkRparen, 3, 18),
   new_identifier(TkBegin, 3, 20, "begin"),
   new_identifier(TkDollar, 4, 12, "display"),
   new_token(TkLparen, 13, 4),
   new_string_literal(13, 5, "xxx(()[]]{}}}"),
   new_token(TkComma, 13, 20),
   new_identifier(TkSymbol, 13, 22, "a"),
   new_token(TkLbracket, 13, 23),
   new_identifier(TkSymbol, 13, 24, "i"),
   new_token(TkRbracket, 13, 25),
   new_token(TkComma, 13, 26),
   new_identifier(TkSymbol, 13, 28, "c"),
   new_token(TkLbracket, 13, 29),
   new_identifier(TkSymbol, 13, 30, "i"),
   new_token(TkRbracket, 13, 31),
   new_token(TkRparen, 13, 32),
   new_token(TkSemicolon, 4, 24),
   new_identifier(TkEnd, 5, 8, "end"),
   new_identifier(TkEnd, 6, 4, "end"),
   new_token(TkSemicolon, 14, 1),
   new_identifier(TkEndmodule, 15, 0, "endmodule"),
]

# run_test("sv-parser case 5", """
# module a;
# `define HI Hello
# `define LO "`HI, world"
# `define H(x) "Hello, x"
# initial begin
# $display("`HI, world");
# $display(`LO);
# $display(`H(world));
# end
# endmodule
# """): [
#    new_identifier(TkSymbol, 2, 18, "foo"),
#    new_identifier(TkSymbol, 1, 17, "ABC"),
#    new_identifier(TkSymbol, 2, 18, "foo"),
#    new_identifier(TkSymbol, 1, 17, "ABC"),
#    new_inumber(TkIntLit, 3, 10, 3, Base10, -1, "3"),
#    new_identifier(TkSymbol, 1, 17, "ABC"),
#    new_identifier(TkSymbol, 3, 25, "bAz"),
#    new_token(TkLparen, 3, 30),
#    new_inumber(TkIntLit, 3, 31, 2, Base10, -1, "2"),
#    new_token(TkRparen, 3, 32),
# ]


# run_test("sv-parser case 6", """
# `define msg(x,y) `"x: `\`"y`\`"`"

# module a;
# initial begin
# $display(`msg(left side,right side));
# end
# endmodule
# # """): [
#    new_identifier(TkSymbol, 2, 18, "foo"),
#    new_identifier(TkSymbol, 1, 17, "ABC"),
#    new_identifier(TkSymbol, 2, 18, "foo"),
#    new_identifier(TkSymbol, 1, 17, "ABC"),
#    new_inumber(TkIntLit, 3, 10, 3, Base10, -1, "3"),
#    new_identifier(TkSymbol, 1, 17, "ABC"),
#    new_identifier(TkSymbol, 3, 25, "bAz"),
#    new_token(TkLparen, 3, 30),
#    new_inumber(TkIntLit, 3, 31, 2, Base10, -1, "2"),
#    new_token(TkRparen, 3, 32),
# ]


run_test("Direct recursion -> error", """
`define a `a b
`define foo `foo
`a
`foo
"""): [
   new_error_token(1, 10, "Recursive definition of a."),
   new_error_token(2, 12, "Recursive definition of foo."),
   new_identifier(TkDirective, 3, 0, "a"),
   new_identifier(TkDirective, 4, 0, "foo"),
]


# TODO: Test indirect recursion: not allowed.
# run_test("sv-parser case 8 (indirect recursion)", """
# `define b `c
# `define c `d
# `define d `e
# `define e `b
# // indirect recursion
# `b
# # """): [
# ]


# TODO: Test number of arguments mismatch: fewer, more.
# TODO: Test ignoring comments.

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
