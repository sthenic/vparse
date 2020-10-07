import terminal
import strformat

import ../../src/vparsepkg/parser
import ../../src/vparsepkg/ast
import ../../src/vparsepkg/identifier
import ../../src/vparsepkg/lexer

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test(title, stimuli: string, reference: PNode) =
   # var response: PNode
   cache = new_ident_cache()
   let response = parse_specific_grammar(stimuli, cache, NkListOfPorts)

   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
      detailed_compare(response, reference)


proc li(line: uint16, col: int16): Location =
   result = Location(file: 1, line: line, col: col - 1)


template new_identifier_node(kind: NodeKind, loc: Location, str: string): untyped =
   new_identifier_node(kind, loc, get_identifier(cache, str))


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: port list
---------------------""")

# Run tests
run_test("Port w/o connection", """(
   .clk_i()
)"""):
   new_node(NkListOfPorts, li(1, 1), @[
      new_node(NkPort, li(2, 4), @[
         new_identifier_node(NkPortIdentifier, li(2, 5), "clk_i"),
      ])
   ])


run_test("Port w/ connection", """(
   .clk_i(s_axis_aclk)
)"""):
   new_node(NkListOfPorts, li(1, 1), @[
      new_node(NkPort, li(2, 4), @[
         new_identifier_node(NkPortIdentifier, li(2, 5), "clk_i"),
         new_node(NkPortReference, li(2, 11), @[
            new_identifier_node(NkPortIdentifier, li(2, 11), "s_axis_aclk"),
         ])
      ])
   ])


run_test("Multiple ports", """(
   .clk_i(s_axis_aclk),
   .rst_ni(s_axis_aresetn),
   .data_o(m_axis_adata)
)"""):
   new_node(NkListOfPorts, li(1, 1), @[
      new_node(NkPort, li(2, 4), @[
         new_identifier_node(NkPortIdentifier, li(2, 5), "clk_i"),
         new_node(NkPortReference, li(2, 11), @[
            new_identifier_node(NkPortIdentifier, li(2, 11), "s_axis_aclk"),
         ])
      ]),
      new_node(NkPort, li(3, 4), @[
         new_identifier_node(NkPortIdentifier, li(3, 5), "rst_ni"),
         new_node(NkPortReference, li(3, 12), @[
            new_identifier_node(NkPortIdentifier, li(3, 12), "s_axis_aresetn"),
         ])
      ]),
      new_node(NkPort, li(4, 4), @[
         new_identifier_node(NkPortIdentifier, li(4, 5), "data_o"),
         new_node(NkPortReference, li(4, 12), @[
            new_identifier_node(NkPortIdentifier, li(4, 12), "m_axis_adata"),
         ])
      ])
   ])


run_test("Multiple ports, one empty", """(
   .clk_i(s_axis_aclk),
   ,
   .data_o(m_axis_adata)
)"""):
   new_node(NkListOfPorts, li(1, 1), @[
      new_node(NkPort, li(2, 4), @[
         new_identifier_node(NkPortIdentifier, li(2, 5), "clk_i"),
         new_node(NkPortReference, li(2, 11), @[
            new_identifier_node(NkPortIdentifier, li(2, 11), "s_axis_aclk"),
         ])
      ]),
      new_node(NkPort, li(3, 4)),
      new_node(NkPort, li(4, 4), @[
         new_identifier_node(NkPortIdentifier, li(4, 5), "data_o"),
         new_node(NkPortReference, li(4, 12), @[
            new_identifier_node(NkPortIdentifier, li(4, 12), "m_axis_adata"),
         ])
      ])
   ])


run_test("Port reference w/ range expressions", """(
   .a_i(a[64]),
   .b_i(b[7:0]),
   .c_i(c[WIDTH * i +: WIDTH]),
   .d_i(d[ADDR-1 -: WIDTH])
)"""):
   new_node(NkListOfPorts, li(1, 1), @[
      new_node(NkPort, li(2, 4), @[
         new_identifier_node(NkPortIdentifier, li(2, 5), "a_i"),
         new_node(NkPortReference, li(2, 9), @[
            new_identifier_node(NkPortIdentifier, li(2, 9), "a"),
            new_node(NkConstantRangeExpression, li(2, 10), @[
               new_inumber_node(NkIntLit, li(2, 11), "64", Base10, -1)
            ])
         ])
      ]),
      new_node(NkPort, li(3, 4), @[
         new_identifier_node(NkPortIdentifier, li(3, 5), "b_i"),
         new_node(NkPortReference, li(3, 9), @[
            new_identifier_node(NkPortIdentifier, li(3, 9), "b"),
            new_node(NkConstantRangeExpression, li(3, 10), @[
               new_node(NkInfix, li(3, 12), @[
                  new_identifier_node(NkIdentifier, li(3, 12), ":"),
                  new_inumber_node(NkIntLit, li(3, 11), "7", Base10, -1),
                  new_inumber_node(NkIntLit, li(3, 13), "0", Base10, -1)
               ])
            ])
         ])
      ]),
      new_node(NkPort, li(4, 4), @[
         new_identifier_node(NkPortIdentifier, li(4, 5), "c_i"),
         new_node(NkPortReference, li(4, 9), @[
            new_identifier_node(NkPortIdentifier, li(4, 9), "c"),
            new_node(NkConstantRangeExpression, li(4, 10), @[
               new_node(NkInfix, li(4, 21), @[
                  new_identifier_node(NkIdentifier, li(4, 21), "+:"),
                  new_node(NkInfix, li(4, 17), @[
                     new_identifier_node(NkIdentifier, li(4, 17), "*"),
                     new_identifier_node(NkIdentifier, li(4, 11), "WIDTH"),
                     new_identifier_node(NkIdentifier, li(4, 19), "i"),
                  ]),
                  new_identifier_node(NkIdentifier, li(4, 24), "WIDTH"),
               ])
            ])
         ])
      ]),
      new_node(NkPort, li(5, 4), @[
         new_identifier_node(NkPortIdentifier, li(5, 5), "d_i"),
         new_node(NkPortReference, li(5, 9), @[
            new_identifier_node(NkPortIdentifier, li(5, 9), "d"),
            new_node(NkConstantRangeExpression, li(5, 10), @[
               new_node(NkInfix, li(5, 18), @[
                  new_identifier_node(NkIdentifier, li(5, 18), "-:"),
                  new_node(NkInfix, li(5, 15), @[
                     new_identifier_node(NkIdentifier, li(5, 15), "-"),
                     new_identifier_node(NkIdentifier, li(5, 11), "ADDR"),
                     new_inumber_node(NkIntLit, li(5, 16), "1", Base10, -1)
                  ]),
                  new_identifier_node(NkIdentifier, li(5, 21), "WIDTH"),
               ])
            ])
         ])
      ])
   ])


run_test("Port reference, concatenation", """(
   .port({a, b[5], last})
)"""):
   new_node(NkListOfPorts, li(1, 1), @[
      new_node(NkPort, li(2, 4), @[
         new_identifier_node(NkPortIdentifier, li(2, 5), "port"),
         new_node(NkPortReferenceConcat, li(2, 10), @[
            new_node(NkPortReference, li(2, 11), @[
               new_identifier_node(NkPortIdentifier, li(2, 11), "a"),
            ]),
            new_node(NkPortReference, li(2, 14), @[
               new_identifier_node(NkPortIdentifier, li(2, 14), "b"),
               new_node(NkConstantRangeExpression, li(2, 15), @[
                  new_inumber_node(NkIntLit, li(2, 16), "5", Base10, -1)
               ])
            ]),
            new_node(NkPortReference, li(2, 20), @[
               new_identifier_node(NkPortIdentifier, li(2, 20), "last"),
            ])
         ])
      ])
   ])


run_test("Multiple ports, anonymous", """(
   s_axis_aclk,
   s_axis_aresetn,
   m_axis_adata
)"""):
   new_node(NkListOfPorts, li(1, 1), @[
      new_node(NkPort, li(2, 4), @[
         new_node(NkPortReference, li(2, 4), @[
            new_identifier_node(NkPortIdentifier, li(2, 4), "s_axis_aclk"),
         ])
      ]),
      new_node(NkPort, li(3, 4), @[
         new_node(NkPortReference, li(3, 4), @[
            new_identifier_node(NkPortIdentifier, li(3, 4), "s_axis_aresetn"),
         ])
      ]),
      new_node(NkPort, li(4, 4), @[
         new_node(NkPortReference, li(4, 4), @[
            new_identifier_node(NkPortIdentifier, li(4, 4), "m_axis_adata"),
         ])
      ])
   ])


run_test("Anonymous port w/ range", """(
   addr[WIDTH-1:0]
)"""):
   new_node(NkListOfPorts, li(1, 1), @[
      new_node(NkPort, li(2, 4), @[
         new_node(NkPortReference, li(2, 4), @[
            new_identifier_node(NkPortIdentifier, li(2, 4), "addr"),
            new_node(NkConstantRangeExpression, li(2, 8), @[
               new_node(NkInfix, li(2, 16), @[
                  new_identifier_node(NkIdentifier, li(2, 16), ":"),
                  new_node(NkInfix, li(2, 14), @[
                     new_identifier_node(NkIdentifier, li(2, 14), "-"),
                     new_identifier_node(NkIdentifier, li(2, 9), "WIDTH"),
                     new_inumber_node(NkIntLit, li(2, 15), "1", Base10, -1)
                  ]),
                  new_inumber_node(NkIntLit, li(2, 17), "0", Base10, -1)
               ])
            ])
         ])
      ])
   ])


run_test("Anonymous port concatenation", """(
   {a, b, addr[WIDTH-1:0], last}
)"""):
   new_node(NkListOfPorts, li(1, 1), @[
      new_node(NkPort, li(2, 4), @[
         new_node(NkPortReferenceConcat, li(2, 4), @[
            new_node(NkPortReference, li(2, 5), @[
               new_identifier_node(NkPortIdentifier, li(2, 5), "a"),
            ]),
            new_node(NkPortReference, li(2, 8), @[
               new_identifier_node(NkPortIdentifier, li(2, 8), "b"),
            ]),
            new_node(NkPortReference, li(2, 11), @[
               new_identifier_node(NkPortIdentifier, li(2, 11), "addr"),
               new_node(NkConstantRangeExpression, li(2, 15), @[
                  new_node(NkInfix, li(2, 23), @[
                     new_identifier_node(NkIdentifier, li(2, 23), ":"),
                     new_node(NkInfix, li(2, 21), @[
                        new_identifier_node(NkIdentifier, li(2, 21), "-"),
                        new_identifier_node(NkIdentifier, li(2, 16), "WIDTH"),
                        new_inumber_node(NkIntLit, li(2, 22), "1", Base10, -1)
                     ]),
                     new_inumber_node(NkIntLit, li(2, 24), "0", Base10, -1)
                  ])
               ])
            ]),
            new_node(NkPortReference, li(2, 28), @[
               new_identifier_node(NkPortIdentifier, li(2, 28), "last"),
            ])
         ])
      ])
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
