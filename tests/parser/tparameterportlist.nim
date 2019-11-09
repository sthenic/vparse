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
      param2 = 3;
   parameter stuff = 2;
   parameter real MYREAL_ = 3.4;
)"""
, nil)
