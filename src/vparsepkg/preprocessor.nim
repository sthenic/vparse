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


# Forward declaration of public interface.
proc get_token*(pp: var Preprocessor, tok: var Token)


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
   var last_tok_line = def.origin.line
   while true:
      # FIXME: Check for recursive definitions. Not allowed according to the
      #        standard.
      case pp.tok.kind
      of TkEndOfFile:
         break
      of TkBackslash:
         include_newline = true;
      else:
         # Check if the token is on a new line. If it is, we only collect it
         # into the replacement list if it was preceeded by a newline token.
         if pp.tok.line != last_tok_line and not include_newline:
            break
         add(def.tokens, pp.tok)
         last_tok_line = pp.tok.line
         include_newline = false
      get_token(pp)

   # Add the define object
   pp.defines[def.name.identifier.s] = def


proc handle_undef(pp: var Preprocessor) =
   # The del() proc does nothing if the key does not exist.
   # FIXME: Expect an identifier (on the same line too).
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


proc collect_arguments(pp: var Preprocessor, def: Define): Table[string, seq[Token]] =
   ## Attempt to collect arguments for the macro invocation of ``def``. The
   ## number of exepected arguments is the length of ``def.parameters``.
   ## Fewer arguments is an error. This proc expects the opening parenthesis
   ## as the first token in the stream.
   let nof_arguments = len(def.parameters)
   result = init_table[string, seq[Token]](right_size(nof_arguments))

   # TODO: Enforce opening parenthesis.
   var tok: Token
   get_token(pp, tok)

   # Although only valid Verilog expressions are allowed as arguments we don't
   # implement any syntax-aware parsing of the tokens here. Instead, we track
   # the delimiters we encounter in order to separate the arguments correctly.
   # Whether or not the collected tokens constitute a valid Verilog expression
   # is for the parser to decide. Additionally, we have to use the public token
   # consumption interface to read tokens since these may come from both the
   # source file and the context stack. By doing this, we naturally expand any
   # macros we come across.
   var paren_count = 0
   var brace_count = 0
   var idx = 0
   var token_list: seq[Token] = @[]
   while true:
      get_token(pp, tok)
      case tok.kind
      of TkLbrace:
         inc(brace_count)

      of TkRbrace:
         if brace_count > 0:
            dec(brace_count)

      of TkLparen:
         inc(paren_count)

      of TkRparen:
         if paren_count > 0:
            dec(paren_count)
         else:
            result[def.parameters[idx].identifier.s] = token_list
            break

      of TkComma:
         if paren_count == 0 and brace_count == 0:
            result[def.parameters[idx].identifier.s] = token_list
            set_len(token_list, 0)
            inc(idx)
            if len(result) >= nof_arguments:
               return
            else:
               continue

      of TkEndOfFile:
         # FIXME: Error
         break

      else:
         discard

      # If we haven't broken the control flow the token should be included in
      # the token list.
      add(token_list, tok)


proc substitute_parameters(def: Define, arguments: Table[string, seq[Token]]): seq[Token] =
   assert len(def.parameters) == len(arguments)
   for tok in def.tokens:
      if tok.kind == TkSymbol and tok.identifier.s in arguments:
         add(result, arguments[tok.identifier.s])
      else:
         add(result, tok)


proc enter_macro_context(pp: var Preprocessor, def: Define) =
   ## Push a new macro context onto the context stack. This proc expects that
   ## the macro token (``def.name``) has been removed from the token stream.

   # Expect arguments to follow a function-like macro. Once we've collected the
   # arguments, we perform parameter substitution in the macro's replacement
   # list.
   var arguments: Table[string, seq[Token]]
   var replacement_list: seq[Token]
   if len(def.parameters) > 0:
      # FIXME: Check for errors
      arguments = collect_arguments(pp, def)
      replacement_list = substitute_parameters(def, arguments)
   else:
      replacement_list = def.tokens

   # Add the context entry to the top of the stack.
   let context = Context(tokens: replacement_list, idx: 0)
   add(pp.context_stack, context)


proc handle_directive(pp: var Preprocessor): bool =
   result = true
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
      let macro_name = pp.tok.identifier.s
      if macro_name in pp.defines:
         get_token(pp)
         enter_macro_context(pp, pp.defines[macro_name])
      else:
         result = false


proc top_context_token(pp: Preprocessor): Token =
   result = pp.context_stack[^1].tokens[pp.context_stack[^1].idx]


proc is_last_context_token(pp: Preprocessor): bool =
   return pp.context_stack[^1].idx == high(pp.context_stack[^1].tokens)


proc pop_context_stack(pp: var Preprocessor) =
   discard pop(pp.context_stack)


proc inc_context_stack(pp: var Preprocessor) =
   inc(pp.context_stack[^1].idx)


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


proc is_defined_macro(pp: Preprocessor, tok: Token): bool =
   return tok.kind == TkDirective and tok.identifier.s in pp.defines


proc prepare_token(pp: var Preprocessor) =
   # When this proc returns, the preprocessor is in a position to return a token
   # from either the topmost context entry or the source buffer. We get to this
   # point by examining the next token from the active source (the context stack
   # has priority) to see if it should be consumed by the preprocessor or not.
   if len(pp.context_stack) > 0:
      while true:
         let next_tok = top_context_token(pp)
         if is_defined_macro(pp, next_tok):
            if is_last_context_token(pp):
               pop_context_stack(pp)
            else:
               inc_context_stack(pp)
            # FIXME: possibly all the directives? handle_directive()?
            enter_macro_context(pp, pp.defines[next_tok.identifier.s])
         else:
            break
   else:
      while true:
         # If by handling a directive the context stack is no longer empty, we
         # perform a recursive call to run the code block above. A macro
         # invocationmay be the first context token.
         if len(pp.context_stack) != 0:
            prepare_token(pp)
            break

         case pp.tok.kind
         of TkDirective:
            if not handle_directive(pp):
               break
         else:
            break

proc get_token*(pp: var Preprocessor, tok: var Token) =
   # If there's anything on the context stack, the caller will receive the next
   # token from there. Otherwise, the next token is read directly from the
   # source buffer.
   prepare_token(pp)
   if len(pp.context_stack) > 0:
      get_context_token(pp, tok)
   else:
      get_source_token(pp, tok)
