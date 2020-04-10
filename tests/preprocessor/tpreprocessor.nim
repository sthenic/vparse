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
   open_preprocessor(pp, cache, "tpreprocessor", ["include"], new_string_stream(stimuli))
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

# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: Preprocessor
------------------------""")


run_test("Invalid macro name -> error", """
`define "foo"
"""): [
   new_error_token(1, 8, "Invalid token given as macro name '\"foo\"'."),
]


run_test("Macro name not on the same line as the `define directive", """
`define
FOO Hello
"""): [
   new_error_token(2, 0, "The argument token 'FOO' is not on the same line as the `define directive."),
   new_identifier(TkSymbol, 2, 4, "Hello"),
]


run_test("Attempting to redefine compiler directive", """
`define define FOO
"""): [
   new_error_token(1, 8, "Attempting to redefine protected macro name 'define'."),
   new_identifier(TkSymbol, 1, 15, "FOO"),
]


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


run_test("Invalid macro name for `undef -> error", """
`undef "foo"
"""): [
   new_error_token(1, 7, "Invalid token given as macro name '\"foo\"'."),
]


run_test("Macro name not on the same line as the `undef directive.", """
`undef
FOO
"""): [
   new_error_token(2, 0, "The argument token 'FOO' is not on the same line as the `undef directive."),
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

run_test("String literals in macros (sv-parser case 5)", """
module a;
`define HI Hello
`define LO "`HI, world"
`define H(x) "Hello, x"
initial begin
$display("`HI, world");
$display(`LO);
$display(`H(world));
end
endmodule
"""): [
   new_identifier(TkModule, 1, 0, "module"),
   new_identifier(TkSymbol, 1, 7, "a"),
   new_token(TkSemicolon, 1, 8),
   new_identifier(TkInitial, 5, 0, "initial"),
   new_identifier(TkBegin, 5, 8, "begin"),
   new_identifier(TkDollar, 6, 0, "display"),
   new_token(TkLparen, 6, 8),
   new_string_literal(6, 9, "`HI, world"),
   new_token(TkRparen, 6, 21),
   new_token(TkSemicolon, 6, 22),
   new_identifier(TkDollar, 7, 0, "display"),
   new_token(TkLparen, 7, 8),
   new_string_literal(3, 11, "`HI, world"),
   new_token(TkRparen, 7, 12),
   new_token(TkSemicolon, 7, 13),
   new_identifier(TkDollar, 8, 0, "display"),
   new_token(TkLparen, 8, 8),
   new_string_literal(4, 13, "Hello, x"),
   new_token(TkRparen, 8, 18),
   new_token(TkSemicolon, 8, 19),
   new_identifier(TkEnd, 9, 0, "end"),
   new_identifier(TkEndmodule, 10, 0, "endmodule"),
]


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


run_test("Indirect recursion -> token propagates", """
`define b `c
`define c `d
`define d `e
`define e `b
`b"""): [
   # We get the `b token from `e since the preprocessor finds it at the end of
   # the expansion chain, unable to continue past it since `b is not enabled
   # for expansion in its own context. This is the way GCC does it and is not
   # incompatible with Verilog since recursive macros are not allowed outright.
   new_identifier(TkDirective, 4, 10, "b"),
]


run_test("Indirect recursion, longer replacement lists", """
`define b pre `c post
`define c pre `d post
`define d pre `e post
`define e pre `b post
`b"""): [
   new_identifier(TkSymbol, 1, 10, "pre"),
   new_identifier(TkSymbol, 2, 10, "pre"),
   new_identifier(TkSymbol, 3, 10, "pre"),
   new_identifier(TkSymbol, 4, 10, "pre"),
   new_identifier(TkDirective, 4, 14, "b"),
   new_identifier(TkSymbol, 4, 17, "post"),
   new_identifier(TkSymbol, 3, 17, "post"),
   new_identifier(TkSymbol, 2, 17, "post"),
   new_identifier(TkSymbol, 1, 17, "post"),
]


run_test("Ignoring one-line comments", """
`define foo this \
   spans \
   // surprise!
   multiple \
   lines
`foo"""): [
   new_identifier(TkSymbol, 1, 12, "this"),
   new_identifier(TkSymbol, 2, 3, "spans"),
   new_identifier(TkSymbol, 4, 3, "multiple"),
   new_identifier(TkSymbol, 5, 3, "lines"),
]


run_test("Ignoring one-line comments, next line is empty", """
`define foo this \
   // surprise!

`foo"""): [
   new_identifier(TkSymbol, 1, 12, "this"),
]


run_test("Block comments -> end macro definition", """
`define foo this \
   spans \
   /* surprise! */
   multiple \
   lines
`foo"""): [
   new_comment(TkBlockComment, 3, 3, "surprise!"),
   new_identifier(TkSymbol, 4, 3, "multiple"),
   new_token(TkBackslash, 4, 12),
   new_identifier(TkSymbol, 5, 3, "lines"),
   new_identifier(TkSymbol, 1, 12, "this"),
   new_identifier(TkSymbol, 2, 3, "spans"),
]


run_test("Example from the standard", """
`define wordsize 8
reg [1:`wordsize] data;

//define a nand with variable delay
`define var_nand(dly) nand #dly

`var_nand(2) g121 (q21, n10, n11);
`var_nand(5) g122 (q22, n10, n11);
"""): [
   new_identifier(TkReg, 2, 0, "reg"),
   new_token(TkLbracket, 2, 4),
   new_inumber(TkIntLit, 2, 5, 1, Base10, -1, "1"),
   new_token(TkColon, 2, 6),
   new_inumber(TkIntLit, 1, 17, 8, Base10, -1, "8"),
   new_token(TkRbracket, 2, 16),
   new_identifier(TkSymbol, 2, 18, "data"),
   new_token(TkSemicolon, 2, 22),
   new_comment(TkComment, 4, 0, "define a nand with variable delay"),

   new_identifier(TkNand, 5, 22, "nand"),
   new_token(TkHash, 5, 27),
   new_inumber(TkIntLit, 7, 10, 2, Base10, -1, "2"),
   new_identifier(TkSymbol, 7, 13, "g121"),
   new_token(TkLparen, 7, 18),
   new_identifier(TkSymbol, 7, 19, "q21"),
   new_token(TkComma, 7, 22),
   new_identifier(TkSymbol, 7, 24, "n10"),
   new_token(TkComma, 7, 27),
   new_identifier(TkSymbol, 7, 29, "n11"),
   new_token(TkRparen, 7, 32),
   new_token(TkSemicolon, 7, 33),

   new_identifier(TkNand, 5, 22, "nand"),
   new_token(TkHash, 5, 27),
   new_inumber(TkIntLit, 8, 10, 5, Base10, -1, "5"),
   new_identifier(TkSymbol, 8, 13, "g122"),
   new_token(TkLparen, 8, 18),
   new_identifier(TkSymbol, 8, 19, "q22"),
   new_token(TkComma, 8, 22),
   new_identifier(TkSymbol, 8, 24, "n10"),
   new_token(TkComma, 8, 27),
   new_identifier(TkSymbol, 8, 29, "n11"),
   new_token(TkRparen, 8, 32),
   new_token(TkSemicolon, 8, 33),
]


run_test("Function-like macro, missing opening parenthesis", """
`define FOO(x) x
`FOO s
"""): [
   new_error_token(2, 5, "Expected token '(', got 's'."),
]


run_test("Function-like macro, too few arguments", """
`define FOO(x, y) x and y
`FOO(1)
"""): [
   new_error_token(2, 4, "Expected 2 arguments, got 1."),
]


run_test("Function-like macro, too many arguments", """
`define FOO(x, y) x and y
`FOO(1, 2, 1, 5)
"""): [
   new_error_token(2, 4, "Expected 2 arguments, got 4."),
]


run_test("Function-like macro, unexpected end of file", """
`define FOO(x, y) x and y
`FOO(1, 2
"""): [
   new_error_token(3, 0, "Unexpected end of file."),
]


run_test("Function-like macro, missing closing parenthesis in parameter list", """
`define FOO(x, y
"""): [
   new_error_token(2, 0, "Expected token ')', got '[EOF]'."),
]


run_test("Include file", """
`include "test.vh"
wire [3:0] another_wire;
"""): [
   new_identifier(TkWire, 1, 0, "wire"),
   new_token(TkLbracket, 1, 5),
   new_inumber(TkIntLit, 1, 6, 7, Base10, -1, "7"),
   new_token(TkColon, 1, 7),
   new_inumber(TkIntLit, 1, 8, 0, Base10, -1, "0"),
   new_token(TkRbracket, 1, 9),
   new_identifier(TkSymbol, 1, 11, "my_wire"),
   new_token(TkSemicolon, 1, 18),
   new_identifier(TkWire, 2, 0, "wire"),
   new_token(TkLbracket, 2, 5),
   new_inumber(TkIntLit, 2, 6, 3, Base10, -1, "3"),
   new_token(TkColon, 2, 7),
   new_inumber(TkIntLit, 2, 8, 0, Base10, -1, "0"),
   new_token(TkRbracket, 2, 9),
   new_identifier(TkSymbol, 2, 11, "another_wire"),
   new_token(TkSemicolon, 2, 23),
]


run_test("Include file, depending on an include path", """
`include "test1.vh"
wire [3:0] another_wire;
"""): [
   new_identifier(TkReg, 1, 0, "reg"),
   new_identifier(TkSymbol, 1, 4, "a_register"),
   new_token(TkSemicolon, 1, 14),
   new_identifier(TkWire, 2, 0, "wire"),
   new_token(TkLbracket, 2, 5),
   new_inumber(TkIntLit, 2, 6, 3, Base10, -1, "3"),
   new_token(TkColon, 2, 7),
   new_inumber(TkIntLit, 2, 8, 0, Base10, -1, "0"),
   new_token(TkRbracket, 2, 9),
   new_identifier(TkSymbol, 2, 11, "another_wire"),
   new_token(TkSemicolon, 2, 23),
]


run_test("Nested include files", """
wire wire0;
`include "include/test2.vh"
wire last_wire;
"""): [
   new_identifier(TkWire, 1, 0, "wire"),
   new_identifier(TkSymbol, 1, 5, "wire0"),
   new_token(TkSemicolon, 1, 10),
   new_identifier(TkWire, 1, 0, "wire"),
   new_identifier(TkSymbol, 1, 5, "wire2"),
   new_token(TkSemicolon, 1, 10),
   new_identifier(TkWire, 1, 0, "wire"),
   new_identifier(TkSymbol, 1, 5, "wire3"),
   new_token(TkSemicolon, 1, 10),
   new_identifier(TkWire, 3, 0, "wire"),
   new_identifier(TkSymbol, 3, 5, "next_to_last_wire"),
   new_token(TkSemicolon, 3, 22),
   new_identifier(TkWire, 3, 0, "wire"),
   new_identifier(TkSymbol, 3, 5, "last_wire"),
   new_token(TkSemicolon, 3, 14),
]


run_test("Macro defined in an include file", """
`include "test4.vh"
wire [`WIDTH-1:0] my_wire;
"""): [
   new_identifier(TkWire, 2, 0, "wire"),
   new_token(TkLbracket, 2, 5),
   new_inumber(TkIntLit, 1, 14, 8, Base10, -1, "8"),
   new_identifier(TkOperator, 2, 12, "-"),
   new_inumber(TkIntLit, 2, 13, 1, Base10, -1, "1"),
   new_token(TkColon, 2, 14),
   new_inumber(TkIntLit, 2, 15, 0, Base10, -1, "0"),
   new_token(TkRbracket, 2, 16),
   new_identifier(TkSymbol, 2, 18, "my_wire"),
   new_token(TkSemicolon, 2, 25),
]


run_test("File cannot be found for `include -> error", """
`include "test_invalid.vh"
wire
"""): [
   new_error_token(1, 9, "Cannot open file 'test_invalid.vh'."),
   new_identifier(TkWire, 2, 0, "wire"),
]


run_test("Missing filename for `include -> error", """
`include
"""): [
   new_error_token(2, 0, "Expected token StrLit, got '[EOF]'."),
]


run_test("Filename not on the same line as the `include directive", """
`include
"test.vh"
"""): [
   new_error_token(2, 0, "The argument token '\"test.vh\"' is not on the same line as the `include directive."),
]


run_test("`ifdef: w/o `else, ignored", """
`ifdef FOO
   wire my_foo_wire;
`endif
reg a;
"""): [
   new_identifier(TkReg, 4, 0, "reg"),
   new_identifier(TkSymbol, 4, 4, "a"),
   new_token(TkSemicolon, 4, 5),
]


run_test("`ifdef: w/o `else, included", """
`define FOO
`ifdef FOO
   wire my_foo_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 3, 3, "wire"),
   new_identifier(TkSymbol, 3, 8, "my_foo_wire"),
   new_token(TkSemicolon, 3, 19),
   new_identifier(TkReg, 5, 0, "reg"),
   new_identifier(TkSymbol, 5, 4, "a"),
   new_token(TkSemicolon, 5, 5),
]


run_test("`ifdef: w/ `else, if-branch", """
`define FOO
`ifdef FOO
   wire my_foo_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 3, 3, "wire"),
   new_identifier(TkSymbol, 3, 8, "my_foo_wire"),
   new_token(TkSemicolon, 3, 19),
   new_identifier(TkReg, 7, 0, "reg"),
   new_identifier(TkSymbol, 7, 4, "a"),
   new_token(TkSemicolon, 7, 5),
]


