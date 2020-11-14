import streams
import terminal
import strformat

import ../../src/vparsepkg/preprocessor
import ../lexer/constructors


var nof_passed = 0
var nof_failed = 0
var pp: Preprocessor
var cache = new_ident_cache()
var locations: Locations
new locations


template run_test(title, stimuli: string, token_reference: openarray[Token],
                  macro_map_reference: openarray[MacroMap] = []) =
   var response: seq[Token] = @[]
   var tok: Token
   init(tok)
   init(locations)
   open_preprocessor(pp, cache, new_string_stream(stimuli),
                     new_file_map("", InvalidLocation),
                     locations, ["include"], ["EXTERNAL_FOO", "EXTERNAL_BAR=wire"])
   while true:
      get_token(pp, tok)
      if tok.kind == TkEndOfFile:
         break
      add(response, tok)
   close_preprocessor(pp)

   if response == token_reference:
      if locations.macro_maps == macro_map_reference:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_passed)
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_failed)
         detailed_compare(locations.macro_maps, macro_map_reference)
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      inc(nof_failed)
      detailed_compare(response, token_reference)


proc new_identifier(kind: TokenKind, loc: Location, identifier: string): Token =
   # Wrap the call to the identifier constructor to avoid passing the global
   # cache variable everywhere.
   new_identifier(kind, loc, identifier, cache)


proc new_error_token(line, col: int, msg: string, args: varargs[string, `$`]): Token =
   result = new_error_token(new_location(1, line, col), msg, args)


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: Preprocessor
------------------------""")


run_test("Invalid macro name -> error", """
`define "foo"
"""): [
   new_error_token(loc(1, 1, 8), "Invalid token given as macro name '\"foo\"'.")
]


run_test("Macro name not on the same line as the `define directive", """
`define
FOO Hello
"""): [
   new_error_token(2, 0, "The argument token 'FOO' is not on the same line as the `define directive."),
   new_identifier(TkSymbol, loc(1, 2, 4), "Hello"),
]


run_test("Attempting to redefine compiler directive", """
`define define FOO
"""): [
   new_error_token(loc(1, 1, 8), "Attempting to redefine protected macro name 'define'."),
   new_identifier(TkSymbol, loc(1, 1, 15), "FOO"),
]


run_test("Object-like macro", """
`define WIRE wire [7:0]
`WIRE my_wire;
""", [
   new_identifier(TkWire, loc(-1, 0, 0), "wire"),
   new_token(TkLbracket, loc(-1, 1, 0)),
   new_inumber(TkIntLit, loc(-1, 2, 0), Base10, -1, "7"),
   new_identifier(TkColon, loc(-1, 3, 0), ":"),
   new_inumber(TkIntLit, loc(-1, 4, 0), Base10, -1, "0"),
   new_token(TkRbracket, loc(-1, 5, 0)),
   new_identifier(TkSymbol, loc(1, 2, 6), "my_wire"),
   new_token(TkSemicolon, loc(1, 2, 13)),
], [
   MacroMap(
      name: "WIRE",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 2, 0),
      locations: @[
         (loc(1, 1, 13), loc(1, 1, 13)),
         (loc(1, 1, 18), loc(1, 1, 18)),
         (loc(1, 1, 19), loc(1, 1, 19)),
         (loc(1, 1, 20), loc(1, 1, 20)),
         (loc(1, 1, 21), loc(1, 1, 21)),
         (loc(1, 1, 22), loc(1, 1, 22)),
      ]
   )
])


run_test("Object-like macro, empty", """
`define FOO
`FOO
""", [])


run_test("Object-like macro, multiline", """
`define WIRE wire \
   [7:0]
`WIRE my_wire;
""", [
   new_identifier(TkWire, loc(-1, 0, 0), "wire"),
   new_token(TkLbracket, loc(-1, 1, 0)),
   new_inumber(TkIntLit, loc(-1, 2, 0), Base10, -1, "7"),
   new_identifier(TkColon, loc(-1, 3, 0), ":"),
   new_inumber(TkIntLit, loc(-1, 4, 0), Base10, -1, "0"),
   new_token(TkRbracket, loc(-1, 5, 0)),
   new_identifier(TkSymbol, loc(1, 3, 6), "my_wire"),
   new_token(TkSemicolon, loc(1, 3, 13)),
], [
   MacroMap(
      name: "WIRE",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 3, 0),
      locations: @[
         (loc(1, 1, 13), loc(1, 1, 13)),
         (loc(1, 2, 3), loc(1, 2, 3)),
         (loc(1, 2, 4), loc(1, 2, 4)),
         (loc(1, 2, 5), loc(1, 2, 5)),
         (loc(1, 2, 6), loc(1, 2, 6)),
         (loc(1, 2, 7), loc(1, 2, 7)),
      ]
   )
])


run_test("Object-like macro, multiline but next line is empty", """
`define WIRE wire \

   text
`WIRE my_wire;
""", [
   new_identifier(TkSymbol, loc(1, 3, 3), "text"),
   new_identifier(TkWire, loc(-1, 0, 0), "wire"),
   new_identifier(TkSymbol, loc(1, 4, 6), "my_wire"),
   new_token(TkSemicolon, loc(1, 4, 13)),
], [
   MacroMap(
      name: "WIRE",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 4, 0),
      locations: @[
         (loc(1, 1, 13), loc(1, 1, 13)),
      ]
   )
])


run_test("Nested object-like macro", """
`define HIGH 7
`define WIRE wire [`HIGH:0]
`WIRE my_wire;
""", [
   new_identifier(TkWire, loc(-1, 0, 0), "wire"),
   new_token(TkLbracket, loc(-1, 1, 0)),
   new_inumber(TkIntLit, loc(-2, 0, 0), Base10, -1, "7"),
   new_identifier(TkColon, loc(-1, 3, 0), ":"),
   new_inumber(TkIntLit, loc(-1, 4, 0), Base10, -1,  "0"),
   new_token(TkRbracket, loc(-1, 5, 0)),
   new_identifier(TkSymbol, loc(1, 3, 6), "my_wire"),
   new_token(TkSemicolon, loc(1, 3, 13)),
], [
   MacroMap(
      name: "WIRE",
      define_loc: loc(1, 2, 8),
      expansion_loc: loc(1, 3, 0),
      locations: @[
         (loc(1, 2, 13), loc(1, 2, 13)),
         (loc(1, 2, 18), loc(1, 2, 18)),
         (loc(1, 2, 19), loc(1, 2, 19)),
         (loc(1, 2, 24), loc(1, 2, 24)),
         (loc(1, 2, 25), loc(1, 2, 25)),
         (loc(1, 2, 26), loc(1, 2, 26)),
      ]
   ),
   MacroMap(
      name: "HIGH",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(-1, 2, 0),
      locations: @[
         (loc(1, 1, 13), loc(1, 1, 13)),
      ]
   )
])


