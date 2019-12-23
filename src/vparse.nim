import ./vparsepkg/parser
import ./vparsepkg/private/[cli, log]

import strutils
import streams
import times
import terminal

when is_main_module:
   const
      # Version information
      VERSION_STR = static_read("./vparsepkg/private/VERSION").strip()
      # Exit codes: negative values are errors.
      ESUCCESS = 0
      EINVAL = 1
      EFILE = 2
      EPARSE = 3

      STATIC_HELP_TEXT = static_read("./vparsepkg/private/CLI_HELP")

   let HELP_TEXT = "Lins v" & VERSION_STR & "\n\n" & STATIC_HELP_TEXT

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

   var p: Parser
   for filename in cli_state.input_files:
      let fs = new_file_stream(filename, fmRead)
      let cache = new_ident_cache()
      open_parser(p, cache, filename, fs)
      let t_start = cpu_time()
      let root_node = parse_all(p)
      let t_diff_ms = (cpu_time() - t_start) * 1000

      if len(cli_state.output_file) == 0:
         echo pretty(root_node)

      log.info("Parsing completed in ", fgGreen, styleBright,
               format_float(t_diff_ms, ffDecimal, 1), " ms", resetStyle, ".")
