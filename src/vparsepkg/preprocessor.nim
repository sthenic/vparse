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
      parameters*: seq[Token]
      is_enabled: bool

   Context = object
      def: Define
      tokens: seq[Token]
      idx: int

   Preprocessor* = object
      lex: Lexer
      tok: Token
      defines: Table[string, Define]
      include_paths: seq[string]
      context_stack: seq[Context]
      error_tokens: seq[Token]


const
   RecursiveDefinition = "Recursive definition of $1."
   InvalidMacroName = "Invalid token given as macro name $1."
   MacroNameLine = "The macro name token $1 is not on the same line as the `define directive."


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
   pp.error_tokens = new_seq_of_cap[Token](32)
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
   def.is_enabled = true

   # Scan over `define.
   let def_line = pp.tok.line
   get_token(pp)
   # Expect the macro name on the same line as the `define directive.
   if pp.tok.kind != TkSymbol:
      pp.tok = new_error_token(pp.tok.line, pp.tok.col, InvalidMacroName, pp.tok)
      return
   elif pp.tok.line != def_line:
      pp.tok = new_error_token(pp.tok.line, pp.tok.col, MacroNameLine, pp.tok)
      return
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
      case pp.tok.kind
      of TkEndOfFile, TkBlockComment:
         break
      of TkComment:
         # A one=line comment is not included in the replacement list but tokens
         # on the next line may be included if we've scanned over a backslash
         # before this token.
         last_tok_line = pp.tok.line
      of TkBackslash:
         include_newline = true;
      else:
         # Check if the token is on a new line. If it is, we only collect it
         # into the replacement list if it was preceeded by a newline token.
         # Additionally, we check for a direct recursive definition, i.e. we
         # encounter a reference to the macro itself while collecting the
         # replacement list. However, we don't stop the control flow since that
         # leaves the token stream in a bad state. Instead, we construct the
         # error token and keep going. Once the replacement list has been
         # removed from the token stream, we discard the macro if an error was
         # encountered.
         let line_delta = pp.tok.line - last_tok_line
         if (line_delta > 1) or (line_delta == 1 and not include_newline):
            break
         if pp.tok.kind == TkDirective and pp.tok.identifier.s == def.name.identifier.s:
            add(pp.error_tokens, new_error_token(pp.tok.line, pp.tok.col,
                                                 RecursiveDefinition,
                                                 def.name.identifier.s))
         add(def.tokens, pp.tok)
         last_tok_line = pp.tok.line
         include_newline = false
      get_token(pp)

   # Add the define object unless there was an error in the `define directive.
   if len(pp.error_tokens) == 0:
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


proc enter_macro_context(pp: var Preprocessor, def: var Define) =
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

   # Add the context entry to the top of the stack and disable the macro from
   # expanding until the context is popped.
   def.is_enabled = false
   let context = Context(def: def, tokens: replacement_list, idx: 0)
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


proc is_context_exhausted(pp: Preprocessor): bool =
   return pp.context_stack[^1].idx > high(pp.context_stack[^1].tokens)


proc pop_context_stack(pp: var Preprocessor, enable: bool = true) =
   # As long as there are exhausted contexts on the stack we remove them and
   # reenable the corresponding macro for expansion.
   while len(pp.context_stack) > 0 and is_context_exhausted(pp):
      let context = pop(pp.context_stack)
      pp.defines[context.def.name.identifier.s].is_enabled = enable


proc inc_context_stack(pp: var Preprocessor) =
   inc(pp.context_stack[^1].idx)


proc get_context_token(pp: var Preprocessor, tok: var Token) =
   tok = top_context_token(pp)

   # Increment the context token list and check if we've just read the last
   # token, thus exhausting the replacement list. If we have, we pop the context
   # from the stack.
   inc_context_stack(pp)
   if is_context_exhausted(pp):
      pop_context_stack(pp)


proc get_source_token(pp: var Preprocessor, tok: var Token) =
   tok = pp.tok
   if pp.tok.kind != TkEndOfFile:
      get_token(pp.lex, pp.tok)


proc is_defined_macro(pp: Preprocessor, tok: Token): bool =
   return tok.kind == TkDirective and tok.identifier.s in pp.defines and
          pp.defines[tok.identifier.s].is_enabled


proc prepare_token(pp: var Preprocessor) =
   # When this proc returns, the preprocessor is in a position to return a token
   # from either the topmost context entry or the source buffer. We get to this
   # point by examining the next token from the active source (the context stack
   # has priority) to see if it should be consumed by the preprocessor or not.
   if len(pp.context_stack) > 0:
      while true:
         let next_tok = top_context_token(pp)
         if is_defined_macro(pp, next_tok):
            # Read past the macro name.
            inc_context_stack(pp)
            # FIXME: possibly all the directives? handle_directive()?
            enter_macro_context(pp, pp.defines[next_tok.identifier.s])
         else:
            break
   else:
      while true:
         # If there's an error token to propagate we break out of the loop.
         if len(pp.error_tokens) > 0:
            break

         # If by handling a directive the context stack is no longer empty, we
         # perform a recursive call to run the code block above. A macro
         # invocation may be the first context token.
         if len(pp.context_stack) > 0:
            prepare_token(pp)
            break

         case pp.tok.kind
         of TkDirective:
            if not handle_directive(pp):
               break
         else:
            break

proc get_token*(pp: var Preprocessor, tok: var Token) =
   # Error tokens have the highest precedence. Otherwise, if there's anything on
   # the context stack, the caller will receive the next token from there.
   # If not, the next token is read directly from the source buffer.
   prepare_token(pp)
   if len(pp.error_tokens) > 0:
      tok = pp.error_tokens.pop()
   elif len(pp.context_stack) > 0:
      get_context_token(pp, tok)
   else:
      get_source_token(pp, tok)
