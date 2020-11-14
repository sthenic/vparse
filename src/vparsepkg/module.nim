# This file implements a module cache which is leveraged by the graph module to
# speed up nagivating the module graph. Like the identifier cache, this is also
# heavily inspired by the Nim compiler.
import hashes
import strutils
import ./ast
import ./location

type
   PModule* = ref TModule
   TModule* {.final.} = object
      id*: int
      s*: string
      next*: PModule
      h*: Hash
      filename*: string
      n*: PNode

   ModuleCache* = ref object
      buckets: array[0..1024 * 2 - 1, PModule]
      nof_modules: int


proc `$`*(x: PModule): string =
   if is_nil(x):
      return "nil"

   result = format("($1) s: '$2', hash: $3", $x.id, x.s, $x.h)
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
   # Use the hash as our starting point to search to buckets, but we stay within
   # the bucket boundaries.
   var idx = h and high(cache.buckets)
   result = cache.buckets[idx]

   var last: PModule = nil
   # Handle hash collisions.
   while not is_nil(result):
      if result.s == identifier:
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
   result.s = identifier
   result.next = cache.buckets[idx]
   cache.buckets[idx] = result

   # Update the cache status.
   result.id = cache.nof_modules
   inc(cache.nof_modules)


template get_module*(cache: ModuleCache, identifier: string): PModule =
   get_module(cache, identifier, local_hash(identifier))


proc new_module_cache*(): ModuleCache =
   new result
   result.nof_modules = 0


iterator walk_modules*(cache: ModuleCache): PModule {.inline.} =
   for module in cache.buckets:
      if not is_nil(module):
         yield module


iterator walk_modules*(cache: ModuleCache, filename: string): PModule {.inline.} =
   for module in cache.buckets:
      if module.filename == filename:
         yield(module)


proc add_modules*(cache: ModuleCache, root: PNode, filename: string) =
   for declaration in walk_sons(root, NkModuleDecl):
      let id = find_first(declaration, NkIdentifier)
      if not is_nil(id):
         let module = get_module(cache, id.identifier.s)
         module.filename = filename
         module.n = declaration


proc remove_modules*(cache: ModuleCache, filename: string) =
   for module in cache.buckets:
      if is_nil(module) or module.filename != filename:
         continue

      # Once we have a matching module to remove, we begin by perform a lookup
      # which serves the purpose of moving the module to the front of its linked
      # list. This allows us to cleanly remove it from the cache since being at
      # the front of the list implies that no other element holds a reference to
      # the soon-to-be removed module in its '.next' field. All we have to do is
      # update the head of the linked list to point past the module.
      let lmodule = get_module(cache, module.s)
      if not is_nil(lmodule.next):
         let idx = lmodule.h and high(cache.buckets)
         cache.buckets[idx] = lmodule.next

      dec(cache.nof_modules)
