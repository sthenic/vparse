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
      # The immediately preceding comment at the define location.
      comment*: string
      # Location of the macro definition.
      define_loc*: Location
      # Location of the expansion point which created this map object.
      expansion_loc*: Location
      # Location pairs of the tokens in this macro.
      locations*: seq[LocationPair]

   FileMap* {.final.} = object
      # The full path of the file.
      filename*: string
      # If this file is the result of an `include, this field holds the location
      # of that directive.
      loc*: Location

   Locations* = ref TLocations
   TLocations* = object
      file_maps*: seq[FileMap]
      macro_maps*: seq[MacroMap]

const
   InvalidLocation* = Location(file: 0, line: 0, col: 0)


proc new_location*(file, line, col: int): Location =
   if line < int(high(uint16)):
      result.line = uint16(line)
   else:
      result.line = high(uint16)

   if col < int(high(int16)):
      result.col = int16(col)
   else:
      result.col = -1

   if file < int(high(int32)):
      result.file = int32(file)
   else:
      result.file = 0


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
defined at: $2
expansion at: $3
locations: $4
""", map.name, $map.define_loc, $map.expansion_loc, indent(pretty(map.locations), 2))


proc pretty*(maps: openarray[MacroMap]): string =
   for m in maps:
      add(result, pretty(m))


proc detailed_compare*(x, y: MacroMap) =
   if x.name != y.name:
      echo format("Name differs: $1 != $2\n", x.name, y.name)
      return

   const INDENT = 2
   if x.comment != y.comment:
      echo indent(format("($1) Comment differs: '$2' != '$3'\n ",
                         x.name, x.comment, y.comment), INDENT)

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


proc pretty*(map: FileMap): string =
   result = format("""
filename: '$1'
location: $2
""", map.filename, $map.loc)


proc pretty*(maps: openarray[FileMap]): string =
   for i, m in maps:
      let s = format("index: $1\n", i + 1)
      add(result, s & pretty(m) & "\n")


proc new_file_map*(filename: string, loc: Location): FileMap =
   result.filename = filename
   result.loc = loc


proc init*(locs: Locations) =
   locs.file_maps = new_seq_of_cap[FileMap](32)
   locs.macro_maps = new_seq_of_cap[MacroMap](64)


proc new_locations*(): Locations =
   new result
   init(result)


# FIXME: Maybe return int32 to match the 'file' member of Location.
proc add_file_map*(locs: Locations, file_map: FileMap): int =
   ## Add a file map to the file index and return its location in the index. If
   add(locs.file_maps, file_map)
   result = high(locs.file_maps) + 1


proc add_macro_map*(locs: Locations, macro_map: MacroMap) =
   add(locs.macro_maps, macro_map)


proc next_macro_map_index*(locs: Locations): int =
   result = -high(locs.macro_maps) - 2


proc to_physical*(locs: Locations, loc: Location): Location =
   ## Given a location database: ``locs``, translate the virtual
   ## location ``loc`` into a physical location.
   result = loc
   while true:
      if result.file > 0:
         break
      result = locs.macro_maps[-(result.file + 1)].locations[result.line].x


proc unroll_location*(locs: Locations, loc: var Location) =
   ## Given a location database: ``locs``, unroll the virtual
   ## (``loc.file < 0``) location ``loc`` to reach the corresponding
   ## virtual location that will appear in the AST. Unrolling is required
   ## for nested macros.
   for i, map in locs.macro_maps:
      for j, lpair in map.locations:
         if loc == lpair.x:
            loc = new_location(-(i + 1), j, 0)


proc in_bounds*(x, y: Location, len: int): bool =
   ## Provided that the two locations ``x`` and ``y``
   ## reside in the same file and on the same line,
   ## this proc returns true if ``x.col`` falls within
   ## the bounding box bounded by ``y.col`` and
   ## ``y.col + len``.
   result = x.file == y.file and x.line == y.line and
            x.col >= y.col and x.col <= (y.col + len - 1)


proc `<`*(x, y: Location): bool =
   result = x.file == y.file and (x.line < y.line or (x.line == y.line and x.col < y.col))


proc `>`*(x, y: Location): bool =
   result = x.file == y.file and (x.line > y.line or (x.line == y.line and x.col > y.col))


proc `>=`*(x, y: Location): bool =
   result = not (x < y)


proc `<=`*(x, y: Location): bool =
   result = not (x > y)