run_test("`ifdef: w/ `else, else-branch", """
`ifdef FOO
   wire my_foo_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 4, 3, "wire"),
   new_identifier(TkSymbol, 4, 8, "my_else_wire"),
   new_token(TkSemicolon, 4, 20),
   new_identifier(TkReg, 6, 0, "reg"),
   new_identifier(TkSymbol, 6, 4, "a"),
   new_token(TkSemicolon, 6, 5),
]


run_test("`ifdef: w/ `elsif, if-branch", """
`define FOO
`ifdef FOO
   wire my_foo_wire;
`elsif BAR
   wire my_bar_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 3, 3, "wire"),
   new_identifier(TkSymbol, 3, 8, "my_foo_wire"),
   new_token(TkSemicolon, 3, 19),
   new_identifier(TkReg, 9, 0, "reg"),
   new_identifier(TkSymbol, 9, 4, "a"),
   new_token(TkSemicolon, 9, 5),
]


run_test("`ifdef: w/ `elsif, elsif-branch", """
`define BAR
`ifdef FOO
   wire my_foo_wire;
`elsif BAR
   wire my_bar_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 5, 3, "wire"),
   new_identifier(TkSymbol, 5, 8, "my_bar_wire"),
   new_token(TkSemicolon, 5, 19),
   new_identifier(TkReg, 9, 0, "reg"),
   new_identifier(TkSymbol, 9, 4, "a"),
   new_token(TkSemicolon, 9, 5),
]


