import terminal
import strformat

import ../../src/vparsepkg/parser

var
   nof_passed = 0
   nof_failed = 0
   cache: IdentifierCache


template run_test_module_decl(title, operation: untyped, stimuli: string, reference: untyped) =
   cache = new_ident_cache()
   let n = parse_string(stimuli, cache)[0]
   let response = operation(n)

   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
      for i in 0..<len(response):
         detailed_compare(response[i][0], reference[i][0])
         detailed_compare(response[i][1], reference[i][1])


template run_test_drivers(title, stimuli: string, reference: untyped) =
   cache = new_ident_cache()
   let n = parse_string(stimuli, cache)
   let response = find_all_drivers(n, recursive = true)

   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
      for i in 0..<len(response):
         detailed_compare(response[i][0], reference[i][0])
         detailed_compare(response[i][1], reference[i][1])


proc li(line: uint16, col: int16): Location =
   result = Location(file: 1, line: line, col: col - 1)


template new_identifier_node(kind: NodeKind, loc: Location, str: string): untyped =
   new_identifier_node(kind, loc, get_identifier(cache, str))


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: AST operations
--------------------------""")


run_test_module_decl("Find all ports, list of port declarations", find_all_ports, """
module port_finder (
   input wire clk_i,
              another_port_i,
              the_last_port_i,
   output reg [7:0] data_o
);
endmodule
""", @[
   (
      port: new_node(NkPortDecl, li(2, 4), @[
         new_identifier_node(NkDirection, li(2, 4), "input"),
         new_identifier_node(NkNetType, li(2, 10), "wire"),
         new_identifier_node(NkPortIdentifier, li(2, 15), "clk_i"),
         new_identifier_node(NkPortIdentifier, li(3, 15), "another_port_i"),
         new_identifier_node(NkPortIdentifier, li(4, 15), "the_last_port_i")
      ]),
      identifier: new_identifier_node(NkPortIdentifier, li(2, 15), "clk_i")
   ),
   (
      port: new_node(NkPortDecl, li(2, 4), @[
         new_identifier_node(NkDirection, li(2, 4), "input"),
         new_identifier_node(NkNetType, li(2, 10), "wire"),
         new_identifier_node(NkPortIdentifier, li(2, 15), "clk_i"),
         new_identifier_node(NkPortIdentifier, li(3, 15), "another_port_i"),
         new_identifier_node(NkPortIdentifier, li(4, 15), "the_last_port_i")
      ]),
      identifier: new_identifier_node(NkPortIdentifier, li(3, 15), "another_port_i")
   ),
   (
      port: new_node(NkPortDecl, li(2, 4), @[
         new_identifier_node(NkDirection, li(2, 4), "input"),
         new_identifier_node(NkNetType, li(2, 10), "wire"),
         new_identifier_node(NkPortIdentifier, li(2, 15), "clk_i"),
         new_identifier_node(NkPortIdentifier, li(3, 15), "another_port_i"),
         new_identifier_node(NkPortIdentifier, li(4, 15), "the_last_port_i"),
      ]),
      identifier: new_identifier_node(NkPortIdentifier, li(4, 15), "the_last_port_i")
   ),
   (
      port: new_node(NkPortDecl, li(5, 4), @[
         new_identifier_node(NkDirection, li(5, 4), "output"),
         new_identifier_node(NkNetType, li(5, 11), "reg"),
         new_node(NkRange, li(5, 15), @[
            new_inumber_node(NkIntLit, li(5, 16), "7", Base10, -1),
            new_inumber_node(NkIntLit, li(5, 18), "0", Base10, -1)
         ]),
         new_identifier_node(NkPortIdentifier, li(5, 21), "data_o")
      ]),
      identifier: new_identifier_node(NkPortIdentifier, li(5, 21), "data_o")
   )
])


run_test_module_decl("Find all ports, port declarations in body", find_all_ports, """
module port_finder (
   clk_i, another_port_i, the_last_port_i, data_o
);
   input wire clk_i,
              another_port_i,
              the_last_port_i;
   output reg [7:0] data_o;
