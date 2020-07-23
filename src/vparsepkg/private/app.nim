import ./cli
import ./log
import ../graph

import strutils
import streams
import times
import terminal
import json

const
   # Version information
   VERSION_STR = static_read("./VERSION").strip()
   # Exit codes: negative values are errors.
   ESUCCESS = 0
   EINVAL = -1
   EFILE = -2
   EPARSE = -3

   STATIC_HELP_TEXT = static_read("./CLI_HELP")

let HELP_TEXT = "vparse v" & VERSION_STR & "\n\n" & STATIC_HELP_TEXT

# Parse the arguments and options and return a CLI state object.
var cli_state: CliState
try:
   cli_state = parse_cli()
except CliValueError:
   quit(EINVAL)

# Parse CLI object state.
if not cli_state.is_ok:
   # Invalid input combination (but otherwise correctly formatted arguments
   # and options).
   echo HELP_TEXT
   quit(EINVAL)
elif cli_state.print_help:
   # Show help text and exit.
   echo HELP_TEXT
   quit(ESUCCESS)
elif cli_state.print_version:
   # Show version information and exit.
   echo VERSION_STR
   quit(ESUCCESS)

log.info("vparse v" & VERSION_STR)

if len(cli_state.input_files) == 0:
   log.error("No input files, aborting.")
   quit(EINVAL)

var ofs: FileStream = nil
if len(cli_state.output_file) != 0:
   ofs = new_file_stream(cli_state.output_file, fmWrite)
   if ofs == nil:
      log.warning("Failed to open output file '$1' for writing.",
                  cli_state.output_file)
   else:
      log.info("Opened output file '$1'.", cli_state.output_file)

var g: Graph
var exit_val = ESUCCESS
for filename in cli_state.input_files:
   let fs = new_file_stream(filename)
   if fs == nil:
      log.error("Failed to open '$1' for reading, skipping.", filename)
      continue

   let cache = new_ident_cache()
   log.info("Parsing source file '$1'", filename)
   let t_start = cpu_time()
   open_graph(g, cache, fs, filename, cli_state.include_paths, cli_state.defines)
   let t_diff_ms = (cpu_time() - t_start) * 1000
   let root_node = parse_all(g)

   if ofs != nil:
      if cli_state.json:
         if cli_state.pretty:
            ofs.write(pretty(%root_node))
         else:
            ofs.write($(%root_node))
      else:
         ofs.write(pretty(root_node))

   if cli_state.stdout:
      if cli_state.json:
         if cli_state.pretty:
            echo pretty(%root_node)
         else:
            echo $(%root_node)
      else:
         echo pretty(root_node)
         if cli_state.maps:
            echo "File maps\n---------"
            echo pretty(g.locations.file_maps)
            echo "Macro maps\n----------"
            echo pretty(g.locations.macro_maps)

   log.info("Parse completed in ", fgGreen, styleBright,
            format_float(t_diff_ms, ffDecimal, 1), " ms", resetStyle, ".")

   if has_errors(root_node):
      log.error("The AST contains errors.")
      exit_val = EPARSE
   else:
      log.info("No errors.\n")

   close_graph(g)
   close(fs)

quit(exit_val)