run_test("Nested object-like macros, immediate expansion", """
`define FOO foo
`define BAR `FOO
`BAR
""", [
   new_identifier(TkSymbol, loc(-2, 0, 0), "foo"),
], [
   MacroMap(
      name: "BAR",
      define_loc: loc(1, 2, 8),
      expansion_loc: loc(1, 3, 0),
      locations: @[
         (loc(1, 2, 12), loc(1, 2, 12)),
      ]
   ),
   MacroMap(
      name: "FOO",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(-1, 0, 0),
      locations: @[
         (loc(1, 1, 12), loc(1, 1, 12)),
      ]
   )
])


run_test("Nested object-like macros, reverse order of definition", """
`define BAR `FOO
`define FOO foo
`BAR
""", [
   new_identifier(TkSymbol, loc(-2, 0, 0), "foo"),
], [
   MacroMap(
      name: "BAR",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 3, 0),
      locations: @[
         (loc(1, 1, 12), loc(1, 1, 12)),
      ]
   ),
   MacroMap(
      name: "FOO",
      define_loc: loc(1, 2, 8),
      expansion_loc: loc(-1, 0, 0),
      locations: @[
         (loc(1, 2, 12), loc(1, 2, 12)),
      ]
   )
])


run_test("Propagate unknown directive tokens", """
`FOO
"""): [
   new_identifier(TkDirective, loc(1, 1, 0), "FOO"),
]


run_test("Object-like macro, redefinition", """
`define WIRE wire [7:0]
`WIRE my_wire;
`define WIRE wire [1:0]
`WIRE smaller_wire;
""", [
   new_identifier(TkWire, loc(-1, 0, 0), "wire"),
   new_token(TkLbracket, loc(-1, 1, 0)),
   new_inumber(TkIntLit, loc(-1, 2, 0), Base10, -1, "7"),
   new_identifier(TkColon, loc(-1, 3, 0), ":"),
   new_inumber(TkIntLit, loc(-1, 4, 0), Base10, -1,  "0"),
   new_token(TkRbracket, loc(-1, 5, 0)),
   new_identifier(TkSymbol, loc(1, 2, 6), "my_wire"),
   new_token(TkSemicolon, loc(1, 2, 13)),
   new_identifier(TkWire, loc(-2, 0, 0), "wire"),
   new_token(TkLbracket, loc(-2, 1, 0)),
   new_inumber(TkIntLit, loc(-2, 2, 0), Base10, -1, "1"),
   new_identifier(TkColon, loc(-2, 3, 0), ":"),
   new_inumber(TkIntLit, loc(-2, 4, 0), Base10, -1,  "0"),
   new_token(TkRbracket, loc(-2, 5, 0)),
   new_identifier(TkSymbol, loc(1, 4, 6), "smaller_wire"),
   new_token(TkSemicolon, loc(1, 4, 18)),
], [
   MacroMap(
      name: "WIRE",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 2, 0),
      locations: @[
         (loc(1, 1, 13), loc(1, 1, 13)),
         (loc(1, 1, 18), loc(1, 1, 18)),
         (loc(1, 1, 19), loc(1, 1, 19)),
         (loc(1, 1, 20), loc(1, 1, 20)),
         (loc(1, 1, 21), loc(1, 1, 21)),
         (loc(1, 1, 22), loc(1, 1, 22)),
      ]
   ),
   MacroMap(
      name: "WIRE",
      define_loc: loc(1, 3, 8),
      expansion_loc: loc(1, 4, 0),
      locations: @[
         (loc(1, 3, 13), loc(1, 3, 13)),
         (loc(1, 3, 18), loc(1, 3, 18)),
         (loc(1, 3, 19), loc(1, 3, 19)),
         (loc(1, 3, 20), loc(1, 3, 20)),
         (loc(1, 3, 21), loc(1, 3, 21)),
         (loc(1, 3, 22), loc(1, 3, 22)),
      ]
   ),
])

