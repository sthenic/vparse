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
   let response = parse_specific_grammar(stimuli, cache, NkModuleParameterPortList)

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

Test suite: parameter port list
-------------------------------""")

# Run tests
run_test("Single parameter", """#(
   parameter MYPARAM = 0
)"""):
   new_node(NkModuleParameterPortList, li(1, 1), @[
      new_node(NkParameterDecl, li(2, 4), @[
         new_node(NkParamAssignment, li(2, 14), @[
            new_identifier_node(NkParameterIdentifier, li(2, 14), "MYPARAM"),
            new_inumber_node(NkIntLit, li(2, 24), 0, "0", Base10, -1)
         ])
      ])
   ])


run_test("Single parameter, signed", """#(
   parameter signed FOO = -1
)"""):
   new_node(NkModuleParameterPortList, li(1, 1), @[
      new_node(NkParameterDecl, li(2, 4), @[
         new_identifier_node(NkType, li(2, 14), "signed"),
         new_node(NkParamAssignment, li(2, 21), @[
            new_identifier_node(NkParameterIdentifier, li(2, 21), "FOO"),
            new_node(NkPrefix, li(2, 27), @[
               new_identifier_node(NkIdentifier, li(2, 27), "-"),
               new_inumber_node(NkIntLit, li(2, 28), 1, "1", Base10, -1)
            ])
         ])
      ])
   ])


run_test("Single parameter, ranged", """#(
   parameter [7:0] FOO = 8'hFF
)"""):
   new_node(NkModuleParameterPortList, li(1, 1), @[
      new_node(NkParameterDecl, li(2, 4), @[
         new_node(NkRange, li(2, 14), @[
            new_inumber_node(NkIntLit, li(2, 15), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(2, 17), 0, "0", Base10, -1),
         ]),
         new_node(NkParamAssignment, li(2, 20), @[
            new_identifier_node(NkParameterIdentifier, li(2, 20), "FOO"),
            new_inumber_node(NkUIntLit, li(2, 26), 255, "FF", Base16, 8),
         ])
      ])
   ])


run_test("Single parameter, signed range", """#(
   parameter signed [7:0] FOO = 8'hFF
)"""):
   new_node(NkModuleParameterPortList, li(1, 1), @[
      new_node(NkParameterDecl, li(2, 4), @[
         new_identifier_node(NkType, li(2, 14), "signed"),
         new_node(NkRange, li(2, 21), @[
            new_inumber_node(NkIntLit, li(2, 22), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(2, 24), 0, "0", Base10, -1),
         ]),
         new_node(NkParamAssignment, li(2, 27), @[
            new_identifier_node(NkParameterIdentifier, li(2, 27), "FOO"),
            new_inumber_node(NkUIntLit, li(2, 33), 255, "FF", Base16, 8),
         ])
      ])
   ])


run_test("Multiple parameters, different types", """#(
   parameter integer PAR_INT = 1,
   parameter real PAR_REAL = 3.14,
   parameter realtime PAR_REALTIME = 2,
   parameter time PAR_TIME = 3
)"""):
   new_node(NkModuleParameterPortList, li(1, 1), @[
      new_node(NkParameterDecl, li(2, 4), @[
         new_identifier_node(NkType, li(2, 14), "integer"),
         new_node(NkParamAssignment, li(2, 22), @[
            new_identifier_node(NkParameterIdentifier, li(2, 22), "PAR_INT"),
            new_inumber_node(NkIntLit, li(2, 32), 1, "1", Base10, -1)
         ])
      ]),
      new_node(NkParameterDecl, li(3, 4), @[
         new_identifier_node(NkType, li(3, 14), "real"),
         new_node(NkParamAssignment, li(3, 19), @[
            new_identifier_node(NkParameterIdentifier, li(3, 19), "PAR_REAL"),
            new_fnumber_node(NkRealLit, li(3, 30), 3.14, "3.14")
         ])
      ]),
      new_node(NkParameterDecl, li(4, 4), @[
         new_identifier_node(NkType, li(4, 14), "realtime"),
         new_node(NkParamAssignment, li(4, 23), @[
            new_identifier_node(NkParameterIdentifier, li(4, 23), "PAR_REALTIME"),
            new_inumber_node(NkIntLit, li(4, 38), 2, "2", Base10, -1)
         ])
      ]),
      new_node(NkParameterDecl, li(5, 4), @[
         new_identifier_node(NkType, li(5, 14), "time"),
         new_node(NkParamAssignment, li(5, 19), @[
            new_identifier_node(NkParameterIdentifier, li(5, 19), "PAR_TIME"),
            new_inumber_node(NkIntLit, li(5, 30), 3, "3", Base10, -1)
         ])
      ])
   ])


run_test("Multiple parameters, same type definition", """#(
   parameter signed [7:0] PAR_SIGNED_8BIT0 = 0,
                          PAR_SIGNED_8BIT1 = 1,
   parameter real PAR_REAL0 = 3.14,
                  PAR_REAL1 = 1.59
)"""):
   new_node(NkModuleParameterPortList, li(1, 1), @[
      new_node(NkParameterDecl, li(2, 4), @[
         new_identifier_node(NkType, li(2, 14), "signed"),
         new_node(NkRange, li(2, 21), @[
            new_inumber_node(NkIntLit, li(2, 22), 7, "7", Base10, -1),
            new_inumber_node(NkIntLit, li(2, 24), 0, "0", Base10, -1),
         ]),
         new_node(NkParamAssignment, li(2, 27), @[
            new_identifier_node(NkParameterIdentifier, li(2, 27), "PAR_SIGNED_8BIT0"),
            new_inumber_node(NkIntLit, li(2, 46), 0, "0", Base10, -1),
         ]),
         new_node(NkParamAssignment, li(3, 27), @[
            new_identifier_node(NkParameterIdentifier, li(3, 27), "PAR_SIGNED_8BIT1"),
            new_inumber_node(NkIntLit, li(3, 46), 1, "1", Base10, -1),
         ])
      ]),
      new_node(NkParameterDecl, li(4, 4), @[
         new_identifier_node(NkType, li(4, 14), "real"),
         new_node(NkParamAssignment, li(4, 19), @[
            new_identifier_node(NkParameterIdentifier, li(4, 19), "PAR_REAL0"),
            new_fnumber_node(NkRealLit, li(4, 31), 3.14, "3.14")
         ]),
         new_node(NkParamAssignment, li(5, 19), @[
            new_identifier_node(NkParameterIdentifier, li(5, 19), "PAR_REAL1"),
            new_fnumber_node(NkRealLit, li(5, 31), 1.59, "1.59")
         ])
      ])
   ])


run_test("Invalid syntax, missing comma between parameter declarations", """#(
   parameter FOO = 0
   parameter BAR = 1
)"""):
   new_node(NkModuleParameterPortList, li(1, 1), @[
      new_node(NkParameterDecl, li(2, 4), @[
         new_node(NkParamAssignment, li(2, 14), @[
            new_identifier_node(NkParameterIdentifier, li(2, 14), "FOO"),
            new_inumber_node(NkIntLit, li(2, 20), 0, "0", Base10, -1)
         ])
      ]),
      new_node(NkExpectError, li(3, 4), @[
         new_error_node(NkTokenError, li(3, 4), "", ""),
         new_error_node(NkTokenError, li(3, 14), "", ""),
         new_error_node(NkTokenError, li(3, 18), "", ""),
         new_error_node(NkTokenError, li(3, 20), "", ""),
         new_error_node(NkTokenErrorSync, li(4, 1), "", "")
      ]),
   ])


run_test("Invalid syntax, missing comma between parameter assignments", """#(
   parameter FOO = 0
             BAR = 1
)"""):
   new_node(NkModuleParameterPortList, li(1, 1), @[
      new_node(NkParameterDecl, li(2, 4), @[
         new_node(NkParamAssignment, li(2, 14), @[
            new_identifier_node(NkParameterIdentifier, li(2, 14), "FOO"),
            new_inumber_node(NkIntLit, li(2, 20), 0, "0", Base10, -1)
         ])
      ]),
      new_node(NkExpectError, li(3, 14), @[
         new_error_node(NkTokenError, li(3, 14), "", ""),
         new_error_node(NkTokenError, li(3, 18), "", ""),
         new_error_node(NkTokenError, li(3, 20), "", ""),
         new_error_node(NkTokenErrorSync, li(4, 1), "", "")
      ]),
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
