import terminal
import parseopt
import strutils
import os

import ./log

type
   CLIValueError* = object of Exception
   CLIState* = object
      has_arguments*: bool
      input_from_stdin*: bool
      is_ok*: bool
      print_help*: bool
      print_version*: bool
      json*: bool
      pretty*: bool
      stdout*: bool
      input_files*: seq[string]
      output_file*: string
      include_paths*: seq[string]

proc parse_cli*(): CLIState =
   var p = init_opt_parser()
   for kind, key, val in p.getopt():
      case kind:
      of cmdArgument:
         var added_file = false
         result.has_arguments = true
         result.is_ok = true

         for file in walk_files(key):
            add(result.input_files, file)
            added_file = true

         if not added_file:
            log.warning("Failed to find any files matching the " &
                        "pattern '$1'.", key)

      of cmdLongOption, cmdShortOption:
         case key:
         of "help", "h":
            result.print_help = true
            result.is_ok = true
         of "version", "v":
            result.print_version = true
            result.is_ok = true
         of "output", "o":
            if val == "":
               log.abort(CLIValueError, "Option --output/-o expects a filename.")
            result.output_file = val
         of "pretty":
            result.pretty = true
         of "stdout":
            result.stdout = true
         of "json":
            result.json = true
         of "I":
            if val == "":
               log.abort(CLIValueError, "Option -I expects a path.")
            add(result.include_paths, val)
         else:
            log.abort(CLIValueError, "Unknown option '$1'.", key)

      of cmdEnd:
         log.abort(CLIValueError, "Failed to parse options and arguments " &
                  "This should not have happened.")
