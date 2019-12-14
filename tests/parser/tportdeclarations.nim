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
   let response = parse_specific_grammar(stimuli, cache, NtListOfPortDeclarations)

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

template new_identifier_node(kind: NodeType, info: TLineInfo, str: string): untyped =
   new_identifier_node(kind, info, get_identifier(cache, str))


run_test("Single port (input)", """(
   input clk_i
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "input"),
         new_identifier_node(NtPortIdentifier, li(2, 10), "clk_i"),
      ])
   ])


run_test("Single port (inout)", """(
   inout data_io
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "inout"),
         new_identifier_node(NtPortIdentifier, li(2, 10), "data_io"),
      ])
   ])


run_test("Single port (output)", """(
   output data_o
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "output"),
         new_identifier_node(NtPortIdentifier, li(2, 11), "data_o"),
      ])
   ])


run_test("Single port (attribute instances)", """(
   (* mark_debug = true, my_attr *) (* attr = val *) output data_o
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 54), @[
         new_node(NtAttributeInst, li(2, 4), @[
            new_identifier_node(NtAttributeName, li(2, 7), "mark_debug"),
            cprim(new_identifier_node(NtIdentifier, li(2, 20), "true")),
            new_identifier_node(NtAttributeName, li(2, 26), "my_attr"),
         ]),
         new_node(NtAttributeInst, li(2,37), @[
            new_identifier_node(NtAttributeName, li(2, 40), "attr"),
            cprim(new_identifier_node(NtIdentifier, li(2, 47), "val")),
         ]),
         new_identifier_node(NtDirection, li(2, 54), "output"),
         new_identifier_node(NtPortIdentifier, li(2, 61), "data_o"),
      ])
   ])


run_test("Empty list", "()"):
   new_node(NtListOfPortDeclarations, li(1, 2))


run_test("Multilple ports, mixed direction", """(
   input clk_i,
   inout data_io,
   output data_o
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "input"),
         new_identifier_node(NtPortIdentifier, li(2, 10), "clk_i"),
      ]),
      new_node(NtPortDecl, li(3, 4), @[
         new_identifier_node(NtDirection, li(3, 4), "inout"),
         new_identifier_node(NtPortIdentifier, li(3, 10), "data_io"),
      ]),
      new_node(NtPortDecl, li(4, 4), @[
         new_identifier_node(NtDirection, li(4, 4), "output"),
         new_identifier_node(NtPortIdentifier, li(4, 11), "data_o"),
      ])
   ])


run_test("Multilple ports, missing comma", """(
   input clk_i
   inout data_io
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "input"),
         new_identifier_node(NtPortIdentifier, li(2, 10), "clk_i"),
      ]),
      new_error_node(li(3, 4), "")
   ])


