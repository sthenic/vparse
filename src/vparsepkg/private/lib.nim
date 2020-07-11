import ../graph
import streams

type
   PGraphHandle = ptr GraphHandle
   GraphHandle = object
      graph: Graph
      messages: seq[string]
      cache: IdentifierCache


const
   EOK = cint(0)
   EINVAL = cint(-1)
   EIO = cint(-2)


proc vparse_open_graph(filename: cstring,
                       include_paths: cstringarray, include_path_len: csize_t,
                       defines: cstringarray, defines_len: csize_t,
                       h: ptr PGraphHandle): cint {.cdecl, exportc, dynlib.} =
   if is_nil(h):
      return EINVAL

   let include_paths_seq =
      if not is_nil(include_paths):
         cstringarray_to_seq(include_paths, include_path_len)
      else:
         @[]

   let defines_seq =
      if not is_nil(defines):
         cstringarray_to_seq(defines, defines_len)
      else:
         @[]

   var handle = cast[PGraphHandle](alloc0(sizeof(GraphHandle)))
   set_len(handle.messages, 0)
   handle.cache = new_ident_cache()
   let fs = new_file_stream($filename)
   if is_nil(fs):
      return EIO

   open_graph(handle.graph, handle.cache, fs, $filename, include_paths_seq, defines_seq)
   close(fs)
   h[] = handle
   result = EOK


proc vparse_close_graph(h: PGraphHandle) {.cdecl, exportc, dynlib.} =
   if not is_nil(h):
      close_graph(h.graph)
      reset(h.graph)
      reset(h.messages)
      reset(h.cache)
      dealloc(h)


proc vparse_print_root(h: GraphHandle): cint {.cdecl, exportc, dynlib.} =
   echo pretty(h.graph.root_node)
   result = EOK