run_test("`undef macro before usage", """
`define WIRE wire [7:0]
`WIRE my_wire;
`undef WIRE
`WIRE smaller_wire;
""", [
   new_identifier(TkWire, loc(-1, 0, 0), "wire"),
   new_token(TkLbracket, loc(-1, 1, 0)),
   new_inumber(TkIntLit, loc(-1, 2, 0), Base10, -1, "7"),
   new_identifier(TkColon, loc(-1, 3, 0), ":"),
   new_inumber(TkIntLit, loc(-1, 4, 0), Base10, -1,  "0"),
   new_token(TkRbracket, loc(-1, 5, 0)),
   new_identifier(TkSymbol, loc(1, 2, 6), "my_wire"),
   new_token(TkSemicolon, loc(1, 2, 13)),
   new_identifier(TkDirective, loc(1, 4, 0), "WIRE"),
   new_identifier(TkSymbol, loc(1, 4, 6), "smaller_wire"),
   new_token(TkSemicolon, loc(1, 4, 18)),
], [
   MacroMap(
      name: "WIRE",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 2, 0),
      locations: @[
         (loc(1, 1, 13), loc(1, 1, 13)),
         (loc(1, 1, 18), loc(1, 1, 18)),
         (loc(1, 1, 19), loc(1, 1, 19)),
         (loc(1, 1, 20), loc(1, 1, 20)),
         (loc(1, 1, 21), loc(1, 1, 21)),
         (loc(1, 1, 22), loc(1, 1, 22)),
      ]
   ),
])


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
""", [
   new_identifier(TkReg, loc(-1, 0, 0), "reg"),
   new_token(TkLbracket, loc(-1, 1, 0)),
   new_inumber(TkIntLit, loc(-1, 2, 0), Base10, -1, "7"),
   new_identifier(TkColon, loc(-1, 3, 0), ":"),
   new_inumber(TkIntLit, loc(-1, 4, 0), Base10, -1, "0"),
   new_token(TkRbracket, loc(-1, 5, 0)),
   new_identifier(TkSymbol, loc(1, 2, 8), "a_reg"),
   new_token(TkSemicolon, loc(1, 2, 13)),
], [
   MacroMap(
      name: "REG",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 2, 0),
      locations: @[
         (loc(1, 1, 19), loc(1, 1, 19)),
         (loc(1, 1, 23), loc(1, 1, 23)),
         (loc(1, 2, 5), loc(1, 1, 24)),
         (loc(1, 1, 29), loc(1, 1, 29)),
         (loc(1, 1, 30), loc(1, 1, 30)),
         (loc(1, 1, 31), loc(1, 1, 31)),
      ]
   ),
])


run_test("Function-like macro, empty", """
`define FOO(x, y)
`FOO (1, 2)
""", [])


run_test("Incorrect spacing in function-like macro -> object-like", """
`define NOT_A_FUNCTION_MACRO (value) {(value){1'b0}}
`NOT_A_FUNCTION_MACRO(8);
""", [
   new_token(TkLparen, loc(-1, 0, 0)),
   new_identifier(TkSymbol, loc(-1, 1, 0), "value"),
   new_token(TkRparen, loc(-1, 2, 0)),
   new_token(TkLbrace, loc(-1, 3, 0)),
   new_token(TkLparen, loc(-1, 4, 0)),
   new_identifier(TkSymbol, loc(-1, 5, 0), "value"),
   new_token(TkRparen, loc(-1, 6, 0)),
   new_token(TkLbrace, loc(-1, 7, 0)),
   new_inumber(TkUIntLit, loc(-1, 8, 0), Base2, 1, "0"),
   new_token(TkRbrace, loc(-1, 9, 0)),
   new_token(TkRbrace, loc(-1, 10, 0)),
   new_token(TkLparen, loc(1, 2, 21)),
   new_inumber(TkIntLit, loc(1, 2, 22), Base10, -1, "8"),
   new_token(TkRparen, loc(1, 2, 23)),
   new_token(TkSemicolon, loc(1, 2, 24)),
], [
   MacroMap(
      name: "NOT_A_FUNCTION_MACRO",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 2, 0),
      locations: @[
         (loc(1, 1, 29), loc(1, 1, 29)),
         (loc(1, 1, 30), loc(1, 1, 30)),
         (loc(1, 1, 35), loc(1, 1, 35)),
         (loc(1, 1, 37), loc(1, 1, 37)),
         (loc(1, 1, 38), loc(1, 1, 38)),
         (loc(1, 1, 39), loc(1, 1, 39)),
         (loc(1, 1, 44), loc(1, 1, 44)),
         (loc(1, 1, 45), loc(1, 1, 45)),
         (loc(1, 1, 46), loc(1, 1, 46)),
         (loc(1, 1, 50), loc(1, 1, 50)),
         (loc(1, 1, 51), loc(1, 1, 51)),
      ]
   ),
])


run_test("Nested function- & object-like macros", """
`define CONSTANT ABC
`define bar(x, y) foo `CONSTANT x y
`bar(`bar(3, `CONSTANT), bAz) (2)
""", [
   new_identifier(TkSymbol, loc(-4, 0, 0), "foo"),
   new_identifier(TkSymbol, loc(-5, 0, 0), "ABC"),
   new_identifier(TkSymbol, loc(-4, 2, 0), "foo"),
   new_identifier(TkSymbol, loc(-4, 3, 0), "ABC"),
   new_inumber(TkIntLit, loc(-4, 4, 0), Base10, -1, "3"),
   new_identifier(TkSymbol, loc(-4, 5, 0), "ABC"),
   new_identifier(TkSymbol, loc(-4, 6, 0), "bAz"),
   new_token(TkLparen, loc(1, 3, 30)),
   new_inumber(TkIntLit, loc(1, 3, 31), Base10, -1, "2"),
   new_token(TkRparen, loc(1, 3, 32)),
], [
   MacroMap(
      name: "CONSTANT",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 3, 13),
      locations: @[
         (loc(1, 1, 17), loc(1, 1, 17)),
      ]
   ),
   MacroMap(
      name: "bar",
      define_loc: loc(1, 2, 8),
      expansion_loc: loc(1, 3, 5),
      locations: @[
         (loc(1, 2, 18), loc(1, 2, 18)),
         (loc(1, 2, 22), loc(1, 2, 22)),
         (loc(1, 3, 10), loc(1, 2, 32)),
         (loc(-1, 0, 0), loc(1, 2, 34)),
      ]
   ),
   MacroMap(
      name: "CONSTANT",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(-2, 1, 0),
      locations: @[
         (loc(1, 1, 17), loc(1, 1, 17)),
      ]
   ),
   MacroMap(
      name: "bar",
      define_loc: loc(1, 2, 8),
      expansion_loc: loc(1, 3, 0),
      locations: @[
         (loc(1, 2, 18), loc(1, 2, 18)),
         (loc(1, 2, 22), loc(1, 2, 22)),
         (loc(-2, 0, 0), loc(1, 2, 32)),
         (loc(-3, 0, 0), loc(1, 2, 32)),
         (loc(-2, 2, 0), loc(1, 2, 32)),
         (loc(-2, 3, 0), loc(1, 2, 32)),
         (loc(1, 3, 25), loc(1, 2, 34)),
      ]
   ),
   MacroMap(
      name: "CONSTANT",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(-4, 1, 0),
      locations: @[
         (loc(1, 1, 17), loc(1, 1, 17)),
      ]
   ),
])

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
""", [
   new_identifier(TkModule, loc(1, 8, 0), "module"),
   new_identifier(TkSymbol, loc(1, 8, 7), "a"),
   new_token(TkLparen, loc(1, 8, 9)),
   new_token(TkRparen, loc(1, 8, 10)),
   new_token(TkSemicolon, loc(1, 8, 11)),
   new_identifier(TkAlways, loc(-1, 0, 0), "always"),
   new_token(TkAt, loc(-1, 1, 0)),
   new_token(TkLparen, loc(-1, 2, 0)),
   new_identifier(TkPosedge, loc(-1, 3, 0), "posedge"),
   new_identifier(TkSymbol, loc(-1, 4, 0), "clk"),
   new_token(TkRparen, loc(-1, 5, 0)),
   new_identifier(TkBegin, loc(-1, 6, 0), "begin"),
   new_identifier(TkIf, loc(-1, 7, 0), "if"),
   new_token(TkLparen, loc(-1, 8, 0)),
   new_identifier(TkOperator, loc(-1, 9, 0), "!"),
   new_token(TkLparen, loc(-1, 10, 0)),
   new_identifier(TkOperator, loc(-1, 11, 0), "!"),
   new_token(TkLparen, loc(-1, 12, 0)),
   new_identifier(TkSymbol, loc(-1, 13, 0), "a"),
   new_token(TkLbracket, loc(-1, 14, 0)),
   new_identifier(TkSymbol, loc(-1, 15, 0), "i"),
   new_token(TkRbracket, loc(-1, 16, 0)),
   new_identifier(TkOperator, loc(-1, 17, 0), "&&"),
   new_identifier(TkSymbol, loc(-1, 18, 0), "c"),
   new_token(TkLbracket, loc(-1, 19, 0)),
   new_identifier(TkSymbol, loc(-1, 20, 0), "i"),
   new_token(TkRbracket, loc(-1, 21, 0)),
   new_token(TkRparen, loc(-1, 22, 0)),
   new_token(TkRparen, loc(-1, 23, 0)),
   new_token(TkRparen, loc(-1, 24, 0)),
   new_identifier(TkBegin, loc(-1, 25, 0), "begin"),
   new_identifier(TkDollar, loc(-1, 26, 0), "display"),
   new_token(TkLparen, loc(-1, 27, 0)),
   new_string_literal(loc(-1, 28, 0), "xxx(()[]]{}}}"),
   new_token(TkComma, loc(-1, 29, 0)),
   new_identifier(TkSymbol, loc(-1, 30, 0), "a"),
   new_token(TkLbracket, loc(-1, 31, 0)),
   new_identifier(TkSymbol, loc(-1, 32, 0), "i"),
   new_token(TkRbracket, loc(-1, 33, 0)),
   new_token(TkComma, loc(-1, 34, 0)),
   new_identifier(TkSymbol, loc(-1, 35, 0), "c"),
   new_token(TkLbracket, loc(-1, 36, 0)),
   new_identifier(TkSymbol, loc(-1, 37, 0), "i"),
   new_token(TkRbracket, loc(-1, 38, 0)),
   new_token(TkRparen, loc(-1, 39, 0)),
   new_token(TkSemicolon, loc(-1, 40, 0)),
   new_identifier(TkEnd, loc(-1, 41, 0), "end"),
   new_identifier(TkEnd, loc(-1, 42, 0), "end"),
   new_token(TkSemicolon, loc(1, 14, 1)),
   new_identifier(TkEndmodule, loc(1, 15, 0), "endmodule"),
], [
   MacroMap(
      name: "disp",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 10, 0),
      locations: @[
         (loc(1, 2, 4), loc(1, 2, 4)),
         (loc(1, 2, 11), loc(1, 2, 11)),
         (loc(1, 2, 12), loc(1, 2, 12)),
         (loc(1, 2, 13), loc(1, 2, 13)),
         (loc(1, 11, 4), loc(1, 2, 21)),
         (loc(1, 2, 24), loc(1, 2, 24)),
         (loc(1, 2, 26), loc(1, 2, 26)),
         (loc(1, 3, 8), loc(1, 3, 8)),
         (loc(1, 3, 11), loc(1, 3, 11)),
         (loc(1, 3, 12), loc(1, 3, 12)),
         (loc(1, 3, 13), loc(1, 3, 13)),
         (loc(1, 12, 4), loc(1, 3, 14)),
         (loc(1, 12, 5), loc(1, 3, 14)),
         (loc(1, 12, 6), loc(1, 3, 14)),
         (loc(1, 12, 7), loc(1, 3, 14)),
         (loc(1, 12, 8), loc(1, 3, 14)),
         (loc(1, 12, 9), loc(1, 3, 14)),
         (loc(1, 12, 11), loc(1, 3, 14)),
         (loc(1, 12, 14), loc(1, 3, 14)),
         (loc(1, 12, 15), loc(1, 3, 14)),
         (loc(1, 12, 16), loc(1, 3, 14)),
         (loc(1, 12, 17), loc(1, 3, 14)),
         (loc(1, 12, 18), loc(1, 3, 14)),
         (loc(1, 3, 17), loc(1, 3, 17)),
         (loc(1, 3, 18), loc(1, 3, 18)),
         (loc(1, 3, 20), loc(1, 3, 20)),
         (loc(1, 4, 12), loc(1, 4, 12)),
         (loc(1, 13, 4), loc(1, 4, 21)),
         (loc(1, 13, 5), loc(1, 4, 21)),
         (loc(1, 13, 20), loc(1, 4, 21)),
         (loc(1, 13, 22), loc(1, 4, 21)),
         (loc(1, 13, 23), loc(1, 4, 21)),
         (loc(1, 13, 24), loc(1, 4, 21)),
         (loc(1, 13, 25), loc(1, 4, 21)),
         (loc(1, 13, 26), loc(1, 4, 21)),
         (loc(1, 13, 28), loc(1, 4, 21)),
         (loc(1, 13, 29), loc(1, 4, 21)),
         (loc(1, 13, 30), loc(1, 4, 21)),
         (loc(1, 13, 31), loc(1, 4, 21)),
         (loc(1, 13, 32), loc(1, 4, 21)),
         (loc(1, 4, 24), loc(1, 4, 24)),
         (loc(1, 5, 8), loc(1, 5, 8)),
         (loc(1, 6, 4), loc(1, 6, 4)),
      ]
   ),
])


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
""", [
   new_identifier(TkModule, loc(1, 1, 0), "module"),
   new_identifier(TkSymbol, loc(1, 1, 7), "a"),
   new_token(TkSemicolon, loc(1, 1, 8)),
   new_identifier(TkInitial, loc(1, 5, 0), "initial"),
   new_identifier(TkBegin, loc(1, 5, 8), "begin"),
   new_identifier(TkDollar, loc(1, 6, 0), "display"),
   new_token(TkLparen, loc(1, 6, 8)),
   new_string_literal(loc(1, 6, 9), "`HI, world"),
   new_token(TkRparen, loc(1, 6, 21)),
   new_token(TkSemicolon, loc(1, 6, 22)),
   new_identifier(TkDollar, loc(1, 7, 0), "display"),
   new_token(TkLparen, loc(1, 7, 8)),
   new_string_literal(loc(-1, 0, 0), "`HI, world"),
   new_token(TkRparen, loc(1, 7, 12)),
   new_token(TkSemicolon, loc(1, 7, 13)),
   new_identifier(TkDollar, loc(1, 8, 0), "display"),
   new_token(TkLparen, loc(1, 8, 8)),
   new_string_literal(loc(-2, 0, 0), "Hello, x"),
   new_token(TkRparen, loc(1, 8, 18)),
   new_token(TkSemicolon, loc(1, 8, 19)),
   new_identifier(TkEnd, loc(1, 9, 0), "end"),
   new_identifier(TkEndmodule, loc(1, 10, 0), "endmodule"),
], [
   MacroMap(
      name: "LO",
      define_loc: loc(1, 3, 8),
      expansion_loc: loc(1, 7, 9),
      locations: @[
         (loc(1, 3, 11), loc(1, 3, 11)),
      ]
   ),
   MacroMap(
      name: "H",
      define_loc: loc(1, 4, 8),
      expansion_loc: loc(1, 8, 9),
      locations: @[
         (loc(1, 4, 13), loc(1, 4, 13)),
      ]
   ),
])


run_test("Direct recursion -> error", """
`define a `a b
`define foo `foo
`a
`foo
"""): [
   new_error_token(1, 10, "Recursive definition of a."),
   new_error_token(2, 12, "Recursive definition of foo."),
   new_identifier(TkDirective, loc(1, 3, 0), "a"),
   new_identifier(TkDirective, loc(1, 4, 0), "foo"),
]


run_test("Indirect recursion -> token propagates", """
`define b `c
`define c `d
`define d `e
`define e `b
`b""", [
   # We get the `b token from `e since the preprocessor finds it at the end of
   # the expansion chain, unable to continue past it since `b is not enabled
   # for expansion in its own context. This is the way GCC does it and is not
   # incompatible with Verilog since recursive macros are not allowed outright.
   new_identifier(TkDirective, loc(-4, 0, 0), "b"),
], [
   MacroMap(
      name: "b",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 5, 0),
      locations: @[
         (loc(1, 1, 10), loc(1, 1, 10)),
      ]
   ),
   MacroMap(
      name: "c",
      define_loc: loc(1, 2, 8),
      expansion_loc: loc(-1, 0, 0),
      locations: @[
         (loc(1, 2, 10), loc(1, 2, 10)),
      ]
   ),
   MacroMap(
      name: "d",
      define_loc: loc(1, 3, 8),
      expansion_loc: loc(-2, 0, 0),
      locations: @[
         (loc(1, 3, 10), loc(1, 3, 10)),
      ]
   ),
   MacroMap(
      name: "e",
      define_loc: loc(1, 4, 8),
      expansion_loc: loc(-3, 0, 0),
      locations: @[
         (loc(1, 4, 10), loc(1, 4, 10)),
      ]
   ),
])


