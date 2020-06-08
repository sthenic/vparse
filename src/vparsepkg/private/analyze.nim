import strformat
import terminal
import ../graph

proc write_errors*(f: File, n: PNode) =
   ## Returns ``true`` if the AST starting with the node ``n`` contains errors.
   case n.kind
   of ErrorTypes - {NkTokenErrorSync}:
      let loc = $n.loc.line & ":" & $(n.loc.col + 1)
      var msg = n.msg
      if len(n.eraw) > 0:
         add(msg, &" ({n.eraw})")
      add(msg, "\n")
      styled_write(f, styleBright, &"{loc:<8} ", resetStyle, msg)
   of PrimitiveTypes - ErrorTypes + {NkTokenErrorSync}:
      return
   else:
      for i in 0..<len(n.sons):
         write_errors(f, n.sons[i])
