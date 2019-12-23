import terminal
import strformat
import strutils

import ../../vparse/parser/parser
import ../../vparse/parser/ast
import ../../vparse/lexer/identifier
import ../../vparse/lexer/lexer

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test(title, stimuli: string, reference: PNode) =
   # var response: PNode
   cache = new_ident_cache()
   let response = parse_specific_grammar(stimuli, cache, NkConstantExpression)

   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
      detailed_compare(response, reference)


proc li(line: uint16, col: int16): TLineInfo =
   result = new_line_info(line, col - 1)


# Wrapper for a constant primary expression
template cprim(n: PNode): PNode =
   n


template new_identifier_node(kind: NodeKind, info: TLineInfo, str: string): untyped =
   new_identifier_node(kind, info, get_identifier(cache, str))

# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: constant expression
-------------------------------""")

# Run tests
run_test("Constant primary: numbers, decimal signed", "1234567890"):
   cprim(new_inumber_node(NkIntLit, li(1, 1), 1234567890, "1234567890", Base10, -1))

run_test("Constant primary: numbers, decimal number w/ base", "32'd2617"):
   cprim(new_inumber_node(NkUIntLit, li(1, 1), 2617, "2617", Base10, 32))

run_test("Constant primary: numbers, decimal number w/ base", "18'D32"):
   cprim(new_inumber_node(NkUIntLit, li(1, 1), 32, "32", Base10, 18))

run_test("Constant primary: numbers, decimal number w/ base", "'d77"):
   cprim(new_inumber_node(NkUIntLit, li(1, 1), 77, "77", Base10, -1))

run_test("Constant primary: numbers, decimal number w/ base", "'sd90"):
   cprim(new_inumber_node(NkIntLit, li(1, 1), 90, "90", Base10, -1))

run_test("Constant primary: numbers, decimal number w/ base", "'Sd100"):
   cprim(new_inumber_node(NkIntLit, li(1, 1), 100, "100", Base10, -1))

run_test("Constant primary: numbers, decimal number w/ base", "5'D 3"):
   cprim(new_inumber_node(NkUIntLit, li(1, 1), 3, "3", Base10, 5))

run_test("Constant primary: numbers, underscore", "2617_123_"):
   cprim(new_inumber_node(NkIntLit, li(1, 1), 2617123, "2617123", Base10, -1))

run_test("Constant primary: numbers, decimal X-digit", "16'dX_"):
   cprim(new_inumber_node(NkAmbUIntLit, li(1, 1), 0, "x", Base10, 16))

run_test("Constant primary: numbers, decimal Z-digit", "16'DZ_"):
   cprim(new_inumber_node(NkAmbUIntLit, li(1, 1), 0, "z", Base10, 16))

run_test("Constant primary: numbers, decimal Z-digit", "2'd?"):
   cprim(new_inumber_node(NkAmbUIntLit, li(1, 1), 0, "?", Base10, 2))

run_test("Constant primary: numbers, decimal negative (unary)", "-13"):
   cprim(new_node(NkPrefix, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 1), "-"),
      cprim(new_inumber_node(NkIntLit, li(1, 2), 13, "13", Base10, -1))
   ]))

run_test("Constant primary: numbers, decimal positive (unary)", "+3"):
   cprim(new_node(NkPrefix, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 1), "+"),
      cprim(new_inumber_node(NkIntLit, li(1, 2), 3, "3", Base10, -1))
   ]))

run_test("Constant primary: numbers, invalid decimal", "'dAF"):
   cprim(new_node(NkTokenError, li(1, 1)))

run_test("Constant primary: numbers, simple real", "3.14159"):
   cprim(new_fnumber_node(NkRealLit, li(1, 1), 3.14159, "3.14159"))

run_test("Constant primary: numbers, real (positive exponent)", "1e2"):
   cprim(new_fnumber_node(NkRealLit, li(1, 1), 100, "1e2"))

run_test("Constant primary: numbers, real (negative exponent)", "1e-2"):
   cprim(new_fnumber_node(NkRealLit, li(1, 1), 0.01, "1e-2"))

run_test("Constant primary: numbers, binary", "8'B10000110"):
   cprim(new_inumber_node(NkUIntLit, li(1, 1), 134, "10000110", Base2, 8))

run_test("Constant primary: numbers, octal", "6'O6721"):
   cprim(new_inumber_node(NkUIntLit, li(1, 1), 3537, "6721", Base8, 6))

run_test("Constant primary: numbers, hex", "32'hFFFF_FFFF"):
   cprim(new_inumber_node(NkUIntLit, li(1, 1), (1 shl 32)-1, "FFFFFFFF", Base16, 32))

run_test("Constant primary: identifier", "FOO"):
   cprim(new_identifier_node(NkIdentifier, li(1, 1), "FOO"))

run_test("Constant primary: identifier w/ range", "bar[WIDTH-1:0]"):
   new_node(NkRangedIdentifier, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 1), "bar"),
      new_node(NkConstantRangeExpression, li(1, 4), @[
         new_node(NkInfix, li(1, 10), @[
            new_identifier_node(NkIdentifier, li(1, 10), "-"),
            cprim(new_identifier_node(NkIdentifier, li(1, 5), "WIDTH")),
            cprim(new_inumber_node(NkIntLit, li(1, 11), 1, "1", Base10, -1))
         ]),
         cprim(new_inumber_node(NkIntLit, li(1, 13), 0, "0", Base10, -1))
      ])
   ])

run_test("Constant primary: concatenation", "{64, 32, foobar}"):
   cprim(new_node(NkConstantConcat, li(1, 1), @[
      cprim(new_inumber_node(NkIntLit, li(1, 2), 64, "64", Base10, -1)),
      cprim(new_inumber_node(NkIntLit, li(1, 6), 32, "32", Base10, -1)),
      cprim(new_identifier_node(NkIdentifier, li(1, 10), "foobar"))
   ]))

run_test("Constant primary: multiple concatenation", "{32{2'b01}}"):
   cprim(new_node(NkConstantMultipleConcat, li(1, 1), @[
      cprim(new_inumber_node(NkIntLit, li(1, 2), 32, "32", Base10, -1)),
      new_node(NkConstantConcat, li(1, 4), @[
         cprim(new_inumber_node(NkUIntLit, li(1, 5), 1, "01", Base2, 2)),
      ])
   ]))

run_test("Constant primary: nested concatenation", "{{(WIDTH-1){1'b0}}, 1'b1}"):
   new_node(NkConstantConcat, li(1, 1), @[
      new_node(NkConstantMultipleConcat, li(1, 2), @[
         new_node(NkParenthesis, li(1, 3), @[
            new_node(NkInfix, li(1, 9), @[
               new_identifier_node(NkIdentifier, li(1, 9), "-"),
               new_identifier_node(NkIdentifier, li(1, 4), "WIDTH"),
               new_inumber_node(NkIntLit, li(1, 10), 1, "1", Base10, -1)
            ]),
         ]),
         new_node(NkConstantConcat, li(1, 12), @[
            new_inumber_node(NkUIntLit, li(1, 13), 0, "0", Base2, 1),
         ])
      ]),
      new_inumber_node(NkUIntLit, li(1, 21), 1, "1", Base2, 1),
   ])

run_test("Constant primary: function call", "myfun (* attr = val *) (2, 3, MYCONST)"):
   cprim(new_node(NkConstantFunctionCall, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 1), "myfun"),
      new_node(NkAttributeInst, li(1, 7), @[
         new_identifier_node(NkAttributeName, li(1, 10), "attr"),
         cprim(new_identifier_node(NkIdentifier, li(1, 17), "val"))
      ]),
      cprim(new_inumber_node(NkIntLit, li(1, 25), 2, "2", Base10, -1)),
      cprim(new_inumber_node(NkIntLit, li(1, 28), 3, "3", Base10, -1)),
      cprim(new_identifier_node(NkIdentifier, li(1, 31), "MYCONST"))
   ]))

run_test("Constant primary: system function call", "$clog2(2, 3, MYCONST)"):
   cprim(new_node(NkConstantSystemFunctionCall, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 1), "clog2"),
      cprim(new_inumber_node(NkIntLit, li(1, 8), 2, "2", Base10, -1)),
      cprim(new_inumber_node(NkIntLit, li(1, 11), 3, "3", Base10, -1)),
      cprim(new_identifier_node(NkIdentifier, li(1, 14), "MYCONST"))
   ]))

run_test("Constant primary: mintypmax", "(2'b00:8'd32:MYMAX)"):
   new_node(NkParenthesis, li(1, 1), @[
      cprim(new_node(NkConstantMinTypMaxExpression, li(1, 2), @[
         cprim(new_inumber_node(NkUIntLit, li(1, 2), 0, "00", Base2, 2)),
         cprim(new_inumber_node(NkUIntLit, li(1, 8), 32, "32", Base10, 8)),
         cprim(new_identifier_node(NkIdentifier, li(1, 14), "MYMAX"))
      ]))
   ])

run_test("Constant primary: string", """"This is a string""""):
   cprim(new_str_lit_node(li(1, 1), "This is a string"))

# Legal syntax but the expression doesn't make sense in a Verilog context.
run_test("Constant primary: two strings", """"This is a string" + "Another string""""):
   new_node(NkInfix, li(1, 20), @[
      cprim(new_identifier_node(NkIdentifier, li(1, 20), "+")),
      cprim(new_str_lit_node(li(1, 1), "This is a string")),
      cprim(new_str_lit_node(li(1, 22), "Another string"))
   ])

# Unary operators (prefix nodes)
for op in UnaryOperators:
   run_test(
      format("Unary operator: '$1'", op),
      format("$1MYPARAM", op)
   ):
      new_node(NkPrefix, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), op),
         new_identifier_node(NkIdentifier, li(1, 1+int16(len(op))), "MYPARAM")
      ])

run_test("Unary operator w/ attributes", """
- (* attr = val, another *) (* second_attr *) 4'd3
"""):
   new_node(NkPrefix, li(1, 1), @[
      new_identifier_node(NkIdentifier, li(1, 1), "-"),
      new_node(NkAttributeInst, li(1, 3), @[
         new_identifier_node(NkAttributeName, li(1, 6), "attr"),
         new_identifier_node(NkIdentifier, li(1, 13), "val"),
         new_identifier_node(NkAttributeName, li(1, 18), "another")
      ]),
      new_node(NkAttributeInst, li(1, 29), @[
         new_identifier_node(NkAttributeName, li(1, 32), "second_attr"),
      ]),
      new_inumber_node(NkUIntLit, li(1, 47), 3, "3", Base10, 4)
   ])

# Binary operators (infix nodex)
for op in BinaryOperators:
   run_test(
      format("Binary operator: '$1'", op),
      format("LHS $1 RHS", op)
   ):
      new_node(NkInfix, li(1, 5), @[
         new_identifier_node(NkIdentifier, li(1, 5), op),
         new_identifier_node(NkIdentifier, li(1, 1), "LHS"),
         new_identifier_node(NkIdentifier, li(1, 6+int16(len(op))), "RHS")
      ])

run_test("Binary operator w/ attributes", """
left_hand_side && (* attr = val, another *) (* second_attr *) right_hand_side
"""):
   new_node(NkInfix, li(1, 16), @[
      new_identifier_node(NkIdentifier, li(1, 16), "&&"),
      new_identifier_node(NkIdentifier, li(1, 1), "left_hand_side"),
      new_node(NkAttributeInst, li(1, 19), @[
         new_identifier_node(NkAttributeName, li(1, 22), "attr"),
         new_identifier_node(NkIdentifier, li(1, 29), "val"),
         new_identifier_node(NkAttributeName, li(1, 34), "another")
      ]),
      new_node(NkAttributeInst, li(1, 45), @[
         new_identifier_node(NkAttributeName, li(1, 48), "second_attr"),
      ]),
      new_identifier_node(NkIdentifier, li(1, 63), "right_hand_side"),
   ])

run_test("Binary operator precedence: arithmetic", """
2 * 2**32 - 1 + 3 / 2**32 + 3 % 5
"""):
   new_node(NkInfix, li(1, 27), @[
      new_identifier_node(NkIdentifier, li(1, 27), "+"),
      new_node(NkInfix, li(1, 15), @[
         new_identifier_node(NkIdentifier, li(1, 15), "+"),
         new_node(NkInfix, li(1, 11), @[
            new_identifier_node(NkIdentifier, li(1, 11), "-"),
            new_node(NkInfix, li(1, 3), @[
               new_identifier_node(NkIdentifier, li(1, 3), "*"),
               new_inumber_node(NkIntLit, li(1, 1), 2, "2", Base10, -1),
               new_node(NkInfix, li(1, 6), @[
                  new_identifier_node(NkIdentifier, li(1, 6), "**"),
                  new_inumber_node(NkIntLit, li(1, 5), 2, "2", Base10, -1),
                  new_inumber_node(NkIntLit, li(1, 8), 32, "32", Base10, -1)
               ])
            ]),
            new_inumber_node(NkIntLit, li(1, 13), 1, "1", Base10, -1)
         ]),
         new_node(NkInfix, li(1, 19), @[
            new_identifier_node(NkIdentifier, li(1, 19), "/"),
            new_inumber_node(NkIntLit, li(1, 17), 3, "3", Base10, -1),
            new_node(NkInfix, li(1, 22), @[
               new_identifier_node(NkIdentifier, li(1, 22), "**"),
               new_inumber_node(NkIntLit, li(1, 21), 2, "2", Base10, -1),
               new_inumber_node(NkIntLit, li(1, 24), 32, "32", Base10, -1)
            ])
         ])
      ]),
      new_node(NkInfix, li(1, 31), @[
         new_identifier_node(NkIdentifier, li(1, 31), "%"),
         new_inumber_node(NkIntLit, li(1, 29), 3, "3", Base10, -1),
         new_inumber_node(NkIntLit, li(1, 33), 5, "5", Base10, -1)
      ])
   ])

run_test("Binary operator precedence: shifts", """
2 + 1 << 32 - 2'b10 >> 1 >>> 1 + (3'b010 <<< 1)
"""):
   new_node(NkInfix, li(1, 26), @[
      new_identifier_node(NkIdentifier, li(1, 26), ">>>"),
      new_node(NkInfix, li(1, 21), @[
         new_identifier_node(NkIdentifier, li(1, 21), ">>"),
         new_node(NkInfix, li(1, 7), @[
            new_identifier_node(NkIdentifier, li(1, 7), "<<"),
            new_node(NkInfix, li(1, 3), @[
               new_identifier_node(NkIdentifier, li(1, 3), "+"),
               new_inumber_node(NkIntLit, li(1, 1), 2, "2", Base10, -1),
               new_inumber_node(NkIntLit, li(1, 5), 1, "1", Base10, -1)
            ]),
            new_node(NkInfix, li(1, 13), @[
               new_identifier_node(NkIdentifier, li(1, 13), "-"),
               new_inumber_node(NkIntLit, li(1, 10), 32, "32", Base10, -1),
               new_inumber_node(NkUIntLit, li(1, 15), 2, "10", Base2, 2)
            ])
         ]),
         new_inumber_node(NkIntLit, li(1, 24), 1, "1", Base10, -1)
      ]),
      new_node(NkInfix, li(1, 32), @[
         new_identifier_node(NkIdentifier, li(1, 32), "+"),
         new_inumber_node(NkIntLit, li(1, 30), 1, "1", Base10, -1),
         new_node(NkParenthesis, li(1, 34), @[
            new_node(NkInfix, li(1, 42), @[
               new_identifier_node(NkIdentifier, li(1, 42), "<<<"),
               new_inumber_node(NkUIntLit, li(1, 35), 2, "010", Base2, 3),
               new_inumber_node(NkIntLit, li(1, 46), 1, "1", Base10, -1)
            ])
         ])
      ])
   ])

run_test("Binary operator precedence: comparisons (1)", """
2 < 3 <= 4 >= 3 > 2
"""):
   new_node(NkInfix, li(1, 17), @[
      new_identifier_node(NkIdentifier, li(1, 17), ">"),
      new_node(NkInfix, li(1, 12), @[
         new_identifier_node(NkIdentifier, li(1, 12), ">="),
         new_node(NkInfix, li(1, 7), @[
            new_identifier_node(NkIdentifier, li(1, 7), "<="),
            new_node(NkInfix, li(1, 3), @[
               new_identifier_node(NkIdentifier, li(1, 3), "<"),
               new_inumber_node(NkIntLit, li(1, 1), 2, "2", Base10, -1),
               new_inumber_node(NkIntLit, li(1, 5), 3, "3", Base10, -1)
            ]),
            new_inumber_node(NkIntLit, li(1, 10), 4, "4", Base10, -1)
         ]),
         new_inumber_node(NkIntLit, li(1, 15), 3, "3", Base10, -1)
      ]),
      new_inumber_node(NkIntLit, li(1, 19), 2, "2", Base10, -1)
   ])

run_test("Binary operator precedence: comparisons (2)", """
2 == 3 != 4 === 3 !== 2
"""):
   new_node(NkInfix, li(1, 19), @[
      new_identifier_node(NkIdentifier, li(1, 19), "!=="),
      new_node(NkInfix, li(1, 13), @[
         new_identifier_node(NkIdentifier, li(1, 13), "==="),
         new_node(NkInfix, li(1, 8), @[
            new_identifier_node(NkIdentifier, li(1, 8), "!="),
            new_node(NkInfix, li(1, 3), @[
               new_identifier_node(NkIdentifier, li(1, 3), "=="),
               new_inumber_node(NkIntLit, li(1, 1), 2, "2", Base10, -1),
               new_inumber_node(NkIntLit, li(1, 6), 3, "3", Base10, -1)
            ]),
            new_inumber_node(NkIntLit, li(1, 11), 4, "4", Base10, -1)
         ]),
         new_inumber_node(NkIntLit, li(1, 17), 3, "3", Base10, -1)
      ]),
      new_inumber_node(NkIntLit, li(1, 23), 2, "2", Base10, -1)
   ])

run_test("Binary operator precedence: comparisons (3)", """
2 == 3 >= 3 != 4
"""):
   new_node(NkInfix, li(1, 13), @[
      new_identifier_node(NkIdentifier, li(1, 13), "!="),
      new_node(NkInfix, li(1, 3), @[
         new_identifier_node(NkIdentifier, li(1, 3), "=="),
         new_inumber_node(NkIntLit, li(1, 1), 2, "2", Base10, -1),
         new_node(NkInfix, li(1, 8), @[
            new_identifier_node(NkIdentifier, li(1, 8), ">="),
            new_inumber_node(NkIntLit, li(1, 6), 3, "3", Base10, -1),
            new_inumber_node(NkIntLit, li(1, 11), 3, "3", Base10, -1)
         ])
      ]),
      new_inumber_node(NkIntLit, li(1, 16), 4, "4", Base10, -1)
   ])

run_test("Binary operator precedence: logical operations", """
A & B ^ C | D ~^ E && F || G ^~ H
"""):
   new_node(NkInfix, li(1, 25), @[
      new_identifier_node(NkIdentifier, li(1, 25), "||"),
      new_node(NkInfix, li(1, 20), @[
         new_identifier_node(NkIdentifier, li(1, 20), "&&"),
         new_node(NkInfix, li(1, 11), @[
            new_identifier_node(NkIdentifier, li(1, 11), "|"),
            new_node(NkInfix, li(1, 7), @[
               new_identifier_node(NkIdentifier, li(1, 7), "^"),
               new_node(NkInfix, li(1, 3), @[
                  new_identifier_node(NkIdentifier, li(1, 3), "&"),
                  new_identifier_node(NkIdentifier, li(1, 1), "A"),
                  new_identifier_node(NkIdentifier, li(1, 5), "B"),
               ]),
               new_identifier_node(NkIdentifier, li(1, 9), "C"),
            ]),
            new_node(NkInfix, li(1, 15), @[
               new_identifier_node(NkIdentifier, li(1, 15), "~^"),
               new_identifier_node(NkIdentifier, li(1, 13), "D"),
               new_identifier_node(NkIdentifier, li(1, 18), "E"),
            ]),
         ]),
         new_identifier_node(NkIdentifier, li(1, 23), "F"),
      ]),
      new_node(NkInfix, li(1, 30), @[
         new_identifier_node(NkIdentifier, li(1, 30), "^~"),
         new_identifier_node(NkIdentifier, li(1, 28), "G"),
         new_identifier_node(NkIdentifier, li(1, 33), "H"),
      ]),
   ])

run_test("Binary operator precedence: complex expression", """
A || B && C | D ^ E & F == G < H >> I + J / K ** L /
A + B >> C < D == E & F ^ G | H && I || J
"""):
   new_node(NkInfix, li(2, 38), @[
      new_identifier_node(NkIdentifier, li(2, 38), "||"),
      new_node(NkInfix, li(1, 3), @[
         new_identifier_node(NkIdentifier, li(1, 3), "||"),
         new_identifier_node(NkIdentifier, li(1, 1), "A"),
         new_node(NkInfix, li(2, 33), @[
            new_identifier_node(NkIdentifier, li(2, 33), "&&"),
            new_node(NkInfix, li(1, 8), @[
               new_identifier_node(NkIdentifier, li(1, 8), "&&"),
               new_identifier_node(NkIdentifier, li(1, 6), "B"),
               new_node(NkInfix, li(2, 29), @[
                  new_identifier_node(NkIdentifier, li(2, 29), "|"),
                  new_node(NkInfix, li(1, 13), @[
                     new_identifier_node(NkIdentifier, li(1, 13), "|"),
                     new_identifier_node(NkIdentifier, li(1, 11), "C"),
                     new_node(NkInfix, li(2, 25), @[
                        new_identifier_node(NkIdentifier, li(2, 25), "^"),
                        new_node(NkInfix, li(1, 17), @[
                           new_identifier_node(NkIdentifier, li(1, 17), "^"),
                           new_identifier_node(NkIdentifier, li(1, 15), "D"),
                           new_node(NkInfix, li(2, 21), @[
                              new_identifier_node(NkIdentifier, li(2, 21), "&"),
                              new_node(NkInfix, li(1, 21), @[
                                 new_identifier_node(NkIdentifier, li(1, 21), "&"),
                                 new_identifier_node(NkIdentifier, li(1, 19), "E"),
                                 new_node(NkInfix, li(2, 16), @[
                                    new_identifier_node(NkIdentifier, li(2, 16), "=="),
                                    new_node(NkInfix, li(1, 25), @[
                                       new_identifier_node(NkIdentifier, li(1, 25), "=="),
                                       new_identifier_node(NkIdentifier, li(1, 23), "F"),
                                       new_node(NkInfix, li(2, 12), @[
                                          new_identifier_node(NkIdentifier, li(2, 12), "<"),
                                          new_node(NkInfix, li(1, 30), @[
                                             new_identifier_node(NkIdentifier, li(1, 30), "<"),
                                             new_identifier_node(NkIdentifier, li(1, 28), "G"),
                                             new_node(NkInfix, li(2, 7), @[
                                                new_identifier_node(NkIdentifier, li(2, 7), ">>"),
                                                new_node(NkInfix, li(1, 34), @[
                                                   new_identifier_node(NkIdentifier, li(1, 34), ">>"),
                                                   new_identifier_node(NkIdentifier, li(1, 32), "H"),
                                                   new_node(NkInfix, li(2, 3), @[
                                                      new_identifier_node(NkIdentifier, li(2, 3), "+"),
                                                      new_node(NkInfix, li(1, 39), @[
                                                         new_identifier_node(NkIdentifier, li(1, 39), "+"),
                                                         new_identifier_node(NkIdentifier, li(1, 37), "I"),
                                                         new_node(NkInfix, li(1, 52), @[
                                                            new_identifier_node(NkIdentifier, li(1, 52), "/"),
                                                            new_node(NkInfix, li(1, 43), @[
                                                               new_identifier_node(NkIdentifier, li(1, 43), "/"),
                                                               new_identifier_node(NkIdentifier, li(1, 41), "J"),
                                                               new_node(NkInfix, li(1, 47), @[
                                                                  new_identifier_node(NkIdentifier, li(1, 47), "**"),
                                                                  new_identifier_node(NkIdentifier, li(1, 45), "K"),
                                                                  new_identifier_node(NkIdentifier, li(1, 50), "L"),
                                                               ]),
                                                            ]),
                                                            new_identifier_node(NkIdentifier, li(2, 1), "A"),
                                                         ]),
                                                      ]),
                                                      new_identifier_node(NkIdentifier, li(2, 5), "B"),
                                                   ]),
                                                ]),
                                                new_identifier_node(NkIdentifier, li(2, 10), "C"),
                                             ]),
                                          ]),
                                          new_identifier_node(NkIdentifier, li(2, 14), "D"),
                                       ]),
                                    ]),
                                    new_identifier_node(NkIdentifier, li(2, 19), "E"),
                                 ]),
                              ]),
                              new_identifier_node(NkIdentifier, li(2, 23), "F"),
                           ]),
                        ]),
                        new_identifier_node(NkIdentifier, li(2, 27), "G"),
                     ]),
                  ]),
                  new_identifier_node(NkIdentifier, li(2, 31), "H"),
               ]),
            ]),
            new_identifier_node(NkIdentifier, li(2, 36), "I"),
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(2, 41), "J"),
   ])

run_test("Conditional expression", """
A == B ? C + D : E || F
"""):
   new_node(NkConstantConditionalExpression, li(1, 8), @[
      new_node(NkInfix, li(1, 3), @[
         new_identifier_node(NkIdentifier, li(1, 3), "=="),
         new_identifier_node(NkIdentifier, li(1, 1), "A"),
         new_identifier_node(NkIdentifier, li(1, 6), "B"),
      ]),
      new_node(NkInfix, li(1, 12), @[
         new_identifier_node(NkIdentifier, li(1, 12), "+"),
         new_identifier_node(NkIdentifier, li(1, 10), "C"),
         new_identifier_node(NkIdentifier, li(1, 14), "D"),
      ]),
      new_node(NkInfix, li(1, 20), @[
         new_identifier_node(NkIdentifier, li(1, 20), "||"),
         new_identifier_node(NkIdentifier, li(1, 18), "E"),
         new_identifier_node(NkIdentifier, li(1, 23), "F"),
      ]),
   ])

run_test("Conditional expression w/ attributes", """
A ? (* attr = val, another *) (* second_attr *) B : C
"""):
   new_node(NkConstantConditionalExpression, li(1, 3), @[
      new_identifier_node(NkIdentifier, li(1, 1), "A"),
      new_node(NkAttributeInst, li(1, 5), @[
         new_identifier_node(NkAttributeName, li(1, 8), "attr"),
         new_identifier_node(NkIdentifier, li(1, 15), "val"),
         new_identifier_node(NkAttributeName, li(1, 20), "another")
      ]),
      new_node(NkAttributeInst, li(1, 31), @[
         new_identifier_node(NkAttributeName, li(1, 34), "second_attr"),
      ]),
      new_identifier_node(NkIdentifier, li(1, 49), "B"),
      new_identifier_node(NkIdentifier, li(1, 53), "C"),
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
