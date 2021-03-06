# Copyright (C) Marcus Eriksson 2020
#
# Description: This file implements the graph for a Verilog source tree.
# TODO: Describe an overview of the the implementation.

import streams
import os
import strutils
import md5

import ./parser
import ./module
import ./private/log

export parser
export module

when defined(trace):
   const
      TRACE_MSG_MATCH = "      [!] Skipping '$1' since the checksums match."
      TRACE_MSG_CLEAR = "      [!] Clearing modules from cache for '$1' since the checksums do not match."
      TRACE_MSG_FOUND_ALREADY_PARSED = "      [✓] Found '$1' in cache (already parsed)."
      TRACE_MSG_FOUND_MATCH = "      [✓] Found '$1' in cache (checksum match)."
      TRACE_MSG_FOUND_AFTER_PARSE = "      [✓] Found '$1' after parse."
      TRACE_MSG_NOT_FOUND = "      [✗] Failed to find '$1'."

type
   WalkStrategy* = enum
      WalkAll
      WalkDefined
      WalkUndefined

   Graph* = ref object
      files_to_parse: seq[string]
      parsed_files: seq[string]
      identifier_cache*: IdentifierCache
      module_cache*: ModuleCache
      locations*: Locations
      root*: PNode
      include_paths*: seq[string]
      external_defines*: seq[string]


const VERILOG_EXTENSIONS = [".v"]


proc new_graph*(identifier_cache: IdentifierCache, module_cache: ModuleCache, locations: Locations): Graph =
   ## Create a new graph for a Verilog source tree.
   new result
   set_len(result.parsed_files, 0)
   set_len(result.files_to_parse, 0)
   set_len(result.include_paths, 0)
   set_len(result.external_defines, 0)
   result.identifier_cache = identifier_cache
   result.module_cache = module_cache
   result.locations = locations


template new_graph*(cache: IdentifierCache): Graph =
   ## Create a new graph for a Verilog source tree.
   new_graph(cache, new_module_cache(), new_locations())


proc filter_module(module: PModule, include_paths: openarray[string]): bool =
   ## Returns ``true`` if the module is reachable from the ``include_paths``.
   const RECURSIVE_TAIL = DirSep & "**"
   result = false
   let (module_directory, _, _) = split_file(module.filename)
   for path in include_paths:
      log.debug("Checking path '$1'.", path)
      if ends_with(path, RECURSIVE_TAIL):
         var head = path
         remove_suffix(head, RECURSIVE_TAIL)
         if starts_with(module_directory, head):
            log.debug("Recursive match, returning.")
            return true
      elif path == module_directory:
         log.debug("Explicit match.")
         return true


proc get_module*(g: Graph, name: string): PModule =
   ## Attempt to get the from the graph's module cache. This function will return
   ## ``nil`` if the module cannot be found.
   # For efficiency reasons (speed and memory consumption), we prepare for the
   # fact that a module cache can be shared between many module graphs, all with
   # different include paths. This means that we may be able to retrieve a
   # module object from get_module() that this graph actually shouldn't be aware
   # of. To fix this, we check the module's source file path against the graph's
   # include paths. If there are no include paths, we pass on the module object.
   result = nil
   let module = get_module(g.module_cache, name)
   if not is_nil(module.n) and filter_module(module, g.include_paths):
      result = module


iterator walk_verilog_files*(dirs: openarray[string]): string {.inline.} =
   ## Walk the Verilog files (``*.v``) in the directories ``dirs``, returning the
   ## full path of each match. A recursive search of the full directory tree will
   ## be performed if the path ends with ``**``. Overlapping directories are
   ## supported, each file is only yielded once.
   var seen_paths = new_seq_of_cap[string](64)
   for dir in dirs:
      if ends_with(dir, "**"):
         var head = dir
         remove_suffix(head, "**")
         for path in walk_dir_rec(head, yield_filter = {pcFile}):
            let (_, _, ext) = split_file(path)
            if ext in VERILOG_EXTENSIONS and path notin seen_paths:
               add(seen_paths, path)
               yield path
      else:
         for kind, path in walk_dir(dir):
            let (_, _, ext) = split_file(path)
            if kind == pcFile and ext in VERILOG_EXTENSIONS and path notin seen_paths:
               add(seen_paths, path)
               yield path


template walk_verilog_files*(dir: string): untyped =
   ## Walk the Verilog files (``*.v``) in the directory ``dir``, returning the
   ## full path of each match.
   walk_verilog_files([dir])


proc find_all_verilog_files*(dir: string): seq[string] =
   ## Find all the Verilog files (``*.v``) in the directory ``dir``. The result
   ## will contain the full path of each match.
   for filename in walk_verilog_files(dir):
      add(result, filename)


proc find_all_verilog_files*(dirs: openarray[string]): seq[string] =
   ## Find all the Verilog files (``*.v``) in the directories ``dirs``. See the
   ## description from the iterator ``walk_verilog_files()``.
   for dir in dirs:
      add(result, find_all_verilog_files(dir))