endmodule
""", @[
   (
      port: new_node(NkPortDecl, li(4, 4), @[
         new_identifier_node(NkDirection, li(4, 4), "input"),
         new_identifier_node(NkNetType, li(4, 10), "wire"),
         new_identifier_node(NkPortIdentifier, li(4, 15), "clk_i"),
         new_identifier_node(NkPortIdentifier, li(5, 15), "another_port_i"),
         new_identifier_node(NkPortIdentifier, li(6, 15), "the_last_port_i")
      ]),
      identifier: new_identifier_node(NkPortIdentifier, li(4, 15), "clk_i")
   ),
   (
      port: new_node(NkPortDecl, li(4, 4), @[
         new_identifier_node(NkDirection, li(4, 4), "input"),
         new_identifier_node(NkNetType, li(4, 10), "wire"),
         new_identifier_node(NkPortIdentifier, li(4, 15), "clk_i"),
         new_identifier_node(NkPortIdentifier, li(5, 15), "another_port_i"),
         new_identifier_node(NkPortIdentifier, li(6, 15), "the_last_port_i")
      ]),
      identifier: new_identifier_node(NkPortIdentifier, li(5, 15), "another_port_i")
   ),
   (
      port: new_node(NkPortDecl, li(4, 4), @[
         new_identifier_node(NkDirection, li(4, 4), "input"),
         new_identifier_node(NkNetType, li(4, 10), "wire"),
         new_identifier_node(NkPortIdentifier, li(4, 15), "clk_i"),
         new_identifier_node(NkPortIdentifier, li(5, 15), "another_port_i"),
         new_identifier_node(NkPortIdentifier, li(6, 15), "the_last_port_i")
      ]),
      identifier: new_identifier_node(NkPortIdentifier, li(6, 15), "the_last_port_i")
   ),
   (
      port: new_node(NkPortDecl, li(7, 4), @[
         new_identifier_node(NkDirection, li(7, 4), "output"),
         new_identifier_node(NkNetType, li(7, 11), "reg"),
         new_node(NkRange, li(7, 15), @[
            new_inumber_node(NkIntLit, li(7, 16), "7", Base10, -1),
            new_inumber_node(NkIntLit, li(7, 18), "0", Base10, -1)
         ]),
         new_identifier_node(NkPortIdentifier, li(7, 21), "data_o")
      ]),
      identifier: new_identifier_node(NkPortIdentifier, li(7, 21), "data_o")
   )
])


run_test_module_decl("Find all parameters (1)", find_all_parameters, """
module port_finder #(
   parameter WIDTH = 32,
   parameter ZERO = 0
)();
   parameter FOO = 3;
endmodule
""", @[
   (
      parameter: new_node(NkParameterDecl, li(2, 4), @[
         new_node(NkParamAssignment, li(2, 14), @[
            new_identifier_node(NkParameterIdentifier, li(2, 14), "WIDTH"),
            new_inumber_node(NkIntLit, li(2, 22), "32", Base10, -1)
         ])
      ]),
      identifier: new_identifier_node(NkParameterIdentifier, li(2, 14), "WIDTH")
   ),
   (
      parameter: new_node(NkParameterDecl, li(3, 4), @[
         new_node(NkParamAssignment, li(3, 14), @[
            new_identifier_node(NkParameterIdentifier, li(3, 14), "ZERO"),
            new_inumber_node(NkIntLit, li(3, 21), "0", Base10, -1)
         ])
      ]),
      identifier: new_identifier_node(NkParameterIdentifier, li(3, 14), "ZERO")
   )
])


run_test_module_decl("Find all parameters (2)", find_all_parameters, """
module port_finder ();
   parameter FOO = 3;
endmodule
""", @[
   (
      parameter: new_node(NkParameterDecl, li(2, 4), @[
         new_node(NkParamAssignment, li(2, 14), @[
            new_identifier_node(NkParameterIdentifier, li(2, 14), "FOO"),
            new_inumber_node(NkIntLit, li(2, 20), "3", Base10, -1)
         ])
      ]),
      identifier: new_identifier_node(NkParameterIdentifier, li(2, 14), "FOO")
   )
])


run_test_drivers("Find all drivers", """
module port_finder (
   input wire clk_i,
   output wire data_o
);

   assign first_driver = 0;

   always @(posedge clk_i) begin
      assign {foo, {bar, baz}} = breaking_net;
      tmp0 <= 0;
      tmp1 = 1;
   end