run_test("Multilple ports, same type", """(
   input clk_i,
         another_port_i,
         the_last_port_i,
   inout data_io,
         another_port_io,
   output data_o,
          another_port_o
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "input"),
         new_identifier_node(NtPortIdentifier, li(2, 10), "clk_i"),
         new_identifier_node(NtPortIdentifier, li(3, 10), "another_port_i"),
         new_identifier_node(NtPortIdentifier, li(4, 10), "the_last_port_i"),
      ]),
      new_node(NtPortDecl, li(5, 4), @[
         new_identifier_node(NtDirection, li(5, 4), "inout"),
         new_identifier_node(NtPortIdentifier, li(5, 10), "data_io"),
         new_identifier_node(NtPortIdentifier, li(6, 10), "another_port_io"),
      ]),
      new_node(NtPortDecl, li(7, 4), @[
         new_identifier_node(NtDirection, li(7, 4), "output"),
         new_identifier_node(NtPortIdentifier, li(7, 11), "data_o"),
         new_identifier_node(NtPortIdentifier, li(8, 11), "another_port_o"),
      ])
   ])


for direction in [TkInput, TkInout, TkOutput]:
   for net_type in NetTypeTokens:
      run_test(format("$1 port, net type $2", direction, net_type), format("""(
   $1
   $2
   my_port
)""", TokenKindToStr[direction], TokenKindToStr[net_type])):
         new_node(NtListOfPortDeclarations, li(2, 4), @[
            new_node(NtPortDecl, li(2, 4), @[
               new_identifier_node(NtDirection, li(2, 4), TokenKindToStr[direction]),
               new_identifier_node(NtNetType, li(3, 4), TokenKindToStr[net_type]),
               new_identifier_node(NtPortIdentifier, li(4, 4), "my_port"),
            ])
         ])


run_test("Signed ports", """(
   input signed signed_input,
   inout signed signed_inout,
   output signed signed_output,
   input wire signed signed_input_wire,
   inout wire signed signed_inout_wire,
   output wire signed signed_output_wire
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "input"),
         new_identifier_node(NtType, li(2, 10), "signed"),
         new_identifier_node(NtPortIdentifier, li(2, 17), "signed_input"),
      ]),
      new_node(NtPortDecl, li(3, 4), @[
         new_identifier_node(NtDirection, li(3, 4), "inout"),
         new_identifier_node(NtType, li(3, 10), "signed"),
         new_identifier_node(NtPortIdentifier, li(3, 17), "signed_inout"),
      ]),
      new_node(NtPortDecl, li(4, 4), @[
         new_identifier_node(NtDirection, li(4, 4), "output"),
         new_identifier_node(NtType, li(4, 11), "signed"),
         new_identifier_node(NtPortIdentifier, li(4, 18), "signed_output"),
      ]),
      new_node(NtPortDecl, li(5, 4), @[
         new_identifier_node(NtDirection, li(5, 4), "input"),
         new_identifier_node(NtNetType, li(5, 10), "wire"),
         new_identifier_node(NtType, li(5, 15), "signed"),
         new_identifier_node(NtPortIdentifier, li(5, 22), "signed_input_wire"),
      ]),
      new_node(NtPortDecl, li(6, 4), @[
         new_identifier_node(NtDirection, li(6, 4), "inout"),
         new_identifier_node(NtNetType, li(6, 10), "wire"),
         new_identifier_node(NtType, li(6, 15), "signed"),
         new_identifier_node(NtPortIdentifier, li(6, 22), "signed_inout_wire"),
      ]),
      new_node(NtPortDecl, li(7, 4), @[
         new_identifier_node(NtDirection, li(7, 4), "output"),
         new_identifier_node(NtNetType, li(7, 11), "wire"),
         new_identifier_node(NtType, li(7, 16), "signed"),
         new_identifier_node(NtPortIdentifier, li(7, 23), "signed_output_wire"),
      ])
   ])


