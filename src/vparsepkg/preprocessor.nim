# Copyright (C) Marcus Eriksson 2020
#
# Description: This file implements a preprocessor for Verilog 2005.
# TODO: Describe an overview of the the implementation.

import streams
import lexbase
import tables
import strutils

import ./lexer

type
   PreprocessedText* = object
      text*: string
      defines*: Table[string, Define]

   Define* = object
      name*: string
      parameters*: seq[string]
      text*: string

   Directive = object
      identifier: string

   PreprocessorError* = object of ValueError

   Preprocessor* = object of BaseLexer
      filename*: string
      include_paths: seq[string]
      text: PreprocessedText


proc new_preprocessor_error(msg: string, args: varargs[string, `$`]):
      ref PreprocessorError =
   new result
   result.msg = format(msg, args)


proc init(t: var PreprocessedText) =
   set_len(t.text, 0)
   t.defines = init_table[string, Define](32)


proc init(def: var Define) =
   set_len(def.name, 0)
   set_len(def.parameters, 0)
   set_len(def.text, 0)


proc add(p: var PreprocessedText, s: string) =
   add(p.text, s)


proc init(dir: var Directive) =
   set_len(dir.identifier, 0)


proc open_preprocessor(p: var Preprocessor, filename: string,
                       include_paths: openarray[string], s: Stream) =
   lexbase.open(p, s)
   p.filename = filename
   set_len(p.include_paths, len(include_paths))
   add(p.include_paths, include_paths)
   init(p.text)


proc close_preprocessor(p: var Preprocessor) =
   lexbase.close(p)


proc handle_crlf(p: var Preprocessor, pos: int): int =
   # Refill buffer at end-of-line characters.
   case p.buf[pos]
   of '\c':
      result = lexbase.handle_cr(p, pos)
   of '\L':
      result = lexbase.handle_lf(p, pos)
   else:
      result = pos


proc skip(p: var Preprocessor, pos: int, add: bool = false): int =
   result = pos
   while p.buf[result] in SpaceChars:
      if add:
         add(p.text, $p.buf[pos])
      inc(result)


proc skip_to_newline_or_eof(p: var Preprocessor, pos: int, add: bool = false): int =
   result = pos
   while p.buf[result] notin lexbase.NewLines + {lexbase.EndOfFile}:
      inc(result)


template expect_character(p: Preprocessor, expected: set[char]): untyped =
   if p.buf[p.bufpos] notin expected:
      raise new_preprocessor_error("Expected character $1, got $2.", expected, p.buf[p.bufpos])


proc get_identifier(p: var Preprocessor): string =
   while p.buf[p.bufpos] in SymChars:
      add(result, p.buf[p.bufpos])
      inc(p.bufpos)


proc handle_text_replacement(p: var Preprocessor, def: Define) =
   # FIXME: Implement
   discard


proc handle_include(p: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_parameter(p: var Preprocessor, def: var Define) =
   p.bufpos = skip(p, p.bufpos)
   expect_character(p, SymChars)
   add(def.parameters, get_identifier(p))
   p.bufpos = skip(p, p.bufpos)


proc handle_parameter_list(p: var Preprocessor, def: var Define) =
   # Skip over '(' and start grabbing identifiers until we encounter the closing
   # parenthesis, a newline or the end of the file. The latter two are errors.
   inc(p.bufpos)
   while true:
      handle_parameter(p, def)
      expect_character(p, {')', ','})
      let c = p.buf[p.bufpos]
      inc(p.bufpos)
      if c == ')':
         break


proc handle_define(p: var Preprocessor) =
   var def: Define
   init(def)

   # Ignore whitespace (not newlines) leading up to the macro name.
   p.bufpos = skip(p, p.bufpos)
   if p.buf[p.bufpos] in lexbase.NewLines + {lexbase.EndOfFile}:
      return

   # Read the macro name from the buffer
   def.name = get_identifier(p)

   # If the next character is '(', this is a function like macro and we attempt
   # to read the parameter list.
   var invalid_syntax = false
   if p.buf[p.bufpos] == '(':
      handle_parameter_list(p, def)

   # We read and store the replacement text until we find the first newline
   # character not preceded by a backslash, or the end of the file.
   var include_newline = false
   while true:
      let c = p.buf[p.bufpos]
      case c
      of '\\':
         include_newline = true
      of lexbase.NewLines:
         if include_newline:
            add(def.text, c)
            include_newline = false
         else:
            break
      of lexbase.EndOfFile:
         break
      else:
         # FIXME: Need to skip comments '//'
         add(def.text, c)
      inc(p.bufpos)

   # FIXME: Check for duplicates (should be replaced).
   if not invalid_syntax:
      p.text.defines[def.name] = def


proc handle_ifdef(p: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_ifndef(p: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_elsif(p: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_else(p: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_endif(p: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_directive(p: var Preprocessor, dir: Directive) =
   case dir.identifier
   of "include":
      handle_include(p)
   of "define":
      handle_define(p)
   of "ifdef":
      handle_ifdef(p)
   of "ifndef":
      handle_ifndef(p)
   of "elsif":
      handle_elsif(p)
   of "else":
      handle_else(p)
   of "endif":
      handle_endif(p)
   else:
      # If we don't recognize the directive, check if if it's one of the defines
      # we've encountered so far. Otherwise, restore the directive to the buffer
      # and recursively call get_directive().
      if dir.identifier in p.text.defines:
         handle_text_replacement(p, p.text.defines[dir.identifier])
      else:
         add(p.text, "`" & dir.identifier)


proc get_directive(p: var Preprocessor, dir: var Directive) =
   init(dir)

   # Eat characters until we encounter the end of the file or the ` character,
   # marking the start of a compiler directive. We refill the buffer if we
   # encounter a newline character.
   var text_block = ""
   while p.buf[p.bufpos] notin {'`', lexbase.EndOfFile}:
      let c = p.buf[p.bufpos]
      add(text_block, c)
      if c in lexbase.NewLines:
         p.bufpos = handle_crlf(p, p.bufpos)
      else:
         inc(p.bufpos)
   add(p.text, text_block)

   # Skip the ` character and grab the directive identifier.
   inc(p.bufpos)
   while p.buf[p.bufpos] in SymChars:
      add(dir.identifier, p.buf[p.bufpos])
      inc(p.bufpos)


proc preprocess*(p: var Preprocessor, filename: string,
                 include_paths: openarray[string], s: Stream): PreprocessedText =
   open_preprocessor(p, filename, include_paths, s)

   while true:
      # Get the next directive and break if we encounter the end of the file
      # instead.
      var dir: Directive
      get_directive(p, dir)
      if p.buf[p.bufpos] == lexbase.EndOfFile:
         break

      # On encountering a preprocessor error when handling the directive we
      # ignore the rest of the line.
      # TODO: Probably communicate this to the caller.
      try:
         handle_directive(p, dir)
      except PreprocessorError as e:
         echo e.msg
         p.bufpos = skip_to_newline_or_eof(p, p.bufpos)

   result = p.text
   close_preprocessor(p)
