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
   OriginKind* = enum
      OkSourceText,
      OkMacroExpansion

   Origin = object
      kind*: OriginKind
      filename*: string
      line*, col*: int

   SourceText = object
      origin*: Origin
      text*: string

   PreprocessedText* = object
      filename*: string
      text*: string
      defines*: Table[string, Define]
      origins*: OrderedTable[int, Origin]

   Define* = object
      name*: string
      parameters*: seq[string]
      text*: string
      origin*: Origin

   Directive = object
      identifier: string

   PreprocessorError* = object of ValueError

   Preprocessor* = object of BaseLexer
      filename: string
      include_paths: seq[string]
      text: PreprocessedText


proc new_preprocessor_error(msg: string, args: varargs[string, `$`]):
      ref PreprocessorError =
   new result
   result.msg = format(msg, args)


proc `$`*(kind: OriginKind): string =
   case kind
   of OkSourceText:
      result = "source"
   of OkMacroExpansion:
      result = "macro"


proc pretty*(o: Origin): string =
   result = format("($1) -- $2:$3:$4", o.kind, o.filename, o.line, o.col)


proc pretty*(o: OrderedTable[int, Origin]): string =
   for k, v in pairs(o):
      add(result, format("$1 $2\n", k, pretty(v)))


proc pretty*(d: Define): string =
   result = format("$1 -- $2:$3:$4", d.name, d.origin.filename,
                   d.origin.line, d.origin.col)
   if len(d.parameters) > 0:
      add(result, "\n   Parameters: ")
      for i, p in d.parameters:
         if i > 0:
            add(result, ", ")
         add(result, p)


proc pretty*(d: Table[string, Define]): string =
   for k, v in pairs(d):
      add(result, pretty(v) & "\n")


proc pretty*(t: PreprocessedText): string =
   const INDENT = 3
   result = """
Filename: $1
Length: $2
Origins:
$3
Defines:
$4
"""
   result = format(result, t.filename, len(t.text),
                   indent(pretty(t.origins), INDENT),
                   indent(pretty(t.defines), INDENT))


proc init(t: var PreprocessedText) =
   set_len(t.text, 0)
   set_len(t.filename, 0)
   t.defines = init_table[string, Define](32)
   t.origins = init_ordered_table[int, Origin](128)


proc init(o: var Origin, kind: OriginKind) =
   set_len(o.filename, 0)
   o.kind = kind
   o.col = 0
   o.line = 0


proc init(def: var Define) =
   set_len(def.name, 0)
   set_len(def.parameters, 0)
   set_len(def.text, 0)
   init(def.origin, OkMacroExpansion)


proc init(s: var SourceText) =
   set_len(s.text, 0)
   init(s.origin, OkSourceText)


proc add(s: var SourceText, c: char) =
   add(s.text, $c)


proc add(p: var PreprocessedText, s: string) =
   add(p.text, s)


proc add(p: var PreprocessedText, s: string, o: Origin) =
   p.origins[len(p.text)] = o
   add(p.text, s)


proc add(p: var PreprocessedText, s: SourceText) =
   p.origins[len(p.text)] = s.origin
   add(p.text, s.text)


proc init(dir: var Directive) =
   set_len(dir.identifier, 0)


template update_origin(p: Preprocessor, o: var Origin) =
   o.filename = p.filename
   o.line = p.line_number
   o.col = get_col_number(p, p.bufpos)


proc open_preprocessor(p: var Preprocessor, filename: string,
                       include_paths: openarray[string], s: Stream) =
   lexbase.open(p, s)
   p.filename = filename
   set_len(p.include_paths, len(include_paths))
   add(p.include_paths, include_paths)
   init(p.text)
   p.text.filename = filename


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


proc skip(p: var Preprocessor, pos: int): int =
   result = pos
   while p.buf[result] in SpaceChars:
      inc(result)


proc skip_to_newline_or_eof(p: var Preprocessor, pos: int): int =
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
   add(p.text, def.text, def.origin)


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

   # Read the macro name from the buffer and mark this as the origin.
   update_origin(p, def.origin)
   def.name = get_identifier(p)

   # If the next character is '(', this is a function like macro and we attempt
   # to read the parameter list.
   var invalid_syntax = false
   if p.buf[p.bufpos] == '(':
      handle_parameter_list(p, def)

   # Skip until the first non-whitespace character.
   p.bufpos = skip(p, p.bufpos)

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
            p.bufpos = handle_crlf(p, p.bufpos)
            continue
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
   var source_text: SourceText
   init(source_text)
   update_origin(p, source_text.origin)
   while p.buf[p.bufpos] notin {'`', lexbase.EndOfFile}:
      let c = p.buf[p.bufpos]
      add(source_text, c)
      if c in lexbase.NewLines:
         p.bufpos = handle_crlf(p, p.bufpos)
      else:
         inc(p.bufpos)
   add(p.text, source_text)

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