iterator walk_verilog_files(g: Graph, pattern: string): string {.inline.} =
   ## Walk the remaining Verilog files, prioritizing paths matching the
   ## ``pattern``. A test with the lowercase version of the pattern is performed
   ## if the pattern yields no match as-is.
   var remainder: seq[string]

   for path in g.files_to_parse:
      if path in g.parsed_files:
         continue

      let (_, filename, _) = split_file(path)
      if contains(filename, pattern) or contains(filename, to_lower_ascii(pattern)):
         add(g.parsed_files, path)
         yield path
      else:
         add(remainder, path)

   for path in remainder:
      # We have to double-check against the list of parsed files since an
      # earlier yield may have caused a recursive parse that handled the path
      # we're about to yield.
      if path in g.parsed_files:
         continue
      add(g.parsed_files, path)
      yield path


iterator walk_modules*(g: Graph, strategy: WalkStrategy = WalkDefined): PModule =
   for module in walk_modules(g.module_cache):
      if is_nil(module.n):
         if strategy in {WalkAll, WalkUndefined}:
            yield module
      elif strategy in {WalkAll, WalkDefined} and filter_module(module, g.include_paths):
         yield module


iterator walk_modules*(g: Graph, filename: string): PModule =
   for module in walk_modules(g.module_cache, filename):
      if filter_module(module, g.include_paths):
         yield module


# Forward declaration of the local parse proc so we can perform recursive
# parsing when we look for submodule declarations.
proc parse(g: Graph, s: Stream, filename: string, checksum: MD5Digest,
           cache_submodules: bool = true): PNode


proc cache_module_declaration_helper(g: Graph, filename: string): bool =
   ## Helper proc to parse the file with path ``filename``, adding the modules it
   ## declares to the cache. If ther file's checksum matches the one on record,
   ## the parsing is skipped and the return value is set to ``true``. Otherwise,
   ## the return value is set to ``false``.
   result = false
   let fs = new_file_stream(filename)
   if is_nil(fs):
      return

   let checksum = compute_md5(fs)
   if has_matching_checksum(g.module_cache, filename, checksum):
      when defined(trace):
         log.debug(TRACE_MSG_MATCH, filename)
      close(fs)
      return true
   else:
      when defined(trace):
         log.debug(TRACE_MSG_CLEAR, filename)
      remove_source_file(g.module_cache, filename)

   # Recursively call parse for the target module with the enclosing graph.
   # If the parse caused the module declaration to appear in the cache, we
   # make an early exit.
   discard parse(g, fs, filename, checksum)
   close(fs)


proc cache_module_declaration*(g: Graph, name: string) =
   ## Attempt to cache the declaration of the module identified by ``name``.
   # We begin by checking the cache for a hit. However, if we do find an entry,
   # we have to verify that its source file either:
   #
   #   - is a file we've already parsed; or
   #   - that the MD5 checksum matches the one on register before we can
   #     confidently make an early return.
   #
   # If there's an MD5 mismatch, we clear the associated modules from the cache
   # and use same source file as a starting point to get the latest module
   # declaration. If we cannot find it by reparsing the original source file
   # (our best guess), then we expand the search and start walking through the
   # remaining source files on the include path. The iterator
   # walk_verilog_files() is somewhat clever in that it prioritizes files with
   # the same name as the module we're searching for since there's a good chance
   # we find the declaration quickly that way.
   let cached_module = get_module(g.module_cache, name)
   if not is_nil(cached_module):
      if cached_module.filename in g.parsed_files:
         when defined(trace):
            log.debug(TRACE_MSG_FOUND_ALREADY_PARSED, name)
         return
      elif cache_module_declaration_helper(g, cached_module.filename):
         when defined(trace):
            log.debug(TRACE_MSG_FOUND_MATCH, name)
         return

   for filename in walk_verilog_files(g, name):
      if cache_module_declaration_helper(g, filename):
         continue
      elif not is_nil(get_module(g, name)):
         # If the parsing caused the target module declaration to appear in the
         # cache, we make an early exit.
         when defined(trace):
            log.debug(TRACE_MSG_FOUND_AFTER_PARSE, name)
         return

   when defined(trace):
      log.debug(TRACE_MSG_NOT_FOUND, name)


proc cache_submodule_declarations*(g: Graph, n: PNode) =
   ## Given a module declaration ``n`` in the context ``g``, go through the AST
   ## and attempt to cache the declarations of all modules instantiated within.
   ## The search stops when all instantiations have been processed. All module
   ## declarations found along the way will be available in the graph's module
   ## cache. These may or may not be all the modules reachable from the include
   ## paths.
   for inst in walk_module_instantiations(n):
      let id = find_first(inst, NkIdentifier)
      if not is_nil(id):
         when defined(trace):
            log.debug("    Attempting to cache declaration of module '$1'.", id.identifier.s)
         cache_module_declaration(g, id.identifier.s)


