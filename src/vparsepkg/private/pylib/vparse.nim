import nimpy
import strutils

import ../../graph
import streams

type
   PGraphHandle = ref GraphHandle
   GraphHandle = object
      graph: Graph
      cache: IdentifierCache


proc io_error(msg: string, args: varargs[string, `$`]): ref IOError =
   new result
   result.msg = format(msg, args)


proc open_graph(filename: string, include_paths: PyObject, defines: PyObject): PGraphHandle {.exportpy.} =
   new result
   result.cache = new_ident_cache()
   let fs = new_file_stream($filename)
   if is_nil(fs):
      raise io_error("Failed to open file '$1'.", filename)
   open_graph(result.graph, result.cache, fs, filename, include_paths.to(seq[string]),
              defines.to(seq[string]))
   close(fs)


proc close_graph(h: PGraphHandle) {.exportpy.} =
   close_graph(h.graph)


proc get_root_node(h: PGraphHandle): PNode {.exportpy.} =
   result = h.graph.root_node


proc has_errors(n: PNode): bool {.exportpy.} =
   result = graph.ast.has_errors(n)


iterator walk_module_declarations(n: PNode): PNode {.exportpy.} =
   if n.kind == NkSourceText:
      for s in walk_sons(n, NkModuleDecl):
         yield s


iterator walk_ports(n: PNode): PNode {.exportpy.} =
   for port in graph.ast.walk_ports(n):
      yield port


iterator walk_parameter_ports(n: PNode): PNode {.exportpy.} =
   for port in graph.ast.walk_parameter_ports(n):
      yield port


proc get_direction(n: PNode): string {.exportpy.} =
   if n.kind == NkPortDecl:
      let dir = find_first(n, NkDirection)
      if not is_nil(dir):
         result = dir.identifier.s


proc get_net_type(n: PNode): string {.exportpy.} =
   if n.kind == NkPortDecl:
      let net_type = find_first(n, NkNetType)
      if not is_nil(net_type):
         result = net_type.identifier.s


proc get_net_range(n: PNode): tuple[high, low: PNode] {.exportpy.} =
   if n.kind == NkPortDecl:
      let range = find_first(n, NkRange)
      if not is_nil(range):
         result.high = range.sons[0]
         result.low = range.sons[1]


proc get_identifier(n: PNode): string {.exportpy.} =
   case n.kind
   of IdentifierTypes:
      result = n.identifier.s
   of NkPortDecl:
      let id = find_first(n, NkPortIdentifier)
      if not is_nil(id):
         result = id.identifier.s
   else:
      discard