run_test("Indirect recursion, longer replacement lists", """
`define b pre `c post
`define c pre `d post
`define d pre `e post
`define e pre `b post
`b""", [
   new_identifier(TkSymbol, loc(-1, 0, 0), "pre"),
   new_identifier(TkSymbol, loc(-2, 0, 0), "pre"),
   new_identifier(TkSymbol, loc(-3, 0, 0), "pre"),
   new_identifier(TkSymbol, loc(-4, 0, 0), "pre"),
   new_identifier(TkDirective, loc(-4, 1, 0), "b"),
   new_identifier(TkSymbol, loc(-4, 2, 0), "post"),
   new_identifier(TkSymbol, loc(-3, 2, 0), "post"),
   new_identifier(TkSymbol, loc(-2, 2, 0), "post"),
   new_identifier(TkSymbol, loc(-1, 2, 0), "post"),
], [
   MacroMap(
      name: "b",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 5, 0),
      locations: @[
         (loc(1, 1, 10), loc(1, 1, 10)),
         (loc(1, 1, 14), loc(1, 1, 14)),
         (loc(1, 1, 17), loc(1, 1, 17)),
      ]
   ),
   MacroMap(
      name: "c",
      define_loc: loc(1, 2, 8),
      expansion_loc: loc(-1, 1, 0),
      locations: @[
         (loc(1, 2, 10), loc(1, 2, 10)),
         (loc(1, 2, 14), loc(1, 2, 14)),
         (loc(1, 2, 17), loc(1, 2, 17)),
      ]
   ),
   MacroMap(
      name: "d",
      define_loc: loc(1, 3, 8),
      expansion_loc: loc(-2, 1, 0),
      locations: @[
         (loc(1, 3, 10), loc(1, 3, 10)),
         (loc(1, 3, 14), loc(1, 3, 14)),
         (loc(1, 3, 17), loc(1, 3, 17)),
      ]
   ),
   MacroMap(
      name: "e",
      define_loc: loc(1, 4, 8),
      expansion_loc: loc(-3, 1, 0),
      locations: @[
         (loc(1, 4, 10), loc(1, 4, 10)),
         (loc(1, 4, 14), loc(1, 4, 14)),
         (loc(1, 4, 17), loc(1, 4, 17)),
      ]
   ),
])


