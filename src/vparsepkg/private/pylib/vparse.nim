import nimpy
import strutils
import json

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


proc new_graph(): PGraphHandle {.exportpy.} =
   new result


proc parse(h: PGraphHandle, filename: string, include_paths: PyObject, defines: PyObject): PNode {.exportpy.} =
   let fs = new_file_stream($filename)
   if is_nil(fs):
      raise io_error("Failed to open file '$1'.", filename)
   h.cache = new_ident_cache()
   h.graph = new_graph(h.cache)
   result = parse(h.graph, fs, filename, include_paths.to(seq[string]), defines.to(seq[string]))
   close(fs)


proc get_root_node(h: PGraphHandle): PNode {.exportpy.} =
   result = h.graph.root


proc has_errors(n: PNode): bool {.exportpy.} =
   result = graph.ast.has_errors(n)


proc json(n: PNode): string {.exportpy.} =
   result = $(%n)


proc pretty(n: PNode): string {.exportpy.} =
   result = pretty(%n)