run_test("`ifdef: w/ `elsif, else-branch", """
`ifdef FOO
   wire my_foo_wire;
`elsif BAR
   wire my_bar_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 6, 3, "wire"),
   new_identifier(TkSymbol, 6, 8, "my_else_wire"),
   new_token(TkSemicolon, 6, 20),
   new_identifier(TkReg, 8, 0, "reg"),
   new_identifier(TkSymbol, 8, 4, "a"),
   new_token(TkSemicolon, 8, 5),
]


run_test("`ifndef: w/o `else, ignored", """
`define FOO
`ifndef FOO
   wire my_foo_wire;
`endif
reg a;
"""): [
   new_identifier(TkReg, 5, 0, "reg"),
   new_identifier(TkSymbol, 5, 4, "a"),
   new_token(TkSemicolon, 5, 5),
]


run_test("`ifndef: w/o `else, included", """
`ifndef FOO
   wire my_foo_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 2, 3, "wire"),
   new_identifier(TkSymbol, 2, 8, "my_foo_wire"),
   new_token(TkSemicolon, 2, 19),
   new_identifier(TkReg, 4, 0, "reg"),
   new_identifier(TkSymbol, 4, 4, "a"),
   new_token(TkSemicolon, 4, 5),
]


run_test("`ifndef: w/ `else, if-branch", """
`ifndef FOO
   wire my_foo_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 2, 3, "wire"),
   new_identifier(TkSymbol, 2, 8, "my_foo_wire"),
   new_token(TkSemicolon, 2, 19),
   new_identifier(TkReg, 6, 0, "reg"),
   new_identifier(TkSymbol, 6, 4, "a"),
   new_token(TkSemicolon, 6, 5),
]


run_test("`ifndef: w/ `else, else-branch", """
`define FOO
`ifndef FOO
   wire my_foo_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 5, 3, "wire"),
   new_identifier(TkSymbol, 5, 8, "my_else_wire"),
   new_token(TkSemicolon, 5, 20),
   new_identifier(TkReg, 7, 0, "reg"),
   new_identifier(TkSymbol, 7, 4, "a"),
   new_token(TkSemicolon, 7, 5),
]


