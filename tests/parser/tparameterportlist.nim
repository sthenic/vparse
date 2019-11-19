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
   response = parse_specific_grammar(stimuli, cache, NtModuleParameterPortList)
   echo pretty(response)

run_test("test_0", """
#(
   parameter signed [5:0]
      myparam = 2,
      param2 = {3,2,1},
      multi = (2:1:2),
      binpar = {MY_MAN{3'b01X}},
   parameter [7:0] stuff = AMAZING,
   parameter real N_sa$ICE = 3.4e-1,
   parameter signed A_func = myfunc(4, 5, SOMETHING),
   parameter infantry = (32'd2),
   parameter MYPAR = ((THING == 9) ? AWESOME : STUFF) - 9
)""", nil)