run_test("Ignoring one-line comments", """
`define  foo this \
   spans \
   // surprise!
   multiple \
   lines
`foo""", [
   new_identifier(TkSymbol, loc(-1, 0, 0), "this"),
   new_identifier(TkSymbol, loc(-1, 1, 0), "spans"),
   new_identifier(TkSymbol, loc(-1, 2, 0), "multiple"),
   new_identifier(TkSymbol, loc(-1, 3, 0), "lines"),
], [
   MacroMap(
      name: "foo",
      define_loc: loc(1, 1, 9),
      expansion_loc: loc(1, 6, 0),
      locations: @[
         (loc(1, 1, 13), loc(1, 1, 13)),
         (loc(1, 2, 3), loc(1, 2, 3)),
         (loc(1, 4, 3), loc(1, 4, 3)),
         (loc(1, 5, 3), loc(1, 5, 3))
      ]
   ),
])

run_test("Ignoring one-line comments, next line is empty", """
`define foo this \
   // surprise!

`foo""", [
   new_identifier(TkSymbol, loc(-1, 0, 0), "this"),
], [
   MacroMap(
      name: "foo",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 4, 0),
      locations: @[
         (loc(1, 1, 12), loc(1, 1, 12))
      ]
   ),
])


run_test("Ignoring block comments", """
`define foo this \
   spans \
   /* surprise! */
   multiple \
   lines
`foo""", [
   new_identifier(TkSymbol, loc(-1, 0, 0), "this"),
   new_identifier(TkSymbol, loc(-1, 1, 0), "spans"),
   new_identifier(TkSymbol, loc(-1, 2, 0), "multiple"),
   new_identifier(TkSymbol, loc(-1, 3, 0), "lines"),
], [
   MacroMap(
      name: "foo",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 6, 0),
      locations: @[
         (loc(1, 1, 12), loc(1, 1, 12)),
         (loc(1, 2, 3), loc(1, 2, 3)),
         (loc(1, 4, 3), loc(1, 4, 3)),
         (loc(1, 5, 3), loc(1, 5, 3))
      ]
   ),
])


run_test("Keeping comment at the end of the replacement list", """
`define AND(x, y) (x & y)
/* Docstring for `WIDTH_FROM_HEADER`. */
localparam WIDTH_FROM_HEADER = 8;
""", [
   new_comment(TkBlockComment, loc(1, 2, 0), "Docstring for `WIDTH_FROM_HEADER`."),
   new_identifier(TkLocalparam, loc(1, 3, 0), "localparam"),
   new_identifier(TkSymbol, loc(1, 3, 11), "WIDTH_FROM_HEADER"),
   new_token(TkEquals, loc(1, 3, 29)),
   new_inumber(TkIntLit, loc(1, 3, 31), Base10, -1, "8"),
   new_token(TkSemicolon, loc(1, 3, 32)),
], [])


