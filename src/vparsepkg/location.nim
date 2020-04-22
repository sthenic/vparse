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
      # The name of the macro.
      name*: string
      # Location of the macro.
      define_loc*: Location
      # Location of the expansion point which created this map object.
      expansion_loc*: Location
      # Location pairs of the tokens in this macro.
      locations*: seq[LocationPair]

   PLocations* = ref Locations
   Locations* = object
      files*: seq[string]
      macro_maps*: seq[MacroMap]


proc `$`*(l: Location): string =
   result = format("($1:$2:$3)", l.file, l.line, l.col + 1)


proc `%`*(l: Location): JsonNode =
   result = %*{"file": l.file, "line": l.line, "col": l.col + 1}


proc pretty*(lpairs: openarray[LocationPair]): string =
   result = "\n"
   for i, p in lpairs:
      add(result, format("""
$1: x: $2, y: $3
""", i, p.x, p.y))


proc pretty*(map: MacroMap): string =
   result = format("""
name: '$1'
expansion at: $2
locations: $3
""", map.name, $map.expansion_loc, indent(pretty(map.locations), 2))


proc pretty*(maps: openarray[MacroMap]): string =
   for m in maps:
      add(result, pretty(m))


proc detailed_compare*(x, y: MacroMap) =
   if x.name != y.name:
      echo format("Name differs: $1 != $2\n", x.name, y.name)
      return

   const INDENT = 2
   if x.define_loc != y.define_loc:
      echo indent(format("($1) Define location differs: $2 != $3\n",
                         x.name, x.define_loc, y.define_loc), INDENT)

   if x.expansion_loc != y.expansion_loc:
      echo indent(format("($1) Expansion location differs: $2 != $3\n",
                         x.name, x.expansion_loc, y.expansion_loc), INDENT)

   for i in 0..<min(len(x.locations), len(y.locations)):
      let xloc = x.locations[i]
      let yloc = y.locations[i]

      if xloc.x != yloc.x:
         echo indent(format("($1) Location $2 differs(x): $3 != $4", x.name, i,
                     xloc.x, yloc.x), INDENT)

      if xloc.y != yloc.y:
         echo indent(format("($1) Location $2 differs(y): $3 != $4", x.name, i,
                     xloc.y, yloc.y), INDENT)

   if len(x.locations) != len(y.locations):
      echo indent(format("($1) Location length differs: LHS($2) != RHS($3)",
                  x.name, len(x.locations), len(y.locations)), INDENT)


proc detailed_compare*(x, y: openarray[MacroMap]) =
   for i in 0..<min(len(x), len(y)):
      detailed_compare(x[i], y[i])

   if len(x) != len(y):
      echo format("Length differs: LHS($1) != RHS($2)", len(x), len(y))


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