run_test("`ifndef: w/ `elsif, if-branch", """
`ifndef FOO
   wire my_foo_wire;
`elsif BAR
   wire my_bar_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 2, 3, "wire"),
   new_identifier(TkSymbol, 2, 8, "my_foo_wire"),
   new_token(TkSemicolon, 2, 19),
   new_identifier(TkReg, 8, 0, "reg"),
   new_identifier(TkSymbol, 8, 4, "a"),
   new_token(TkSemicolon, 8, 5),
]


run_test("`ifndef: w/ `elsif, elsif-branch", """
`define FOO
`define BAR
`ifndef FOO
   wire my_foo_wire;
`elsif BAR
   wire my_bar_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 6, 3, "wire"),
   new_identifier(TkSymbol, 6, 8, "my_bar_wire"),
   new_token(TkSemicolon, 6, 19),
   new_identifier(TkReg, 10, 0, "reg"),
   new_identifier(TkSymbol, 10, 4, "a"),
   new_token(TkSemicolon, 10, 5),
]


run_test("`ifndef: w/ `elsif, else-branch", """
`define FOO
`ifndef FOO
   wire my_foo_wire;
`elsif BAR
   wire my_bar_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, 7, 3, "wire"),
   new_identifier(TkSymbol, 7, 8, "my_else_wire"),
   new_token(TkSemicolon, 7, 20),
   new_identifier(TkReg, 9, 0, "reg"),
   new_identifier(TkSymbol, 9, 4, "a"),
   new_token(TkSemicolon, 9, 5),
]


run_test("`ifdef: nested 1", """
`ifdef FOO
   wire my_foo_wire;
   `ifdef BAR
      wire my_bar_wire;
   `else
      wire my_bar_else_wire;
   `endif
   wire another_foo_wire;
`else
   wire my_foo_else_wire;
   `ifndef BAR
      wire my_not_bar_wire;
   `else
      wire my_bar_else_wire;
   `endif
   wire another_foo_else_wire;
`endif
"""): [
   new_identifier(TkWire, 10, 3, "wire"),
   new_identifier(TkSymbol, 10, 8, "my_foo_else_wire"),
   new_token(TkSemicolon, 10, 24),
   new_identifier(TkWire, 12, 6, "wire"),
   new_identifier(TkSymbol, 12, 11, "my_not_bar_wire"),
   new_token(TkSemicolon, 12, 26),
   new_identifier(TkWire, 16, 3, "wire"),
   new_identifier(TkSymbol, 16, 8, "another_foo_else_wire"),
   new_token(TkSemicolon, 16, 29),
]


run_test("`ifdef: nested 2", """
`define FOO
`ifdef FOO
   wire my_foo_wire;
   `ifdef BAR
      wire my_bar_wire;
   `else
      wire my_bar_else_wire;
   `endif
   wire another_foo_wire;
`else
   wire my_foo_else_wire;
   `ifndef BAR
      wire my_not_bar_wire;
   `else
      wire my_bar_else_wire;
   `endif
   wire another_foo_else_wire;
`endif
"""): [
   new_identifier(TkWire, 3, 3, "wire"),
   new_identifier(TkSymbol, 3, 8, "my_foo_wire"),
   new_token(TkSemicolon, 3, 19),
   new_identifier(TkWire, 7, 6, "wire"),
   new_identifier(TkSymbol, 7, 11, "my_bar_else_wire"),
   new_token(TkSemicolon, 7, 27),
   new_identifier(TkWire, 9, 3, "wire"),
   new_identifier(TkSymbol, 9, 8, "another_foo_wire"),
   new_token(TkSemicolon, 9, 24),
]


run_test("`ifdef: nested 3", """
`define BAR
`ifdef FOO
   wire my_foo_wire;
   `ifdef BAR
      wire my_bar_wire;
   `else
      wire my_bar_else_wire;
   `endif
   wire another_foo_wire;
`else
   wire my_foo_else_wire;
   `ifndef BAR
      wire my_not_bar_wire;
   `else
      wire my_bar_else_wire;
   `endif
   wire another_foo_else_wire;
`endif
"""): [
   new_identifier(TkWire, 11, 3, "wire"),
   new_identifier(TkSymbol, 11, 8, "my_foo_else_wire"),
   new_token(TkSemicolon, 11, 24),
   new_identifier(TkWire, 15, 6, "wire"),
   new_identifier(TkSymbol, 15, 11, "my_bar_else_wire"),
   new_token(TkSemicolon, 15, 27),
   new_identifier(TkWire, 17, 3, "wire"),
   new_identifier(TkSymbol, 17, 8, "another_foo_else_wire"),
   new_token(TkSemicolon, 17, 29),
]


run_test("Conditional include: if-branch", """
`define FOO
`ifdef FOO
   `include "test1.vh"
`else
   `include "test2.vh"
`endif
"""): [
   new_identifier(TkReg, 1, 0, "reg"),
   new_identifier(TkSymbol, 1, 4, "a_register"),
   new_token(TkSemicolon, 1, 14),
]


run_test("Conditional include: else-branch", """
`ifdef FOO
   `include "test1.vh"
`else
   `include "test2.vh"
`endif
"""): [
   new_identifier(TkWire, 1, 0, "wire"),
   new_identifier(TkSymbol, 1, 5, "wire2"),
   new_token(TkSemicolon, 1, 10),
   new_identifier(TkWire, 1, 0, "wire"),
   new_identifier(TkSymbol, 1, 5, "wire3"),
   new_token(TkSemicolon, 1, 10),
   new_identifier(TkWire, 3, 0, "wire"),
   new_identifier(TkSymbol, 3, 5, "next_to_last_wire"),
   new_token(TkSemicolon, 3, 22),
]


run_test("Invalid `ifdef token -> error", """
`ifdef "FOO"
"""): [
   new_error_token(1, 7, "Expected token Symbol, got '\"FOO\"'."),
]


run_test("Macro name not on the same line as the `ifdef directive", """
`ifdef
FOO
"""): [
   new_error_token(2, 0, "The argument token 'FOO' is not on the same line as the `ifdef directive."),
]