endmodule
""", @[
   (
      driver: new_node(NkPortDecl, li(2, 4), @[
         new_identifier_node(NkDirection, li(2, 4), "input"),
         new_identifier_node(NkNetType, li(2, 10), "wire"),
         new_identifier_node(NkPortIdentifier, li(2, 15), "clk_i"),
      ]),
      identifier: new_identifier_node(NkPortIdentifier, li(2, 15), "clk_i")
   ),
   (
      driver: new_node(NkContinuousAssignment, li(6, 4), @[
         new_node(NkAssignment, li(6, 11), @[
            new_node(NkVariableLvalue, li(6, 11), @[
               new_identifier_node(NkIdentifier, li(6, 11), "first_driver")
            ]),
            new_inumber_node(NkIntLit, li(6, 26), "0", Base10, -1)
         ])
      ]),
      identifier: new_identifier_node(NkIdentifier, li(6, 11), "first_driver")
   ),
   (
      driver: new_node(NkProceduralContinuousAssignment, li(9, 7), @[
         new_identifier_node(NkType, li(9, 7), "assign"),
         new_node(NkVariableLvalueConcat, li(9, 14), @[
            new_node(NkVariableLvalue, li(9, 15), @[
               new_identifier_node(NkIdentifier, li(9, 15), "foo")
            ]),
            new_node(NkVariableLvalueConcat, li(9, 20), @[
               new_node(NkVariableLvalue, li(9, 21), @[
                  new_identifier_node(NkIdentifier, li(9, 21), "bar")
               ]),
               new_node(NkVariableLvalue, li(9, 26), @[
                  new_identifier_node(NkIdentifier, li(9, 26), "baz")
               ]),
            ]),
         ]),
         new_identifier_node(NkIdentifier, li(9, 34), "breaking_net")
      ]),
      identifier: new_identifier_node(NkIdentifier, li(9, 15), "foo")
   ),
   (
      driver: new_node(NkProceduralContinuousAssignment, li(9, 7), @[
         new_identifier_node(NkType, li(9, 7), "assign"),
         new_node(NkVariableLvalueConcat, li(9, 14), @[
            new_node(NkVariableLvalue, li(9, 15), @[
               new_identifier_node(NkIdentifier, li(9, 15), "foo")
            ]),
            new_node(NkVariableLvalueConcat, li(9, 20), @[
               new_node(NkVariableLvalue, li(9, 21), @[
                  new_identifier_node(NkIdentifier, li(9, 21), "bar")
               ]),
               new_node(NkVariableLvalue, li(9, 26), @[
                  new_identifier_node(NkIdentifier, li(9, 26), "baz")
               ]),
            ]),
         ]),
         new_identifier_node(NkIdentifier, li(9, 34), "breaking_net")
      ]),
      identifier: new_identifier_node(NkIdentifier, li(9, 21), "bar")
   ),
   (
      driver: new_node(NkProceduralContinuousAssignment, li(9, 7), @[
         new_identifier_node(NkType, li(9, 7), "assign"),
         new_node(NkVariableLvalueConcat, li(9, 14), @[
            new_node(NkVariableLvalue, li(9, 15), @[
               new_identifier_node(NkIdentifier, li(9, 15), "foo")
            ]),
            new_node(NkVariableLvalueConcat, li(9, 20), @[
               new_node(NkVariableLvalue, li(9, 21), @[
                  new_identifier_node(NkIdentifier, li(9, 21), "bar")
               ]),
               new_node(NkVariableLvalue, li(9, 26), @[
                  new_identifier_node(NkIdentifier, li(9, 26), "baz")
               ]),
            ]),
         ]),
         new_identifier_node(NkIdentifier, li(9, 34), "breaking_net")
      ]),
      identifier: new_identifier_node(NkIdentifier, li(9, 26), "baz")
   ),
   (
      driver: new_node(NkNonblockingAssignment, li(10, 7), @[
         new_node(NkVariableLvalue, li(10, 7), @[
            new_identifier_node(NkIdentifier, li(10, 7), "tmp0")
         ]),
         new_inumber_node(NkIntLit, li(10, 15), "0", Base10, -1)
      ]),
      identifier: new_identifier_node(NkIdentifier, li(10, 7), "tmp0")
   ),
   (
      driver: new_node(NkBlockingAssignment, li(11, 7), @[
         new_node(NkVariableLvalue, li(11, 7), @[
            new_identifier_node(NkIdentifier, li(11, 7), "tmp1")
         ]),
         new_inumber_node(NkIntLit, li(11, 14), "1", Base10, -1)
      ]),
      identifier: new_identifier_node(NkIdentifier, li(11, 7), "tmp1")
   )
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
