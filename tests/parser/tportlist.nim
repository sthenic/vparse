import streams
import terminal
import strformat

import ../../src/parser/parser
import ../../src/parser/ast
import ../../src/lexer/identifier
import ../../src/lexer/lexer

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0
   p: Parser


template run_test(title, stimuli: string, reference: PNode,
                  debug: bool = false) =
   var response: PNode
   let cache = new_ident_cache()
   response = parse_specific_grammar(stimuli, cache, NtListOfPortDeclarations)
   echo pretty(response)

run_test("test_0", """
(
   input wire clk_i,
              another_i,
   input wire signed [ADDR-1:0] addr_i,
   output integer MYTIME = 89 + ABD,
   output reg signed [56:0] nice, anda, soas = 7,
   output wire signed [33:0] hello, orz
)""", nil)