run_test("Ranged ports", """(
   input [ADDR-1:0] ranged_input,
   inout [7:0] ranged_inout,
   output [0:0] ranged_output,
   input wire [ADDR-1:0] ranged_input_wire,
   inout wire [7:0] ranged_inout_wire,
   output wire [0:0] ranged_output_wire
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "input"),
         new_node(NtRange, li(2, 10), @[
            new_node(NtInfix, li(2, 15), @[
               new_identifier_node(NtIdentifier, li(2, 15), "-"),
               cprim(new_identifier_node(NtIdentifier, li(2, 11), "ADDR")),
               cprim(new_inumber_node(NtIntLit, li(2, 16), 1, "1", Base10, -1))
            ]),
            cprim(new_inumber_node(NtIntLit, li(2, 18), 0, "0", Base10, -1))
         ]),
         new_identifier_node(NtPortIdentifier, li(2, 21), "ranged_input"),
      ]),
      new_node(NtPortDecl, li(3, 4), @[
         new_identifier_node(NtDirection, li(3, 4), "inout"),
         new_node(NtRange, li(3, 10), @[
            cprim(new_inumber_node(NtIntLit, li(3, 11), 7, "7", Base10, -1)),
            cprim(new_inumber_node(NtIntLit, li(3, 13), 0, "0", Base10, -1))
         ]),
         new_identifier_node(NtPortIdentifier, li(3, 16), "ranged_inout"),
      ]),
      new_node(NtPortDecl, li(4, 4), @[
         new_identifier_node(NtDirection, li(4, 4), "output"),
         new_node(NtRange, li(4, 11), @[
            cprim(new_inumber_node(NtIntLit, li(4, 12), 0, "0", Base10, -1)),
            cprim(new_inumber_node(NtIntLit, li(4, 14), 0, "0", Base10, -1))
         ]),
         new_identifier_node(NtPortIdentifier, li(4, 17), "ranged_output"),
      ]),
      new_node(NtPortDecl, li(5, 4), @[
         new_identifier_node(NtDirection, li(5, 4), "input"),
         new_identifier_node(NtNetType, li(5, 10), "wire"),
         new_node(NtRange, li(5, 15), @[
            new_node(NtInfix, li(5, 20), @[
               new_identifier_node(NtIdentifier, li(5, 20), "-"),
               cprim(new_identifier_node(NtIdentifier, li(5, 16), "ADDR")),
               cprim(new_inumber_node(NtIntLit, li(5, 21), 1, "1", Base10, -1))
            ]),
            cprim(new_inumber_node(NtIntLit, li(5, 23), 0, "0", Base10, -1))
         ]),
         new_identifier_node(NtPortIdentifier, li(5, 26), "ranged_input_wire"),
      ]),
      new_node(NtPortDecl, li(6, 4), @[
         new_identifier_node(NtDirection, li(6, 4), "inout"),
         new_identifier_node(NtNetType, li(6, 10), "wire"),
         new_node(NtRange, li(6, 15), @[
            cprim(new_inumber_node(NtIntLit, li(6, 16), 7, "7", Base10, -1)),
            cprim(new_inumber_node(NtIntLit, li(6, 18), 0, "0", Base10, -1))
         ]),
         new_identifier_node(NtPortIdentifier, li(6, 21), "ranged_inout_wire"),
      ]),
      new_node(NtPortDecl, li(7, 4), @[
         new_identifier_node(NtDirection, li(7, 4), "output"),
         new_identifier_node(NtNetType, li(7, 11), "wire"),
         new_node(NtRange, li(7, 16), @[
            cprim(new_inumber_node(NtIntLit, li(7, 17), 0, "0", Base10, -1)),
            cprim(new_inumber_node(NtIntLit, li(7, 19), 0, "0", Base10, -1))
         ]),
         new_identifier_node(NtPortIdentifier, li(7, 22), "ranged_output_wire"),
      ])
   ])

run_test("Output reg ports", """(
   output reg data_o,
              port_o = 8'hEA
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "output"),
         new_identifier_node(NtNetType, li(2, 11), "reg"),
         new_identifier_node(NtPortIdentifier, li(2, 15), "data_o"),
         new_node(NtVariablePort, li(3, 15), @[
            new_identifier_node(NtPortIdentifier, li(3, 15), "port_o"),
            cprim(new_inumber_node(NtUIntLit, li(3, 24), 234, "EA", Base16, 8))
         ])
      ])
   ])


run_test("Full output reg port", """(
   output reg signed [7:0] data_o
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "output"),
         new_identifier_node(NtNetType, li(2, 11), "reg"),
         new_identifier_node(NtType, li(2, 15), "signed"),
         new_node(NtRange, li(2, 22), @[
            cprim(new_inumber_node(NtIntLit, li(2, 23), 7, "7", Base10, -1)),
            cprim(new_inumber_node(NtIntLit, li(2, 25), 0, "0", Base10, -1))
         ]),
         new_identifier_node(NtPortIdentifier, li(2, 28), "data_o"),
      ])
   ])


run_test("Variable output port", """(
   output integer int_o = 64,
   output time time_o = 3.4
)"""):
   new_node(NtListOfPortDeclarations, li(2, 4), @[
      new_node(NtPortDecl, li(2, 4), @[
         new_identifier_node(NtDirection, li(2, 4), "output"),
         new_identifier_node(NtNetType, li(2, 11), "integer"),
         new_node(NtVariablePort, li(2, 19), @[
            new_identifier_node(NtPortIdentifier, li(2, 19), "int_o"),
            cprim(new_inumber_node(NtIntLit, li(2, 27), 64, "64", Base10, -1))
         ]),
      ]),
      new_node(NtPortDecl, li(3, 4), @[
         new_identifier_node(NtDirection, li(3, 4), "output"),
         new_identifier_node(NtNetType, li(3, 11), "time"),
         new_node(NtVariablePort, li(3, 16), @[
            new_identifier_node(NtPortIdentifier, li(3, 16), "time_o"),
            cprim(new_fnumber_node(NtRealLit, li(3, 25), 3.4, "3.4"))
         ]),
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
