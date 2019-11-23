import terminal
import strformat
import strutils

import ../../src/parser/parser
import ../../src/parser/ast
import ../../src/lexer/identifier
import ../../src/lexer/lexer

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

# FIXME: Tests w/ attribute instances when that's implemented.

for direction in [TkInput, TkInout, TkOutput]:
   for net_type in NetTypeTokens:
      run_test(format("$1 port, net type $2", direction, net_type), format("""(
   $1
   $2
   my_port
)""", TokenTypeToStr[direction], TokenTypeToStr[net_type])):
         new_node(NtListOfPortDeclarations, li(2, 4), @[
            new_node(NtPortDecl, li(2, 4), @[
               new_identifier_node(NtDirection, li(2, 4), TokenTypeToStr[direction]),
               new_identifier_node(NtNetType, li(3, 4), TokenTypeToStr[net_type]),
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
