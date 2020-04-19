import strutils
import json

type
   # This data structure encodes the physical or virtual location of a token
   # in the source code. It is exactly 64-bits.
   Location* = object
      line*: uint16
      col*: int16
      file*: int32

   LocationPair* = tuple[x, y: Location]

   MacroMap* = object
      # Location of the macro expansion point.
      expansion_loc*: Location
      # Location pairs of the tokens.
      locations*: seq[LocationPair]

   PLocations* = ref Locations
   Locations* = object
      files*: seq[string]
      macro_maps*: seq[MacroMap]


proc `$`*(l: Location): string =
   result = format("($1:$2:$3)", l.file, l.line, l.col + 1)


proc `%`*(l: Location): JsonNode =
   result = %*{"file": l.file, "line": l.line, "col": l.col + 1}


proc init*(locs: PLocations) =
   locs.files = new_seq_of_cap[string](32)
   locs.macro_maps = new_seq_of_cap[MacroMap](64)


# FIXME: Maybe return int32 to match the 'file' member of Location.
proc add_to_index*(locs: PLocations, filename: string): int =
   ## Add a file to the graph's file index and return its index.
   let idx = find(locs.files, filename)
   if idx < 0:
      add(locs.files, filename)
      result = high(locs.files) + 1
   else:
      result = idx + 1


proc add_macro_map*(locs: PLocations, macro_map: MacroMap) =
   add(locs.macro_maps, macro_map)


proc next_macro_map_index*(locs: PLocations): int =
   result = -high(locs.macro_maps) - 2
