import streams
import terminal
import strformat

import ../../src/parser/parser
import ../../src/parser/ast
import ../../src/lexer/identifier

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0
   p: Parser


template run_test(title, stimuli: string, reference: PNode,
                  debug: bool = false) =
   var response: PNode
   let cache = new_ident_cache()
   response = parse_string(stimuli, cache)
   echo pretty(response)


run_test("test_0", "(* hello = 0 *) (*noice *) module nice! endmodule (* hello = 0 *)module", nil)
