# Identifier handling (heavily influenced by the Nim compiler)

import hashes
import ./special_words

type
   PIdentifier* = ref TIdentifier
   TIdentifier* = object of RootObj
      id*: int
      s*: string
      next*: PIdentifier
      h*: Hash

   IdentifierCache* = ref object
      buckets: array[0..4096 * 2 - 1, PIdentifier]
      nof_identifiers: int


proc `$`*(x: PIdentifier): string =
   echo "Identifier (", x.id, ")"
   echo "  s: ", x.s
   echo "  hash: ", x.h
   echo "  next (id): ", if x.next == nil: "nil" else: $x.next.id


proc get_identifier*(ic: IdentifierCache, identifier: cstring,
                     length: int, h: Hash): PIdentifier =
   # Use the hash as our starting point to search the buckets, but keep within
   # the bucket boundaries.
   var idx = h and high(ic.buckets)
   result = ic.buckets[idx]

   var last: PIdentifier = nil
   # Handle hash collisions.
   while result != nil:
      if result.s == identifier:
         # We've found a perfect match in the table and we're ready to return
         # from this function. If we got here by searching a chain of hashed
         # identifiers we swap the position of the first element we encountered
         # and this one to make subsequent lookups faster.
         if last != nil:
            last.next = result.next
            result.next = ic.buckets[idx]
            ic.buckets[idx] = result
         return
      # Keep searching the chain of identifiers for either a match or an empty
      # bucket to place our new identifier.
      last = result
      result = result.next

   # Initialize a new identifier.
   new(result)
   result.h = h
   result.s = new_string(length)
   for i in 0..<length:
      result.s[i] = identifier[i]
   result.next = ic.buckets[idx]
   ic.buckets[idx] = result

   # Update the cache status.
   result.id = ic.nof_identifiers
   inc(ic.nof_identifiers)


proc get_identifier*(ic: IdentifierCache, identifier: string): PIdentifier =
   result = get_identifier(ic, cstring(identifier), len(identifier),
                           hash(identifier))


proc get_identifier*(ic: IdentifierCache, identifier: string,
                     h: Hash): PIdentifier =
   result = get_identifier(ic, cstring(identifier), len(identifier), h)


proc new_ident_cache*(): IdentifierCache =
   # Create a new identifier cache. which we initialize with the reserved
   # keywords of the language. It is crucial that the keywords are ordered
   # in sync with the corresponding token enumeration in the lexer since
   # the cache id is used for token lookup.
   result = IdentifierCache()
   result.nof_identifiers = 0
   for word in SpecialWords:
      discard result.get_identifier(word)