run_test("Example from the standard", """
`define wordsize 8
reg [1:`wordsize] data;

//define a nand with variable delay
`define var_nand(dly) nand #dly

`var_nand(2) g121 (q21, n10, n11);
`var_nand(5) g122 (q22, n10, n11);
""", [
   new_identifier(TkReg, loc(1, 2, 0), "reg"),
   new_token(TkLbracket, loc(1, 2, 4)),
   new_inumber(TkIntLit, loc(1, 2, 5), Base10, -1, "1"),
   new_identifier(TkColon, loc(1, 2, 6), ":"),
   new_inumber(TkIntLit, loc(-1, 0, 0), Base10, -1, "8"),
   new_token(TkRbracket, loc(1, 2, 16)),
   new_identifier(TkSymbol, loc(1, 2, 18), "data"),
   new_token(TkSemicolon, loc(1, 2, 22)),

   new_identifier(TkNand, loc(-2, 0, 0), "nand"),
   new_token(TkHash, loc(-2, 1, 0)),
   new_inumber(TkIntLit, loc(-2, 2, 0), Base10, -1, "2"),
   new_identifier(TkSymbol, loc(1, 7, 13), "g121"),
   new_token(TkLparen, loc(1, 7, 18)),
   new_identifier(TkSymbol, loc(1, 7, 19), "q21"),
   new_token(TkComma, loc(1, 7, 22)),
   new_identifier(TkSymbol, loc(1, 7, 24), "n10"),
   new_token(TkComma, loc(1, 7, 27)),
   new_identifier(TkSymbol, loc(1, 7, 29), "n11"),
   new_token(TkRparen, loc(1, 7, 32)),
   new_token(TkSemicolon, loc(1, 7, 33)),

   new_identifier(TkNand, loc(-3, 0, 0), "nand"),
   new_token(TkHash, loc(-3, 1, 0)),
   new_inumber(TkIntLit, loc(-3, 2, 0), Base10, -1, "5"),
   new_identifier(TkSymbol, loc(1, 8, 13), "g122"),
   new_token(TkLparen, loc(1, 8, 18)),
   new_identifier(TkSymbol, loc(1, 8, 19), "q22"),
   new_token(TkComma, loc(1, 8, 22)),
   new_identifier(TkSymbol, loc(1, 8, 24), "n10"),
   new_token(TkComma, loc(1, 8, 27)),
   new_identifier(TkSymbol, loc(1, 8, 29), "n11"),
   new_token(TkRparen, loc(1, 8, 32)),
   new_token(TkSemicolon, loc(1, 8, 33)),
], [
   MacroMap(
      name: "wordsize",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(1, 2, 7),
      locations: @[
         (loc(1, 1, 17), loc(1, 1, 17))
      ]
   ),
   MacroMap(
      name: "var_nand",
      comment: "define a nand with variable delay",
      define_loc: loc(1, 5, 8),
      expansion_loc: loc(1, 7, 0),
      locations: @[
         (loc(1, 5, 22), loc(1, 5, 22)),
         (loc(1, 5, 27), loc(1, 5, 27)),
         (loc(1, 7, 10), loc(1, 5, 28))
      ]
   ),
   MacroMap(
      name: "var_nand",
      comment: "define a nand with variable delay",
      define_loc: loc(1, 5, 8),
      expansion_loc: loc(1, 8, 0),
      locations: @[
         (loc(1, 5, 22), loc(1, 5, 22)),
         (loc(1, 5, 27), loc(1, 5, 27)),
         (loc(1, 8, 10), loc(1, 5, 28))
      ]
   ),
])


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
   new_identifier(TkWire, loc(2, 1, 0), "wire"),
   new_token(TkLbracket, loc(2, 1, 5)),
   new_inumber(TkIntLit, loc(2, 1, 6), Base10, -1, "7"),
   new_identifier(TkColon, loc(2, 1, 7), ":"),
   new_inumber(TkIntLit, loc(2, 1, 8), Base10, -1, "0"),
   new_token(TkRbracket, loc(2, 1, 9)),
   new_identifier(TkSymbol, loc(2, 1, 11), "my_wire"),
   new_token(TkSemicolon, loc(2, 1, 18)),
   new_identifier(TkWire, loc(1, 2, 0), "wire"),
   new_token(TkLbracket, loc(1, 2, 5)),
   new_inumber(TkIntLit, loc(1, 2, 6), Base10, -1, "3"),
   new_identifier(TkColon, loc(1, 2, 7), ":"),
   new_inumber(TkIntLit, loc(1, 2, 8), Base10, -1, "0"),
   new_token(TkRbracket, loc(1, 2, 9)),
   new_identifier(TkSymbol, loc(1, 2, 11), "another_wire"),
   new_token(TkSemicolon, loc(1, 2, 23)),
]


run_test("Include file, depending on an include path", """
`include "test1.vh"
wire [3:0] another_wire;
"""): [
   new_identifier(TkReg, loc(2, 1, 0), "reg"),
   new_identifier(TkSymbol, loc(2, 1, 4), "a_register"),
   new_token(TkSemicolon, loc(2, 1, 14)),
   new_identifier(TkWire, loc(1, 2, 0), "wire"),
   new_token(TkLbracket, loc(1, 2, 5)),
   new_inumber(TkIntLit, loc(1, 2, 6), Base10, -1, "3"),
   new_identifier(TkColon, loc(1, 2, 7), ":"),
   new_inumber(TkIntLit, loc(1, 2, 8), Base10, -1, "0"),
   new_token(TkRbracket, loc(1, 2, 9)),
   new_identifier(TkSymbol, loc(1, 2, 11), "another_wire"),
   new_token(TkSemicolon, loc(1, 2, 23)),
]


run_test("Nested include files", """
wire wire0;
`include "include/test2.vh"
wire last_wire;
"""): [
   new_identifier(TkWire, loc(1, 1, 0), "wire"),
   new_identifier(TkSymbol, loc(1, 1, 5), "wire0"),
   new_token(TkSemicolon, loc(1, 1, 10)),
   new_identifier(TkWire, loc(2, 1, 0), "wire"),
   new_identifier(TkSymbol, loc(2, 1, 5), "wire2"),
   new_token(TkSemicolon, loc(2, 1, 10)),
   new_identifier(TkWire, loc(3, 1, 0), "wire"),
   new_identifier(TkSymbol, loc(3, 1, 5), "wire3"),
   new_token(TkSemicolon, loc(3, 1, 10)),
   new_identifier(TkWire, loc(2, 3, 0), "wire"),
   new_identifier(TkSymbol, loc(2, 3, 5), "next_to_last_wire"),
   new_token(TkSemicolon, loc(2, 3, 22)),
   new_identifier(TkWire, loc(1, 3, 0), "wire"),
   new_identifier(TkSymbol, loc(1, 3, 5), "last_wire"),
   new_token(TkSemicolon, loc(1, 3, 14)),
]


run_test("Macro defined in an include file", """
`include "test4.vh"
wire [`WIDTH-1:0] my_wire;
""", [
   new_identifier(TkWire, loc(1, 2, 0), "wire"),
   new_token(TkLbracket, loc(1, 2, 5)),
   new_inumber(TkIntLit, loc(-1, 0, 0), Base10, -1, "8"),
   new_identifier(TkOperator, loc(1, 2, 12), "-"),
   new_inumber(TkIntLit, loc(1, 2, 13), Base10, -1, "1"),
   new_identifier(TkColon, loc(1, 2, 14), ":"),
   new_inumber(TkIntLit, loc(1, 2, 15), Base10, -1, "0"),
   new_token(TkRbracket, loc(1, 2, 16)),
   new_identifier(TkSymbol, loc(1, 2, 18), "my_wire"),
   new_token(TkSemicolon, loc(1, 2, 25)),
], [
   MacroMap(
      name: "WIDTH",
      define_loc: loc(2, 1, 8),
      expansion_loc: loc(1, 2, 6),
      locations: @[
         (loc(2, 1, 14), loc(2, 1, 14)),
      ]
   ),
])


