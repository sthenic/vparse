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
      nof_identifiers*: int


proc `$`*(x: PIdentifier): string =
   result = "(" & $x.id & ")" & " s: '" & x.s & "' hash: " & $x.h & " next: "
   if x.next == nil:
      add(result, "nil")
   else:
      add(result, "(" & $x.next.id & ")")

# We have to define our own hashing of strings since the one offered for strings
# in the stdlib does not yield the same result.
proc local_hash(x: string): Hash =
   for c in x:
      result = result !& ord(c)
   result = !$result


# We have to define our own string comparison for the case where b is located
# directly in the raw file buffer. This implementation is borrowed directly
# from the Nim compiler's implementation of identifiers.
proc cmp_exact(a, b: cstring, blen: int): int =
   var i = 0
   var j = 0
   result = 1
   while j < blen:
      var aa = a[i]
      var bb = b[j]
      result = ord(aa) - ord(bb)
      if (result != 0) or (aa == '\0'):
         break
      inc(i)
      inc(j)
   if result == 0:
      if a[i] != '\0':
         result = 1


proc get_identifier*(ic: IdentifierCache, identifier: cstring,
                     length: int, h: Hash): PIdentifier =
   # Use the hash as our starting point to search the buckets, but keep within
   # the bucket boundaries.
   var idx = h and high(ic.buckets)
   result = ic.buckets[idx]

   var last: PIdentifier = nil
   # Handle hash collisions.
   while result != nil:
      if cmp_exact(cstring(result.s), identifier, length) == 0:
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
                           local_hash(identifier))


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
