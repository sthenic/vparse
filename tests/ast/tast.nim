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


template run_test(title: string, grammar: NodeKind, stimuli, reference: string) =
   cache = new_ident_cache()
   let node = parse_specific_grammar(stimuli, cache, grammar)
   let response = $node
   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
      echo pretty(node)
      echo "'" & response & "'"
      echo "'" & reference & "'"


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: AST to source
-------------------------""")


run_test("Net declaration", NkNetDecl,
"wire   [WIDTH - 1:  FOO +2]   my_wire ;",
"wire [WIDTH - 1:FOO + 2] my_wire")


run_test("Net declaration assignment (ranged) (1)", NkNetDecl,
"wire my_wire = some_other_wire[4][ 3:0 ];",
"wire my_wire = some_other_wire[4][3:0]")


run_test("Net declaration assignment (ranged) (2)", NkNetDecl,
"wire my_wire = some_other_wire[0 +: (WIDTH-1) ];",
"wire my_wire = some_other_wire[0 +: (WIDTH - 1)]")


run_test("Complex trireg declaration", NkNetDecl,
"trireg (small) scalared signed [7 : 0] #(1,2,3) first, second;",
"trireg (small) scalared signed [7:0] #(1, 2, 3) first, second")


run_test("Complex wire declaration", NkNetDecl,
"wire (highz0, supply1) vectored signed [7:0] #(1,2,3) first = 8'd0, second = 8'h23;",
"wire (highz0, supply1) vectored signed [7:0] #(1, 2, 3) first = 8'd0, second = 8'h23")


run_test("Register declaration", NkRegDecl,
"reg   [WIDTH - 1:  FOO +2]   a_reg ;",
"reg [WIDTH - 1:FOO + 2] a_reg")


run_test("Register declaration, concatenation", NkRegDecl,
"reg [15:0  ]  default_constant = {8'hDE , {4  {1'b0}}, 2'b01, {2{1'b1}} };",
"reg [15:0] default_constant = {8'hDE, {4{1'b0}}, 2'b01, {2{1'b1}}}")


run_test("Localparam declaration", NkLocalparamDecl,
"localparam  WIDTH = 32, BAR = 23 ;",
"localparam WIDTH = 32, BAR = 23")


run_test("Parameter declaration", NkParameterDecl,
"parameter  INPUT_WIDTH = 32, ANOTHER_PARAMETER= 3 ",
"parameter INPUT_WIDTH = 32, ANOTHER_PARAMETER = 3")


run_test("Function declaration", NkFunctionDecl,
"""
/* This is the documentation of the `add_one` function. */
function automatic signed [SOME_WIDTH-1:0] add_one(input a, input [7:0] foo);
   add_one = a + 1;
endfunction""",
"function automatic signed [SOME_WIDTH - 1:0] add_one(input a, input [7:0] foo)")


run_test("Task declaration: empty", NkTaskDecl,
"""
/* This is the documentation of the `an_empty_task` function. */
task an_empty_task;
   reg_no_default <= 1'b0;
endtask""",
"task an_empty_task()")


run_test("Task declaration: w/ parameters", NkTaskDecl,
"""
/* This is the documentation of the `an_empty_task` function. */
task automatic an_empty_task(input [7:0] foo_in, output [31:0] foo_out);
   reg_no_default <= 1'b0;
endtask""",
"task automatic an_empty_task(input [7:0] foo_in, output [31:0] foo_out)")


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
