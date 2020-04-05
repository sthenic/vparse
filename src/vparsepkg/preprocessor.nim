# Copyright (C) Marcus Eriksson 2020
#
# Description: This file implements a preprocessor for Verilog 2005.
# TODO: Describe an overview of the the implementation.

import streams
import tables
import strutils

import ./lexer

export lexer

type
   Origin* = object
      filename*: string
      line*, col*: int

   Define* = object
      name*: Token
      origin*: Origin
      tokens*: seq[Token]

   Preprocessor* = object
      lex: Lexer
      tok: Token
      defines: Table[string, Define]
      include_paths: seq[string]


proc get_token(pp: var Preprocessor) =
   # Internal token consumer.
   get_token(pp.lex, pp.tok)


template update_origin(pp: Preprocessor, o: var Origin) =
   o.filename = pp.lex.filename
   o.line = pp.tok.line
   o.col = pp.tok.col


proc open_preprocessor*(pp: var Preprocessor, cache: IdentifierCache,
                        filename: string, include_paths: openarray[string],
                        s: Stream) =
   init(pp.tok)
   open_lexer(pp.lex, cache, filename, s)
   pp.defines = init_table[string, Define](32)
   pp.include_paths = new_seq_of_cap[string](len(pp.include_paths))
   add(pp.include_paths, include_paths)
   get_token(pp.lex, pp.tok)


proc close_preprocessor*(pp: var Preprocessor) =
   close_lexer(pp.lex)


proc handle_define(pp: var Preprocessor) =
   var def: Define
   update_origin(pp, def.origin)

   # FIXME: Expect the macro name, error if not present.
   get_token(pp)
   def.name = pp.tok

   var include_newline = false
   while true:
      get_token(pp)
      case pp.tok.kind
      of TkEndOfFile:
         break
      of TkBackslash:
         include_newline = true;
      else:
         # Check if the token is on a new line. If it is, we only collect it
         # into the .
         if pp.tok.line != def.origin.line and not include_newline:
            break
         add(def.tokens, pp.tok)
         include_newline = false

   # Add the define object
   pp.defines[def.name.identifier.s] = def


proc handle_undef(pp: var Preprocessor) =
   # The del() proc does nothing if the key does not exist.
   # FIXME: Expect an identifier (on the same line too)
   get_token(pp)
   del(pp.defines, pp.tok.identifier.s)
   get_token(pp)


proc handle_include(pp: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_ifdef(pp: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_ifndef(pp: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_elsif(pp: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_else(pp: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_endif(pp: var Preprocessor) =
   # FIXME: Implement
   discard


proc handle_text_replacement(pp: var Preprocessor) =
   # The current token in pp.tok is a known define which should be expanded.
   # FIXME: Implement
   discard


proc handle_directive(pp: var Preprocessor) =
   case pp.tok.identifier.s
   of "define":
      handle_define(pp)
   of "undef":
      handle_undef(pp)
   of "include":
      handle_include(pp)
   of "ifdef":
      handle_ifdef(pp)
   of "ifndef":
      handle_ifndef(pp)
   of "elsif":
      handle_elsif(pp)
   of "else":
      handle_else(pp)
   of "endif":
      handle_endif(pp)
   else:
      # If we don't recognize the directive, check if if it's one of the defines
      # we've encountered so far. Otherwise, leave the token as it is. The
      # parser will deal with the
      if pp.tok.identifier.s in pp.defines:
         handle_text_replacement(pp)


proc get_token*(pp: var Preprocessor, tok: var Token) =
   tok = pp.tok
   if pp.tok.kind != TkEndOfFile:
      get_token(pp.lex, pp.tok)
      if pp.tok.kind == TkDirective:
         handle_directive(pp)