run_test("Macro used in an include file", """
`define FOO reg [3:0]
`include "test5.vh"
""", [
   new_identifier(TkReg, loc(-1, 0, 0), "reg"),
   new_token(TkLbracket, loc(-1, 1, 0)),
   new_inumber(TkIntLit, loc(-1, 2, 0), Base10, -1, "3"),
   new_identifier(TkColon, loc(-1, 3, 0), ":"),
   new_inumber(TkIntLit, loc(-1, 4, 0), Base10, -1, "0"),
   new_token(TkRbracket, loc(-1, 5, 0)),
   new_identifier(TkSymbol, loc(2, 1, 5), "my_reg"),
   new_token(TkSemicolon, loc(2, 1, 11)),
], [
   MacroMap(
      name: "FOO",
      define_loc: loc(1, 1, 8),
      expansion_loc: loc(2, 1, 0),
      locations: @[
         (loc(1, 1, 12), loc(1, 1, 12)),
         (loc(1, 1, 16), loc(1, 1, 16)),
         (loc(1, 1, 17), loc(1, 1, 17)),
         (loc(1, 1, 18), loc(1, 1, 18)),
         (loc(1, 1, 19), loc(1, 1, 19)),
         (loc(1, 1, 20), loc(1, 1, 20)),
      ]
   ),
])


run_test("File cannot be found for `include -> error", """
`include "test_invalid.vh"
wire
"""): [
   new_error_token(1, 9, "Cannot open file 'test_invalid.vh'."),
   new_identifier(TkWire, loc(1, 2, 0), "wire"),
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
   new_identifier(TkReg, loc(1, 4, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 4, 4), "a"),
   new_token(TkSemicolon, loc(1, 4, 5)),
]


run_test("`ifdef: w/o `else, included", """
`define FOO
`ifdef FOO
   wire my_foo_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, loc(1, 3, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 3, 8), "my_foo_wire"),
   new_token(TkSemicolon, loc(1, 3, 19)),
   new_identifier(TkReg, loc(1, 5, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 5, 4), "a"),
   new_token(TkSemicolon, loc(1, 5, 5)),
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
   new_identifier(TkWire, loc(1, 3, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 3, 8), "my_foo_wire"),
   new_token(TkSemicolon, loc(1, 3, 19)),
   new_identifier(TkReg, loc(1, 7, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 7, 4), "a"),
   new_token(TkSemicolon, loc(1, 7, 5)),
]


run_test("`ifdef: w/ `else, else-branch", """
`ifdef FOO
   wire my_foo_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, loc(1, 4, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 4, 8), "my_else_wire"),
   new_token(TkSemicolon, loc(1, 4, 20)),
   new_identifier(TkReg, loc(1, 6, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 6, 4), "a"),
   new_token(TkSemicolon, loc(1, 6, 5)),
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
   new_identifier(TkWire, loc(1, 3, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 3, 8), "my_foo_wire"),
   new_token(TkSemicolon, loc(1, 3, 19)),
   new_identifier(TkReg, loc(1, 9, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 9, 4), "a"),
   new_token(TkSemicolon, loc(1, 9, 5)),
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
   new_identifier(TkWire, loc(1, 5, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 5, 8), "my_bar_wire"),
   new_token(TkSemicolon, loc(1, 5, 19)),
   new_identifier(TkReg, loc(1, 9, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 9, 4), "a"),
   new_token(TkSemicolon, loc(1, 9, 5)),
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
   new_identifier(TkWire, loc(1, 6, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 6, 8), "my_else_wire"),
   new_token(TkSemicolon, loc(1, 6, 20)),
   new_identifier(TkReg, loc(1, 8, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 8, 4), "a"),
   new_token(TkSemicolon, loc(1, 8, 5)),
]


run_test("`ifndef: w/o `else, ignored", """
`define FOO
`ifndef FOO
   wire my_foo_wire;
`endif
reg a;
"""): [
   new_identifier(TkReg, loc(1, 5, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 5, 4), "a"),
   new_token(TkSemicolon, loc(1, 5, 5)),
]


run_test("`ifndef: w/o `else, included", """
`ifndef FOO
   wire my_foo_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, loc(1, 2, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 2, 8), "my_foo_wire"),
   new_token(TkSemicolon, loc(1, 2, 19)),
   new_identifier(TkReg, loc(1, 4, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 4, 4), "a"),
   new_token(TkSemicolon, loc(1, 4, 5)),
]


run_test("`ifndef: w/ `else, if-branch", """
`ifndef FOO
   wire my_foo_wire;
`else
   wire my_else_wire;
`endif
reg a;
"""): [
   new_identifier(TkWire, loc(1, 2, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 2, 8), "my_foo_wire"),
   new_token(TkSemicolon, loc(1, 2, 19)),
   new_identifier(TkReg, loc(1, 6, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 6, 4), "a"),
   new_token(TkSemicolon, loc(1, 6, 5)),
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
   new_identifier(TkWire, loc(1, 5, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 5, 8), "my_else_wire"),
   new_token(TkSemicolon, loc(1, 5, 20)),
   new_identifier(TkReg, loc(1, 7, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 7, 4), "a"),
   new_token(TkSemicolon, loc(1, 7, 5)),
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
   new_identifier(TkWire, loc(1, 2, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 2, 8), "my_foo_wire"),
   new_token(TkSemicolon, loc(1, 2, 19)),
   new_identifier(TkReg, loc(1, 8, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 8, 4), "a"),
   new_token(TkSemicolon, loc(1, 8, 5)),
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
   new_identifier(TkWire, loc(1, 6, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 6, 8), "my_bar_wire"),
   new_token(TkSemicolon, loc(1, 6, 19)),
   new_identifier(TkReg, loc(1, 10, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 10, 4), "a"),
   new_token(TkSemicolon, loc(1, 10, 5)),
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
   new_identifier(TkWire, loc(1, 7, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 7, 8), "my_else_wire"),
   new_token(TkSemicolon, loc(1, 7, 20)),
   new_identifier(TkReg, loc(1, 9, 0), "reg"),
   new_identifier(TkSymbol, loc(1, 9, 4), "a"),
   new_token(TkSemicolon, loc(1, 9, 5)),
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
   new_identifier(TkWire, loc(1, 10, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 10, 8), "my_foo_else_wire"),
   new_token(TkSemicolon, loc(1, 10, 24)),
   new_identifier(TkWire, loc(1, 12, 6), "wire"),
   new_identifier(TkSymbol, loc(1, 12, 11), "my_not_bar_wire"),
   new_token(TkSemicolon, loc(1, 12, 26)),
   new_identifier(TkWire, loc(1, 16, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 16, 8), "another_foo_else_wire"),
   new_token(TkSemicolon, loc(1, 16, 29)),
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
   new_identifier(TkWire, loc(1, 3, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 3, 8), "my_foo_wire"),
   new_token(TkSemicolon, loc(1, 3, 19)),
   new_identifier(TkWire, loc(1, 7, 6), "wire"),
   new_identifier(TkSymbol, loc(1, 7, 11), "my_bar_else_wire"),
   new_token(TkSemicolon, loc(1, 7, 27)),
   new_identifier(TkWire, loc(1, 9, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 9, 8), "another_foo_wire"),
   new_token(TkSemicolon, loc(1, 9, 24)),
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
   new_identifier(TkWire, loc(1, 11, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 11, 8), "my_foo_else_wire"),
   new_token(TkSemicolon, loc(1, 11, 24)),
   new_identifier(TkWire, loc(1, 15, 6), "wire"),
   new_identifier(TkSymbol, loc(1, 15, 11), "my_bar_else_wire"),
   new_token(TkSemicolon, loc(1, 15, 27)),
   new_identifier(TkWire, loc(1, 17, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 17, 8), "another_foo_else_wire"),
   new_token(TkSemicolon, loc(1, 17, 29)),
]


run_test("Conditional include: if-branch", """
`define FOO
`ifdef FOO
   `include "test1.vh"
`else
   `include "test2.vh"
`endif
"""): [
   new_identifier(TkReg, loc(2, 1, 0), "reg"),
   new_identifier(TkSymbol, loc(2, 1, 4), "a_register"),
   new_token(TkSemicolon, loc(2, 1, 14)),
]


run_test("Conditional include: else-branch", """
`ifdef FOO
   `include "test1.vh"
`else
   `include "test2.vh"
`endif
"""): [
   new_identifier(TkWire, loc(2, 1, 0), "wire"),
   new_identifier(TkSymbol, loc(2, 1, 5), "wire2"),
   new_token(TkSemicolon, loc(2, 1, 10)),
   new_identifier(TkWire, loc(3, 1, 0), "wire"),
   new_identifier(TkSymbol, loc(3, 1, 5), "wire3"),
   new_token(TkSemicolon, loc(3, 1, 10)),
   new_identifier(TkWire, loc(2, 3, 0), "wire"),
   new_identifier(TkSymbol, loc(2, 3, 5), "next_to_last_wire"),
   new_token(TkSemicolon, loc(2, 3, 22)),
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
   new_identifier(TkWire, loc(1, 2, 0), "wire"),
   new_identifier(TkSymbol, loc(1, 2, 5), "some_wire"),
   new_token(TkSemicolon, loc(1, 2, 14)),
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
   new_identifier(TkWire, loc(1, 2, 0), "wire"),
   new_identifier(TkSymbol, loc(1, 2, 5), "some_wire"),
   new_token(TkSemicolon, loc(1, 2, 14)),
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
   new_identifier(TkWire, loc(1, 8, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 8, 8), "my_else_wire"),
   new_token(TkSemicolon, loc(1, 8, 20)),
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
   new_identifier(TkWire, loc(1, 3, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 3, 8), "my_foo_wire"),
   new_token(TkSemicolon, loc(1, 3, 19)),
   new_identifier(TkDirective, loc(1, 7, 0), "resetall"),
   new_identifier(TkWire, loc(1, 11, 3), "wire"),
   new_identifier(TkSymbol, loc(1, 11, 8), "my_else_wire"),
   new_token(TkSemicolon, loc(1, 11, 20)),
]


run_test("`line directive unsupported", """
`line 2 "test.v" 1
wire my_wire;
"""): [
   new_error_token(1, 0, "The `line directive is currently not supported."),
   new_identifier(TkWire, loc(1, 2, 0), "wire"),
   new_identifier(TkSymbol, loc(1, 2, 5), "my_wire"),
   new_token(TkSemicolon, loc(1, 2, 12)),
]


