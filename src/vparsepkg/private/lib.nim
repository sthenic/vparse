import ../graph
import streams

type
   PGraphHandle = ptr GraphHandle
   GraphHandle = object
      graph: Graph
      cache: IdentifierCache
      # Stores to allow the library to own all memory.
      # The memory is freed in vparse_close_graph().
      contexts: seq[PAstContext]
      context_items: seq[PAstContextItem]
      node_seqs: seq[ref seq[PNode]]


const
   EOK = cint(0)
   EINVAL = cint(-1)
   EIO = cint(-2)


# NimMain() needs to be called in order to set up the GC. The
# function gets embedded into the library when its built. We
# provide an alias for that function which makes more sense
# to ask the user to call (in the context of this library).
proc nim_main {.cdecl, importc: "NimMain", dynlib: "libvparse.so".}
proc vparse_init() {.cdecl, exportc, dynlib.} = nim_main()


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
   set_len(handle.contexts, 0)
   set_len(handle.context_items, 0)
   set_len(handle.node_seqs, 0)
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
      reset(h.node_seqs)
      reset(h.contexts)
      reset(h.context_items)
      reset(h.cache)
      reset(h.graph)
      dealloc(h)


proc vparse_ast_print(h: PGraphHandle): cint {.cdecl, exportc, dynlib.} =
   if is_nil(h):
      return EINVAL

   echo pretty(h.graph.root_node)
   result = EOK


proc vparse_ast_has_errors(h: PGraphHandle): cint {.cdecl, exportc, dynlib.} =
   if is_nil(h):
      return EINVAL

   result = cint(has_errors(h.graph.root_node))


proc vparse_get_identifier(n: PNode, identifier: ptr cstring): cint {.cdecl, exportc, dynlib.} =
   if is_nil(n):
      return EINVAL
   if n.kind notin IdentifierTypes:
      return EINVAL

   identifier[] = n.identifier.s
   result = EOK


proc vparse_get_location(n: PNode, file, line, col: ptr cint): cint {.cdecl, exportc, dynlib.} =
   if is_nil(n):
      return EINVAL
   if not is_nil(file):
      file[] = n.loc.file
   if not is_nil(line):
      line[] = cint(n.loc.line)
   if not is_nil(col):
      col[] = n.loc.col


proc vparse_find_identifier(h: PGraphHandle, line, col, added_length: cint,
                            n: ptr PNode, c: ptr PAstContext): cint {.cdecl, exportc, dynlib.} =
   if is_nil(h) or is_nil(n):
      return EINVAL

   var context = new AstContext
   let loc = new_location(1, line, col)
   n[] = find_identifier_physical(h.graph.root_node, h.graph.locations, loc, context[],
                                  added_length)
   if not is_nil(c):
      add(h.contexts, context)
      c[] = context
   result = EOK


proc vparse_find_declaration(h: PGraphHandle,
                             context: PAstContext, identifier: PNode,
                             select_identifier: cint,
                             declaration: ptr PNode,
                             declaration_context: ptr PAstContextItem): cint {.cdecl, exportc, dynlib.} =
   if is_nil(context) or is_nil(identifier) or is_nil(declaration):
      return EINVAL
   if identifier.kind notin IdentifierTypes:
      return EINVAL

   # Create a new traced reference of an AST context item.
   var result_context = new AstContextItem
   (declaration[], result_context[]) = find_declaration(context[], identifier.identifier,
                                                        bool(select_identifier))
   if not is_nil(declaration_context):
      add(h.context_items, result_context)
      declaration_context[] = result_context
   result = EOK


proc vparse_find_all_declarations(h: PGraphHandle,
                                  select_identifiers: cint,
                                  declarations: ptr ptr PNode,
                                  declarations_len: ptr csize_t): cint {.cdecl, exportc, dynlib.} =
   if is_nil(h) or is_nil(declarations) or is_nil(declarations_len):
      return EINVAL

   let d = new seq[PNode]
   d[] = find_all_declarations(h.graph.root_node, bool(select_identifiers))
   add(h.node_seqs, d)
   declarations[] = unsafe_addr(d[0])
   declarations_len[] = csize_t(len(d[]))
   result = EOK


proc vparse_find_references(h: PGraphHandle, identifier: PNode,
                            references: ptr ptr PNode,
                            references_len: ptr csize_t): cint {.cdecl, exportc, dynlib.} =
   if is_nil(h) or is_nil(identifier) or is_nil(references) or is_nil(references_len):
      return EINVAL
   if identifier.kind notin IdentifierTypes:
      return EINVAL

   let r = new seq[PNode]
   r[] = find_references(h.graph.root_node, identifier.identifier)
   add(h.node_seqs, r)
   references[] = unsafe_addr(r[0])
   references_len[] = csize_t(len(r[]))
   result = EOK
