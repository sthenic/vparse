# This file implements a module cache which is leveraged by the graph module to
# speed up nagivating the module graph. Like the identifier cache, this is also
# heavily inspired by the Nim compiler.
# TODO: Describe the jist of the data structure: LRU cache for modules + hash
# table to allow operations indexing the modules using a filename.
import hashes
import strutils
import streams
import tables
import md5

import ./ast
import ./location

type
   PModule* = ref TModule
   TModule* {.final.} = object
      id: int
      next: PModule
      h: Hash
      name*: string
      filename*: string
      n*: PNode

   SourceFile* = ref object
      filename*: string
      checksum*: MD5Digest
      modules*: seq[PModule]
      root*: PNode

   ModuleCache* = ref object
      buckets: array[0..1024 * 2 - 1, PModule]
      count*: int
      source_files: Table[string, SourceFile]


proc `$`*(x: PModule): string =
   if is_nil(x):
      return "nil"

   result = format("($1) s: '$2', hash: $3", $x.id, x.name, $x.h)
   if is_nil(x.next):
      add(result, ", next: nil")
   else:
      add(result, format(", next: ($1)", $x.next.id))

   add(result, format(", filename: '$1'", x.filename))
   if is_nil(x.n):
      add(result, ", node: nil")
   else:
      add(result, format(", node: $1 @ $2", x.n.kind, x.n.loc))


proc local_hash(x: string): Hash =
   for c in x:
      result = result !& ord(c)
   result = !$result


proc get_module*(cache: ModuleCache, identifier: string, h: Hash): PModule =
   # Use the hash as our starting point to search the buckets, but we make sure
   # to stay within the boundaries.
   var idx = h and high(cache.buckets)
   result = cache.buckets[idx]

   var last: PModule = nil
   # Handle hash collisions.
   while not is_nil(result):
      if result.name == identifier:
         # We've found a perfect match in the table and we're ready to return
         # from this function. If we got here by searching a chain of hashed
         # identifiers we swap the position of the first element we encountered
         # and this one to make subsequent lookups faster.
         if not is_nil(last):
            last.next = result.next
            result.next = cache.buckets[idx]
            cache.buckets[idx] = result
         return
      # Keep searching the chain of modules for either a match or an empty
      # bucket to place our new identifier.
      last = result
      result = result.next

   # Initialize a new module.
   new result
   result.h = h
   result.name = identifier
   result.next = cache.buckets[idx]
   cache.buckets[idx] = result

   # Update the cache status.
   result.id = cache.count
   inc(cache.count)


template get_module*(cache: ModuleCache, identifier: string): PModule =
   get_module(cache, identifier, local_hash(identifier))


template get_source_file*(cache: ModuleCache, filename: string): SourceFile =
   ## Retrieve the source file object
   get_or_default(cache.source_files, filename, nil)


proc has_matching_checksum*(cache: ModuleCache, filename: string, checksum: MD5Digest): bool =
   ## Returns ``true`` if the .
   let source_file = get_source_file(cache, filename)
   if is_nil(source_file):
      result = false
   else:
      result = source_file.checksum == checksum


proc new_module_cache*(): ModuleCache =
   new result
   result.count = 0
   clear(result.source_files)


iterator walk_modules*(cache: ModuleCache): PModule {.inline.} =
   for module in cache.buckets:
      if not is_nil(module):
         yield module
         var cursor = module.next
         while not is_nil(cursor):
            yield cursor
            cursor = cursor.next


iterator walk_modules*(cache: ModuleCache, filename: string): PModule {.inline.} =
   let source_file = get_source_file(cache, filename)
   if not is_nil(source_file):
      for module in source_file.modules:
         yield module


proc add_source_file*(cache: ModuleCache, root: PNode, filename: string, checksum: MD5Digest) =
   # Add the source file and the module declarations contained in its source
   # text node ``root`` to the cache. The file's ``checksum`` is stored
   let source_file = SourceFile(filename: filename, checksum: checksum)
   for declaration in walk_sons(root, NkModuleDecl):
      let id = find_first(declaration, NkIdentifier)
      if not is_nil(id):
         let module = get_module(cache, id.identifier.s)
         # FIXME: How to handle duplicates, i.e. if module.n is not nil here
         # then there are two modules with the same name in this scope. We could
         # maintain another linked list of those? It would be nice to be able to
         # warn about the ambiguity.
         module.filename = filename
         module.n = declaration
         add(source_file.modules, module)
   cache.source_files[filename] = source_file


proc remove_source_file*(cache: ModuleCache, filename: string) =
   ## Remove the source file ``filename`` and its associated module declarations
   ## from the ``cache``. The proc does nothing if the file does not exist in the
   ## cache.
   let source_file = get_source_file(cache, filename)
   if is_nil(source_file):
      return

   # Once we have a matching source file object, we walk over its modules in
   # the cache. For each module, we begin by performing a lookup which serves
   # the purpose of moving the module to the front of its linked list. This
   # allows us to cleanly remove it from the cache since being at the front
   # of the list implies that no other element holds a reference to the
   # soon-to-be removed module in its '.next' field. All we have to do is
   # update the head of the linked list to point past the module if there's
   # anything to point to. Otherwise, we simply clear the bucket.
   for module in source_file.modules:
      let lmodule = get_module(cache, module.name)
      let idx = lmodule.h and high(cache.buckets)
      if not is_nil(lmodule.next):
         cache.buckets[idx] = lmodule.next
      else:
         cache.buckets[idx] = nil
      dec(cache.count)

   del(cache.source_files, filename)


proc compute_md5*(s: Stream): MD5Digest =
   ## Compute the MD5 checksum of the data in the input stream ``s``. The
   ## stream's position is reset to the beginning of the stream when this proc
   ## returns.
   const BLOCK_SIZE = 8192
   let data = cast[cstring](alloc(BLOCK_SIZE))
   var context: MD5Context
   md5_init(context)
   while not at_end(s):
      let bytes_read = read_data(s, data, BLOCK_SIZE)
      md5_update(context, data, bytes_read)
   dealloc(data)
   md5_final(context, result)
   set_position(s, 0)


proc compute_md5*(filename: string): MD5Digest =
   let fs = new_file_stream(filename)
   if not is_nil(fs):
      result = compute_md5(fs)
      close(fs)
