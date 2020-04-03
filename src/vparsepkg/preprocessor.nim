# Copyright (C) Marcus Eriksson 2020
#
# Description: This file implements a preprocessor for Verilog 2005.
# TODO: Describe an overview of the the implementation.

import streams
import lexbase
import tables

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

   Preprocessor* = object of BaseLexer
      filename*: string
      include_paths: seq[string]
      text: PreprocessedText


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


proc skip(p: var Preprocessor, pos: int): int =
   result = pos
   while p.buf[pos] in SpaceChars:
      add(p.text, $p.buf[pos])
      inc(result)


proc handle_text_replacement(p: var Preprocessor, def: Define) =
   # FIXME: Implement
   discard


proc handle_include(p: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_define(p: var Preprocessor) =
   var def: Define
   init(def)

   # If the next character is '(', this is a function like macro and we attempt
   # to read the parameter list. Otherwise we read and store the replacement
   # text until we find the first newline character not preceded by a backslash,
   # or the end of the file.


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
      handle_directive(p, dir)

   result = p.text
   close_preprocessor(p)
