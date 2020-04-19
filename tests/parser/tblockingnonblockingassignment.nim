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
   let response = parse_specific_grammar(stimuli, cache, NkBlockingAssignment)

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
   result = new_line_info(line, col - 1, 1)


template new_identifier_node(kind: NodeKind, info: TLineInfo, str: string): untyped =
   new_identifier_node(kind, info, get_identifier(cache, str))

# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: blocking & nonblocking assignment
---------------------------------------------""")

# Run tests
run_test("Simple blocking assignment", "foo = 3"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_inumber_node(NkIntLit, li(1, 7), 3, "3", Base10, -1)
   ])

run_test("Simple nonblocking assignment", "baar <= baz"):
   new_node(NkNonblockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "baar")
      ]),
      new_identifier_node(NkIdentifier, li(1, 9), "baz")
   ])

run_test("Concatenated blocking assignment", "{wire0, wire1} = big_wire"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalueConcat, li(1, 1), @[
         new_node(NkVariableLvalue, li(1, 2), @[
            new_identifier_node(NkIdentifier, li(1, 2), "wire0"),
         ]),
         new_node(NkVariableLvalue, li(1, 9), @[
            new_identifier_node(NkIdentifier, li(1, 9), "wire1")
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 18), "big_wire")
   ])

run_test("Concatenated nonblocking assignment", "{wire0, wire1} <= big_wire"):
   new_node(NkNonblockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalueConcat, li(1, 1), @[
         new_node(NkVariableLvalue, li(1, 2), @[
            new_identifier_node(NkIdentifier, li(1, 2), "wire0"),
         ]),
         new_node(NkVariableLvalue, li(1, 9), @[
            new_identifier_node(NkIdentifier, li(1, 9), "wire1")
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 19), "big_wire")
   ])

run_test("Blocking assignment: delay control, integer", "foo = #2 FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkDelay, li(1, 7), @[
         new_inumber_node(NkIntLit, li(1, 8), 2, "2", Base10, -1)
      ]),
      new_identifier_node(NkIdentifier, li(1, 10), "FOO")
   ])

run_test("Blocking assignment: delay control, real", "foo = #4.21 FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkDelay, li(1, 7), @[
         new_fnumber_node(NkRealLit, li(1, 8), 4.21, "4.21")
      ]),
      new_identifier_node(NkIdentifier, li(1, 13), "FOO")
   ])

run_test("Blocking assignment: delay control, identifier", "foo = #BAR FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkDelay, li(1, 7), @[
         new_identifier_node(NkIdentifier, li(1, 8), "BAR")
      ]),
      new_identifier_node(NkIdentifier, li(1, 12), "FOO")
   ])

run_test("Blocking assignment: delay control, mintypmax", "foo = #(2:3:5) FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkDelay, li(1, 7), @[
         new_node(NkParenthesis, li(1, 8), @[
            new_node(NkConstantMinTypMaxExpression, li(1, 9), @[
               new_inumber_node(NkIntLit, li(1, 9), 2, "2", Base10, -1),
               new_inumber_node(NkIntLit, li(1, 11), 3, "3", Base10, -1),
               new_inumber_node(NkIntLit, li(1, 13), 5, "5", Base10, -1)
            ]),
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 16), "FOO")
   ])

run_test("Blocking assignment: delay control, error", "foo = #begin FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkDelay, li(1, 7), @[
         new_error_node(NkTokenError, li(1, 8), "", "")
      ]),
      new_identifier_node(NkIdentifier, li(1, 14), "FOO")
   ])

run_test("Blocking assignment: event control, identifier", "foo = @some_event FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkEventControl, li(1, 7), @[
         new_identifier_node(NkIdentifier, li(1, 8), "some_event")
      ]),
      new_identifier_node(NkIdentifier, li(1, 19), "FOO")
   ])

run_test("Blocking assignment: event control, wildcard w/o parentheses", "foo = @* FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkEventControl, li(1, 7), @[
         new_node(NkWildcard, li(1, 8))
      ]),
      new_identifier_node(NkIdentifier, li(1, 10), "FOO")
   ])

run_test("Blocking assignment: event control, wildcard w/ parentheses", "foo = @(*) FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkEventControl, li(1, 7), @[
         new_node(NkParenthesis, li(1, 8), @[
            new_node(NkWildcard, li(1, 9))
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 12), "FOO")
   ])

run_test("Blocking assignment: event control, wildcard w/ parentheses, spaced out", "foo = @( * ) FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkEventControl, li(1, 7), @[
         new_node(NkParenthesis, li(1, 8), @[
            new_node(NkWildcard, li(1, 10))
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 14), "FOO")
   ])

run_test("Blocking assignment: event control, event expression, posedge", "foo = @(posedge clk) FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkEventControl, li(1, 7), @[
         new_node(NkParenthesis, li(1, 8), @[
            new_node(NkEventExpression, li(1, 9), @[
               new_identifier_node(NkType, li(1, 9), "posedge"),
               new_identifier_node(NkIdentifier, li(1, 17), "clk")
            ]),
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 22), "FOO")
   ])

run_test("Blocking assignment: event control, event expression, negedge", "foo = @(negedge clk) FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkEventControl, li(1, 7), @[
         new_node(NkParenthesis, li(1, 8), @[
            new_node(NkEventExpression, li(1, 9), @[
               new_identifier_node(NkType, li(1, 9), "negedge"),
               new_identifier_node(NkIdentifier, li(1, 17), "clk")
            ]),
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 22), "FOO")
   ])

run_test("Blocking assignment: event control, event expression, expression", "foo = @(A_SYMBOL + 3) FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkEventControl, li(1, 7), @[
         new_node(NkParenthesis, li(1, 8), @[
            new_node(NkEventExpression, li(1, 9), @[
               new_node(NkInfix, li(1, 18), @[
                  new_identifier_node(NkIdentifier, li(1, 18), "+"),
                  new_identifier_node(NkIdentifier, li(1, 9), "A_SYMBOL"),
                  new_inumber_node(NkIntLit, li(1, 20), 3, "3", Base10, -1)
               ]),
            ]),
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 23), "FOO")
   ])

run_test("Blocking assignment: event control, multiple event expressions (or)", "foo = @(posedge clk or negedge rst_n or random_signal) FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkEventControl, li(1, 7), @[
         new_node(NkParenthesis, li(1, 8), @[
            new_node(NkEventOr, li(1, 21), @[
               new_node(NkEventExpression, li(1, 9), @[
                  new_identifier_node(NkType, li(1, 9), "posedge"),
                  new_identifier_node(NkIdentifier, li(1, 17), "clk")
               ]),
               new_node(NkEventOr, li(1, 38), @[
                  new_node(NkEventExpression, li(1, 24), @[
                     new_identifier_node(NkType, li(1, 24), "negedge"),
                     new_identifier_node(NkIdentifier, li(1, 32), "rst_n")
                  ]),
                  new_node(NkEventExpression, li(1, 41), @[
                     new_identifier_node(NkIdentifier, li(1, 41), "random_signal")
                  ]),
               ]),
            ]),
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 56), "FOO")
   ])

run_test("Blocking assignment: event control, multiple event expressions (mixed)", "foo = @(posedge clk, negedge rst_n or random_signal) FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkEventControl, li(1, 7), @[
         new_node(NkParenthesis, li(1, 8), @[
            new_node(NkEventComma, li(1, 20), @[
               new_node(NkEventExpression, li(1, 9), @[
                  new_identifier_node(NkType, li(1, 9), "posedge"),
                  new_identifier_node(NkIdentifier, li(1, 17), "clk")
               ]),
               new_node(NkEventOr, li(1, 36), @[
                  new_node(NkEventExpression, li(1, 22), @[
                     new_identifier_node(NkType, li(1, 22), "negedge"),
                     new_identifier_node(NkIdentifier, li(1, 30), "rst_n")
                  ]),
                  new_node(NkEventExpression, li(1, 39), @[
                     new_identifier_node(NkIdentifier, li(1, 39), "random_signal")
                  ]),
               ]),
            ]),
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 54), "FOO")
   ])

run_test("Blocking assignment: event control, repeat", "foo = repeat (3) @(posedge clk) FOO"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_node(NkVariableLvalue, li(1, 1), @[
         new_identifier_node(NkIdentifier, li(1, 1), "foo")
      ]),
      new_node(NkRepeat, li(1, 7), @[
         new_inumber_node(NkIntLit, li(1, 15), 3, "3", Base10, -1),
         new_node(NkEventControl, li(1, 18), @[
            new_node(NkParenthesis, li(1, 19), @[
               new_node(NkEventExpression, li(1, 20), @[
                  new_identifier_node(NkType, li(1, 20), "posedge"),
                  new_identifier_node(NkIdentifier, li(1, 28), "clk")
               ])
            ]),
         ]),
      ]),
      new_identifier_node(NkIdentifier, li(1, 33), "FOO")
   ])

run_test("Blocking assignment: error", "foo A"):
   new_node(NkBlockingAssignment, li(1, 1), @[
      new_error_node(NkTokenError, li(1, 5), "", "")
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
