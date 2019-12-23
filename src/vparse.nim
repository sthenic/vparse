import ./vparsepkg/parser
import ./vparsepkg/private/[cli, log]

import strutils
import streams
import times
import terminal
import json

const
   # Version information
   VERSION_STR = static_read("./vparsepkg/private/VERSION").strip()
   # Exit codes: negative values are errors.
   ESUCCESS = 0
   EINVAL = 1
   EFILE = 2
   EPARSE = 3

   STATIC_HELP_TEXT = static_read("./vparsepkg/private/CLI_HELP")

let HELP_TEXT = "vparse v" & VERSION_STR & "\n\n" & STATIC_HELP_TEXT

# Parse the arguments and options and return a CLI state object.
var cli_state: CLIState
try:
   cli_state = parse_cli()
except CLIValueError:
   quit(-EINVAL)

# Parse CLI object state.
if not cli_state.is_ok:
   # Invalid input combination (but otherwise correctly formatted arguments
   # and options).
   echo HELP_TEXT
   quit(-EINVAL)
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
   quit(-EINVAL)

var ofs: FileStream = nil
if len(cli_state.output_file) != 0:
   ofs = new_file_stream(cli_state.output_file, fmWrite)
   if ofs == nil:
      log.warning("Failed to open output file '$1' for writing.",
                  cli_state.output_file)
   else:
      log.info("Opened output file '$1'.", cli_state.output_file)

var p: Parser
for filename in cli_state.input_files:
   let fs = new_file_stream(filename, fmRead)
   if fs == nil:
      log.error("Failed to open '$1' for reading, skipping.", filename)
      continue

   let cache = new_ident_cache()
   open_parser(p, cache, filename, fs)
   log.info("Parsing source file '$1'", filename)

   let t_start = cpu_time()
   let root_node = parse_all(p)
   let t_diff_ms = (cpu_time() - t_start) * 1000

   if ofs != nil:
      if cli_state.json:
         ofs.write(%root_node)
      else:
         ofs.write(pretty(root_node))

   if cli_state.stdout:
      if cli_state.json:
         echo %root_node
      else:
         echo pretty(root_node)

   log.info("Parse completed in ", fgGreen, styleBright,
            format_float(t_diff_ms, ffDecimal, 1), " ms", resetStyle, ".")

   # TODO: Analyze errors and present a summary.

quit(ESUCCESS)
