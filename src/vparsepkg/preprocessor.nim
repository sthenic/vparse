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
      # FIXME: Bool to enable/disable the macro expansion? Like GCC does?
      name*: Token
      origin*: Origin
      tokens*: seq[Token]
      parameters*: seq[Token]

   Context = object
      tokens: seq[Token]
      idx: int

   Preprocessor* = object
      lex: Lexer
      tok: Token
      defines: Table[string, Define]
      include_paths: seq[string]
      context_stack: seq[Context]


proc get_token(pp: var Preprocessor) =
   ## Internal token consumer. Reads a token from the lexer and stores the result
   ## in the local ``tok`` variable.
   get_token(pp.lex, pp.tok)


template update_origin(pp: Preprocessor, o: var Origin) =
   o.filename = pp.lex.filename
   o.line = pp.tok.line
   o.col = pp.tok.col


proc open_preprocessor*(pp: var Preprocessor, cache: IdentifierCache,
                        filename: string, include_paths: openarray[string],
                        s: Stream) =
   ## Open the preprocessor and prepare to process the target file.
   init(pp.tok)
   open_lexer(pp.lex, cache, filename, s)
   pp.defines = init_table[string, Define](32)
   pp.include_paths = new_seq_of_cap[string](len(pp.include_paths))
   add(pp.include_paths, include_paths)
   pp.context_stack = new_seq_of_cap[Context](32)
   get_token(pp.lex, pp.tok)


proc close_preprocessor*(pp: var Preprocessor) =
   ## Close the preprocessor.
   close_lexer(pp.lex)


proc handle_parameter_list(pp: var Preprocessor, def: var Define) =
   ## Collect the parameter list of ``def`` from the source buffer. When this
   ## proc returns, the closing parenthesis has been removed from the buffer.
   # Skip over the opening parenthesis and collect a list of comma-separated
   # identifiers.
   get_token(pp)
   while true:
      if pp.tok.kind != TkSymbol:
         break
      add(def.parameters, pp.tok)
      get_token(pp)
      if (pp.tok.kind != TkComma):
         break
      get_token(pp)

   # FIXME: Expect a closing parenthesis. Error if not present.
   get_token(pp)


proc immediately_follows(x, y: Token): bool =
   ## Check if ``x`` immediately follows ``y`` in the source buffer.
   assert(y.kind == TkSymbol)
   return x.line == y.line and x.col == (y.col + len(y.identifier.s))


proc handle_define(pp: var Preprocessor) =
   ## Handle the ``define`` directive.
   var def: Define
   update_origin(pp, def.origin)

   # FIXME: Expect the macro name, error if not present.
   get_token(pp)
   def.name = pp.tok

   # If the next character is '(', and it follows the macro name w/o any
   # whitespace, this is a function like macro and we attempt to read the
   # parameter list.
   get_token(pp)
   if pp.tok.kind == TkLparen and immediately_follows(pp.tok, def.name):
      handle_parameter_list(pp, def)

   var include_newline = false
   while true:
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
      get_token(pp)

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


proc enter_macro_context(pp: var Preprocessor, def: Define) =
   # This proc pushes a new macro context onto the context stack.
   # FIXME: Handle nested expansion and whatnot.
   let context = Context(tokens: def.tokens, idx: 0)
   add(pp.context_stack, context)


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
      # If we don't recognize the directive, check if it's a macro usage which
      # has a matching entry in the macro table. Otherwise, leave the token as
      # it is. The parser will deal with it.
      if pp.tok.identifier.s in pp.defines:
         enter_macro_context(pp, pp.defines[pp.tok.identifier.s])
         get_token(pp)


proc top_context_token(pp: Preprocessor): Token =
   result = pp.context_stack[^1].tokens[pp.context_stack[^1].idx]


proc is_last_context_token(pp: Preprocessor): bool =
   return pp.context_stack[^1].idx == high(pp.context_stack[^1].tokens)


proc inc_context_stack(pp: var Preprocessor)
proc pop_context_stack(pp: var Preprocessor) =
   discard pop(pp.context_stack)
   # After a pop, we have to reexamine the source buffer too see if the current
   # token is a directive, in which case we have to handle it. However, we only
   # do this if the context stack is empty.
   if len(pp.context_stack) == 0:
      if pp.tok.kind == TkDirective:
         handle_directive(pp)


proc inc_context_stack(pp: var Preprocessor) =
   inc(pp.context_stack[^1].idx)
   # After incrementing the token cursor of the topmost entry of the context
   # stack, we have to check if the token is a text macro usage. If it is, we
   # enter a new macro context. We also have to handle the special case that
   # this is the last token, in which case we pop the current macro context
   # from the stack before entering the new one.
   let next_tok = top_context_token(pp)
   if next_tok.kind == TkDirective and next_tok.identifier.s in pp.defines:
      if is_last_context_token(pp):
         pop_context_stack(pp)
      # FIXME: possibly all the directives? handle_directive()?
      enter_macro_context(pp, pp.defines[next_tok.identifier.s])


proc get_context_token(pp: var Preprocessor, tok: var Token) =
   tok = top_context_token(pp)

   # If we've just read the last token from the topmost context entry, we remove
   # the entry from the stack. Otherwise, increment the entry's token cursor.
   if is_last_context_token(pp):
      pop_context_stack(pp)
   else:
      inc_context_stack(pp)


proc get_source_token(pp: var Preprocessor, tok: var Token) =
   tok = pp.tok
   if pp.tok.kind != TkEndOfFile:
      get_token(pp.lex, pp.tok)
      while pp.tok.kind == TkDirective and len(pp.context_stack) == 0:
         handle_directive(pp)


proc get_token*(pp: var Preprocessor, tok: var Token) =
   # If there's anything on the context stack, the caller will receive the next
   # token from there. Otherwise, the next token is read directly from the
   # source buffer.

   # FIXME: Refactor this to do preprocessing instead of postprocessing like we
   # do now where the token to return to the caller is processed since before.
   # We should begin by reading and parsing the token, i.e. determining if we
   # should push a context stack and return something from that etc.
   if len(pp.context_stack) > 0:
      get_context_token(pp, tok)
   else:
      get_source_token(pp, tok)
