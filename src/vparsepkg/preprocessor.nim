# Copyright (C) Marcus Eriksson 2020
#
# Description: This file implements a preprocessor for Verilog 2005.
# TODO: Describe an overview of the the implementation.

import streams
import strutils

import ./lexer

export lexer

type
   Preprocessor* = object
      lex: Lexer
      tok: Token
      include_paths: seq[string]


proc open_preprocessor*(pp: var Preprocessor, cache: IdentifierCache,
                        filename: string, include_paths: openarray[string],
                        s: Stream) =
   init(pp.tok)
   open_lexer(pp.lex, cache, filename, s)
   set_len(pp.include_paths, 0)
   add(pp.include_paths, include_paths)
   get_token(pp.lex, pp.tok)


proc close_preprocessor*(pp: var Preprocessor) =
   close_lexer(pp.lex)


proc get_token*(pp: var Preprocessor, tok: var Token) =
   tok = pp.tok
   if pp.tok.kind != TkEndOfFile:
      get_token(pp.lex, pp.tok)