run_test("`ifdef unexpected end of file", """
`ifdef FOO
   wire ignored_wire;
"""): [
   new_error_token(3, 0, "Unexpected end of file."),
]


run_test("Unexpected `endif", """
`endif
wire some_wire;
"""): [
   new_error_token(1, 0, "Unexpected token '`endif'."),
   new_identifier(TkWire, 2, 0, "wire"),
   new_identifier(TkSymbol, 2, 5, "some_wire"),
   new_token(TkSemicolon, 2, 14),
]


run_test("`ifdef/`else unexpected end of file", """
`ifdef FOO
`else
"""): [
   new_error_token(3, 0, "Unexpected end of file."),
]


run_test("`ifndef/`else unexpected end of file", """
`ifndef FOO
`else
"""): [
   new_error_token(3, 0, "Unexpected end of file."),
]


run_test("Unexpected `else", """
`else
wire some_wire;
"""): [
   new_error_token(1, 0, "Unexpected token '`else'."),
   new_identifier(TkWire, 2, 0, "wire"),
   new_identifier(TkSymbol, 2, 5, "some_wire"),
   new_token(TkSemicolon, 2, 14),
]


run_test("Conditional directives, broken syntax", """
`ifdef FOO
   wire my_foo_wire;
   `ifndef BAR
      wire my_bar_wire
   `endif
   `endif
`else
   wire my_else_wire;
`endif
"""): [
   new_error_token(7, 0, "Unexpected token '`else'."),
   new_identifier(TkWire, 8, 3, "wire"),
   new_identifier(TkSymbol, 8, 8, "my_else_wire"),
   new_token(TkSemicolon, 8, 20),
   new_error_token(9, 0, "Unexpected token '`endif'."),
]


run_test("Clear defines with `resetall", """
`define FOO
`ifdef FOO
   wire my_foo_wire;
`else
   wire my_else_wire;
`endif
`resetall
`ifdef FOO
   wire my_foo_wire;
`else
   wire my_else_wire;
`endif
"""): [
   new_identifier(TkWire, 3, 3, "wire"),
   new_identifier(TkSymbol, 3, 8, "my_foo_wire"),
   new_token(TkSemicolon, 3, 19),
   new_identifier(TkDirective, 7, 0, "resetall"),
   new_identifier(TkWire, 11, 3, "wire"),
   new_identifier(TkSymbol, 11, 8, "my_else_wire"),
   new_token(TkSemicolon, 11, 20),
]


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
