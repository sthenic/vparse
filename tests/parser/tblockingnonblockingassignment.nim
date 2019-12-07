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
   let response = parse_specific_grammar(stimuli, cache, NtBlockingAssignment)

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


run_test("Simple blocking assignment", "foo = 3"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_inumber_node(NtIntLit, li(1, 7), 3, "3", Base10, -1)
   ])

run_test("Simple nonblocking assignment", "baar <= baz"):
   new_node(NtNonblockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "baar")
      ]),
      new_identifier_node(NtIdentifier, li(1, 9), "baz")
   ])

run_test("Concatenated blocking assignment", "{wire0, wire1} = big_wire"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalueConcat, li(1, 1), @[
         new_node(NtVariableLvalue, li(1, 2), @[
            new_identifier_node(NtIdentifier, li(1, 2), "wire0"),
         ]),
         new_node(NtVariableLvalue, li(1, 9), @[
            new_identifier_node(NtIdentifier, li(1, 9), "wire1")
         ]),
      ]),
      new_identifier_node(NtIdentifier, li(1, 18), "big_wire")
   ])

run_test("Concatenated nonblocking assignment", "{wire0, wire1} <= big_wire"):
   new_node(NtNonblockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalueConcat, li(1, 1), @[
         new_node(NtVariableLvalue, li(1, 2), @[
            new_identifier_node(NtIdentifier, li(1, 2), "wire0"),
         ]),
         new_node(NtVariableLvalue, li(1, 9), @[
            new_identifier_node(NtIdentifier, li(1, 9), "wire1")
         ]),
      ]),
      new_identifier_node(NtIdentifier, li(1, 19), "big_wire")
   ])

run_test("Blocking assignment: delay control, integer", "foo = #2 FOO"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_node(NtDelay, li(1, 7), @[
         new_inumber_node(NtIntLit, li(1, 8), 2, "2", Base10, -1)
      ]),
      new_identifier_node(NtIdentifier, li(1, 10), "FOO")
   ])

run_test("Blocking assignment: delay control, real", "foo = #4.21 FOO"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_node(NtDelay, li(1, 7), @[
         new_fnumber_node(NtRealLit, li(1, 8), 4.21, "4.21")
      ]),
      new_identifier_node(NtIdentifier, li(1, 13), "FOO")
   ])

run_test("Blocking assignment: delay control, identifier", "foo = #BAR FOO"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_node(NtDelay, li(1, 7), @[
         new_identifier_node(NtIdentifier, li(1, 8), "BAR")
      ]),
      new_identifier_node(NtIdentifier, li(1, 12), "FOO")
   ])

run_test("Blocking assignment: delay control, mintypmax", "foo = #(2:3:5) FOO"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_node(NtDelay, li(1, 7), @[
         new_node(NtParenthesis, li(1, 8), @[
            new_node(NtConstantMinTypMaxExpression, li(1, 9), @[
               new_inumber_node(NtIntLit, li(1, 9), 2, "2", Base10, -1),
               new_inumber_node(NtIntLit, li(1, 11), 3, "3", Base10, -1),
               new_inumber_node(NtIntLit, li(1, 13), 5, "5", Base10, -1)
            ]),
         ]),
      ]),
      new_identifier_node(NtIdentifier, li(1, 16), "FOO")
   ])

run_test("Blocking assignment: delay control, error", "foo = #begin FOO"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_node(NtDelay, li(1, 7), @[
         new_error_node(li(1, 8), "")
      ]),
      new_error_node(li(1, 8), "")
   ])

run_test("Blocking assignment: event control, identifier", "foo = @some_event FOO"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_node(NtEventControl, li(1, 7), @[
         new_identifier_node(NtIdentifier, li(1, 8), "some_event")
      ]),
      new_identifier_node(NtIdentifier, li(1, 19), "FOO")
   ])

run_test("Blocking assignment: event control, wildcard w/o parentheses", "foo = @* FOO"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_node(NtEventControl, li(1, 7), @[
         new_node(NtWildcard, li(1, 8))
      ]),
      new_identifier_node(NtIdentifier, li(1, 10), "FOO")
   ])

run_test("Blocking assignment: event control, wildcard w/ parentheses", "foo = @(*) FOO"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_node(NtEventControl, li(1, 7), @[
         new_node(NtParenthesis, li(1, 8), @[
            new_node(NtWildcard, li(1, 9))
         ]),
      ]),
      new_identifier_node(NtIdentifier, li(1, 12), "FOO")
   ])

run_test("Blocking assignment: event control, wildcard w/ parentheses, spaced out", "foo = @( * ) FOO"):
   new_node(NtBlockingAssignment, li(1, 1), @[
      new_node(NtVariableLvalue, li(1, 1), @[
         new_identifier_node(NtIdentifier, li(1, 1), "foo")
      ]),
      new_node(NtEventControl, li(1, 7), @[
         new_node(NtParenthesis, li(1, 8), @[
            new_node(NtWildcard, li(1, 10))
         ]),
      ]),
      new_identifier_node(NtIdentifier, li(1, 14), "FOO")
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
