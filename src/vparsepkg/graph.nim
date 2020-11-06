# Copyright (C) Marcus Eriksson 2020
#
# Description: This file implements the graph for a Verilog source tree.
# TODO: Describe an overview of the the implementation.

import streams
import tables
import os
import strutils

import ./parser
import ./location
export parser
export tables

type
   WalkStrategy* = enum
      WalkAll
      WalkDefined
      WalkUndefined

   Graph* = ref object
      modules*: Table[string, PNode]
      module_stack: seq[string]
      files_to_parse: seq[string]
      parsed_files: seq[string]
      cache*: IdentifierCache
      locations*: PLocations
      root*: PNode
      include_paths*: seq[string]
      external_defines*: seq[string]


const VERILOG_EXTENSIONS = [".v"]


proc new_graph*(cache: IdentifierCache): Graph =
   ## Create a new graph for a Verilog source tree.
   new result
   new result.locations
   init(result.locations)
   clear(result.modules)
   set_len(result.module_stack, 0)
   set_len(result.parsed_files, 0)
   set_len(result.files_to_parse, 0)
   set_len(result.include_paths, 0)
   set_len(result.external_defines, 0)
   result.cache = cache


iterator walk_verilog_files*(dir: string): string {.inline.} =
   ## Walk the verilog files in ``dir``, returning the full path of each match.
   for kind, path in walk_dir(dir):
      let (_, _, ext) = split_file(path)
      if kind == pcFile and ext in VERILOG_EXTENSIONS:
         yield path


proc find_all_verilog_files*(dir: string): seq[string] =
   for filename in walk_verilog_files(dir):
      add(result, filename)


proc find_all_verilog_files*(dirs: openarray[string]): seq[string] =
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


iterator walk_modules*(g: Graph, strategy: WalkStrategy = WalkAll):
      tuple[module: PNode, name, filename: string] =
   for name, module in g.modules:
      if is_nil(module):
         if strategy in {WalkAll, WalkUndefined}:
            yield (nil, name, "")
         else:
            continue
      else:
         if strategy in {WalkAll, WalkDefined}:
            let filename = g.locations.file_maps[module.loc.file - 1].filename
            yield (module, name, filename)
         else:
            continue


# Forward declaration of the local parse proc so we can perform recursive
# parsing when we look for submodule declarations.
proc parse(g: Graph, s: Stream, filename: string): PNode


proc cache_module_declaration*(g: Graph, name: string) =
   ## Attempt to cache the declaration of the module identified by ``name``.
   # First we check the cache for a hit. Otherwise, we check the source files
   # available on the include paths. We prioritize files with the same name as
   # the module we're searching for since there's a good chance we find the
   # declaration quickly that way.
   if has_key(g.modules, name):
      return

   for filename in walk_verilog_files(g, name):
      let fs = new_file_stream(filename)
      if is_nil(fs):
         close(fs)
         continue
      # Recursively call parse for the target module with the enclosing graph.
      discard parse(g, fs, filename)
      close(fs)
      if has_key(g.modules, name):
         return

   # If we got this far, we failed to find the declaration of the target module.
   # We mark this as a 'nil' entry in the table.
   g.modules[name] = nil


proc cache_submodule_declarations*(g: Graph, n: PNode) =
   ## Given a module declaration ``n`` in the context ``g``, go through the AST
   ## and attempt to cache the declarations of all modules instantiated within.
   ## The search stops when all instantiations have been processed. All
   ## declarations found along the way will be cached and available in the
   ## graph's ``modules`` table. These may or may not be all the modules
   ## reachable from the include paths.
   for inst in walk_module_instantiations(n):
      let id = find_first(inst, NkIdentifier)
      if not is_nil(id):
         cache_module_declaration(g, id.identifier.s)


proc parse(g: Graph, s: Stream, filename: string): PNode =
   ## Parse the Verilog source tree contained in the stream ``s``. Module
   ## declarations found within are added to the graph's ``modules`` table. The
   ## modules instantated within defines additional targets for the parser. The
   ## parsing is complete once the AST is fully defined from this entry point and
   ## downwards or the source files the include paths have been exhausted.
   var p: Parser
   open_parser(p, g.cache, s, absolute_path(filename), g.locations,
               g.include_paths, g.external_defines)
   result = parse_all(p)
   close_parser(p)

   # We have to do this in two steps since a source tree may contain multiple
   # module declarations that reference each other.
   for decl in walk_sons(result, NkModuleDecl):
      let id = find_first(decl, NkIdentifier)
      if is_nil(id):
         continue
      # TODO: Figure out conflicts in the table.
      g.modules[id.identifier.s] = decl

   for decl in walk_sons(result, NkModuleDecl):
      cache_submodule_declarations(g, decl)


proc parse*(g: Graph, s: Stream, filename: string, include_paths: openarray[string],
            external_defines: openarray[string]): PNode =
   ## Given an initialized graph ``g``, parse the Verilog source tree contained
   ## in the stream ``s``. The parser will attempt to look up any external
   ## objects, e.g. targets of an ``include`` directive, or declarations of
   ## modules instantiated within the source tree, by traversing the paths listed
   ## in ``include_paths``. A list of external defines may be provided in
   ## ``external_defines`` that are treated as if the preprocessor had processed
   ## each element with the ``define`` directive.
   g.include_paths = new_seq_of_cap[string](len(include_paths))
   for path in include_paths:
      add(g.include_paths, expand_tilde(path))

   # We always add the parent directory to the include path.
   let absolute_filename = absolute_path(filename)
   let absolute_parent_dir = parent_dir(absolute_filename)
   if absolute_parent_dir notin g.include_paths:
      add(g.include_paths, absolute_parent_dir)

   g.external_defines = new_seq_of_cap[string](len(external_defines))
   add(g.external_defines, external_defines)

   g.files_to_parse = find_all_verilog_files(g.include_paths)
   g.parsed_files = @[absolute_filename]

   g.root = parse(g, s, filename)
   result = g.root