proc parse(g: Graph, s: Stream, filename: string, checksum: MD5Digest,
           cache_submodules: bool = true): PNode =
   ## Parse the Verilog source tree contained in the stream ``s``. Module
   ## declarations found within are added to the graph's ``modules`` table. If
   ## ``cache_submodules`` is ``true`` (the default), modules instantated within
   ## defines additional targets for the parser. The parsing is complete once the
   ## AST is fully defined from this entry point and downwards or the source
   ## files the include paths have been exhausted.
   when defined(trace):
      log.debug("Parsing file '$1'.", filename)
   var p: Parser
   let afilename = absolute_path(filename)
   open_parser(p, g.identifier_cache, s, afilename, g.locations, g.include_paths, g.external_defines)
   result = parse_all(p)
   close_parser(p)

   # We have to do this in two steps since a source tree may contain multiple
   # module declarations that reference each other.
   add_source_file(g.module_cache, result, afilename, checksum)
   when defined(trace):
      log.debug("Cache contains $1 modules after parse.", $g.module_cache.count)

   if cache_submodules:
      for decl in walk_sons(result, NkModuleDecl):
         cache_submodule_declarations(g, decl)


proc parse*(g: Graph, s: Stream, filename: string, include_paths: openarray[string],
            external_defines: openarray[string], cache_submodules: bool = true): PNode =
   ## Given an initialized graph ``g``, parse the Verilog source tree contained
   ## in the stream ``s``. The parser will attempt to look up any external
   ## objects, e.g. targets of an ``include`` directive, or declarations of
   ## modules instantiated within the source tree, by traversing the paths listed
   ## in ``include_paths``. A list of external defines may be provided in
   ## ``external_defines`` that are treated as if the preprocessor had processed
   ## each element with the ``define`` directive.
   g.include_paths = new_seq_of_cap[string](len(include_paths))
   for path in include_paths:
      add(g.include_paths, absolute_path(normalized_path(expand_tilde(path))))

   # We always add the parent directory to the include path.
   let absolute_filename = absolute_path(filename)
   let absolute_parent_dir = parent_dir(absolute_filename)
   if absolute_parent_dir notin g.include_paths:
      add(g.include_paths, absolute_parent_dir)

   g.external_defines = new_seq_of_cap[string](len(external_defines))
   add(g.external_defines, external_defines)

   g.files_to_parse = find_all_verilog_files(g.include_paths)
   g.parsed_files = @[absolute_filename]

   # Clear the module declarations previously contained in the source file
   # before proceeding with the parse.
   remove_source_file(g.module_cache, absolute_filename)
   g.root = parse(g, s, absolute_filename, compute_md5(s), cache_submodules)
   result = g.root


proc find_module_port_declaration*(g: Graph, module_id, port_id: PIdentifier):
      tuple[declaration, identifier: PNode, filename: string] =
   ## Given a parsed module graph ``g``, find the declaration of the module port
   ## ``port_id`` that belong to the module ``module_id``. The return value is a
   ## tuple containing the declaration node, the matching identifier node within
   ## this declaration and the filename in which this declaration appears. If the
   ## search fails, the declaration node is set to ``nil``.
   result = (nil, nil, "")
   let module = get_module(g, module_id.s)
   if is_nil(module):
      return

   for (declaration, id) in walk_ports(module.n):
      if id.identifier.s == port_id.s:
         return (declaration, id, module.filename)


proc find_module_parameter_declaration*(g: Graph, module_id, parameter_id: PIdentifier):
      tuple[declaration, identifier: PNode, filename: string] =
   ## Given a parsed module graph ``g``, find the declaration of the module
   ## parameter ``parameter_id`` that belongs to the module ``module_id``. The
   ## return value is a tuple containing the declaration node, the matching
   ## identifier node within this declaration and the filename in which this
   ## declaration appears. If the search fails, the declaration node is set to
   ## ``nil``.
   result = (nil, nil, "")
   let module = get_module(g, module_id.s)
   if is_nil(module):
      return

   for (declaration, id) in find_all_parameters(module.n):
      if id.identifier.s == parameter_id.s:
         return (declaration, id, module.filename)


proc find_external_declaration*(g: Graph, context: AstContext, identifier: PIdentifier):
      tuple[declaration, identifier: PNode, filename: string] =
   ## Given a parsed module graph ``g``, find the external declaration of the
   ## ``identifier`` that exists in the provided ``context``. The return value is
   ## a tuple containing the declaration node, the matching identifier node within
   ## this declaration and the filename in which this declaration appears. If the
   ## search fails, the declaration node is set to ``nil``.
   result = (nil, nil, "")
   if not is_external_identifier(context):
      return

   case context[^1].n.kind
   of NkModuleInstantiation:
      let module = get_module(g, identifier.s)
      if not is_nil(module):
         let id = find_first(module.n, NkIdentifier)
         result = (module.n, id, module.filename)

   of NkNamedPortConnection:
      let module_id = find_first(context[^3].n, NkIdentifier)
      if not is_nil(module_id):
         result = find_module_port_declaration(g, module_id.identifier, identifier)

   of NkNamedParameterAssignment:
      let module_id = find_first(context[^3].n, NkIdentifier)
      if not is_nil(module_id):
         result = find_module_parameter_declaration(g, module_id.identifier, identifier)

   else:
      discard