run_test("External define: ifdef", """
`ifdef EXTERNAL_FOO
wire foo;
`else
wire not_foo;
`endif
"""): [
   new_identifier(TkWire, loc(1, 2, 0), "wire"),
   new_identifier(TkSymbol, loc(1, 2, 5), "foo"),
   new_token(TkSemicolon, loc(1, 2, 8)),
]


run_test("External define: object-like macro", """
`EXTERNAL_BAR foo;
""", [
   new_identifier(TkWire, loc(-1, 0, 0), "wire"),
   new_identifier(TkSymbol, loc(1, 1, 14), "foo"),
   new_token(TkSemicolon, loc(1, 1, 17)),
], [
   MacroMap(
      name: "EXTERNAL_BAR",
      define_loc: loc(0, 1, 0),
      expansion_loc: loc(1, 1, 0),
      locations: @[
         (loc(0, 1, 13), loc(0, 1, 13)),
      ]
   )
])


run_test("Attached comment", """
/* This is a docstring for the `AND` macro. */
`define AND(x, y) (x & y)
wire always_zero = `AND(1'b1, 1'b0);
""", [
   new_identifier(TkWire, loc(1, 3, 0), "wire"),
   new_identifier(TkSymbol, loc(1, 3, 5), "always_zero"),
   new_token(TkEquals, loc(1, 3, 17)),
   new_token(TkLparen, loc(-1, 0, 0)),
   new_inumber(TkUIntLit, loc(-1, 1, 0), Base2, 1, "1"),
   new_identifier(TkOperator, loc(-1, 2, 0), "&"),
   new_inumber(TkUIntLit, loc(-1, 3, 0), Base2, 1, "0"),
   new_token(TkRparen, loc(-1, 4, 0)),
   new_token(TkSemicolon, loc(1, 3, 35)),
], [
   MacroMap(
      name: "AND",
      comment: "This is a docstring for the `AND` macro.",
      define_loc: loc(1, 2, 8),
      expansion_loc: loc(1, 3, 19),
      locations: @[
         (loc(1, 2, 18), loc(1, 2, 18)),
         (loc(1, 3, 24), loc(1, 2, 19)),
         (loc(1, 2, 21), loc(1, 2, 21)),
         (loc(1, 3, 30), loc(1, 2, 23)),
         (loc(1, 2, 24), loc(1, 2, 24)),
      ]
   )
])


# FIXME: Test with include file that uses a define from the outside syntax.
# FIXME: Validate file maps for all test cases. Also add a test like:
#
#  File 1            File 2           File 3
#  --------------    --------------   --------------
#
#  `include file3    `include file3   <syntax error>
#  `include file2
#  `include file3
#
#  Two entries should exist for file 3 in the index, representing the two
#  include directives.


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
