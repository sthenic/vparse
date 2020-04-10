# Copyright (C) Marcus Eriksson 2020
#
# Description: This file implements a preprocessor for Verilog 2005.
# TODO: Describe an overview of the the implementation.

import streams
import tables
import strutils
import os

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
      pp_tok: Token
      defines: Table[string, Define]
      include_paths: seq[string]
      context_stack: seq[Context]
      error_tokens: seq[Token]
      pp_include: ref Preprocessor
      endif_semaphore: int

   PreprocessorError = object of ValueError
      line, col: int


const
   RecursiveDefinition = "Recursive definition of $1."
   InvalidMacroName = "Invalid token given as macro name $1."
   DirectiveArgLine = "The argument token $1 is not on the same line as the $2 directive."
   ExpectedToken = "Expected token $1, got $2."
   UnexpectedToken = "Unexpected token $1."
   UnexpectedEndOfFile = "Unexpected end of file."
   WrongNumberOfArguments = "Expected $1 arguments, got $2."
   CannotOpenFile = "Cannot open file '$1'."
   RedefineProtected = "Attempting to redefine protected macro name $1."
   ProtectedMacroNames = [
      "begin_keywords", "celldefine", "default_nettype", "define", "else",
      "elsif", "end_keywords", "endcelldefine", "endif", "ifdef", "ifndef",
      "include", "line", "nounconnected_drive", "pragma", "resetall",
      "timescale", "unconnected_drive", "undef"
   ]


proc new_preprocessor_error(line, col: int, msg: string,
                            args: varargs[string, `$`]): ref PreprocessorError =
   new result
   result.msg = format(msg, args)
   result.line = line
   result.col = col


proc add_error_token(pp: var Preprocessor, line, col: int, msg: string,
                     args: varargs[string, `$`]) =
   add(pp.error_tokens, new_error_token(line, col, msg, args))


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
   init(pp.pp_tok)
   pp.endif_semaphore = 0
   pp.defines = init_table[string, Define](64)
   pp.include_paths = new_seq_of_cap[string](len(pp.include_paths) + 1)
   pp.context_stack = new_seq_of_cap[Context](32)
   pp.error_tokens = new_seq_of_cap[Token](32)
   pp.pp_include = nil

   # We add the include paths passed as an argument but not before we add the
   # parent directory of the file itself. The parent directory always has
   # priority.
   if file_exists(filename):
      let parent_dir = parent_dir(expand_filename(filename))
      if parent_dir notin include_paths:
         add(pp.include_paths, parent_dir)
   add(pp.include_paths, include_paths)

   open_lexer(pp.lex, cache, filename, s)
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

   # Expect a closing parenthesis.
   if pp.tok.kind != TkRparen:
      add_error_token(pp, pp.tok.line, pp.tok.col, ExpectedToken, TkRparen, pp.tok)
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
      add_error_token(pp, pp.tok.line, pp.tok.col, InvalidMacroName, pp.tok)
      get_token(pp)
      return
   elif pp.tok.line != def_line:
      add_error_token(pp, pp.tok.line, pp.tok.col, DirectiveArgLine, pp.tok, "`define")
      get_token(pp)
      return
   def.name = pp.tok

   if def.name.identifier.s in ProtectedMacroNames:
      add_error_token(pp, pp.tok.line, pp.tok.col, RedefineProtected, def.name)
      get_token(pp)
      return

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
            add_error_token(pp, pp.tok.line, pp.tok.col, RecursiveDefinition,
                            def.name.identifier.s)
         add(def.tokens, pp.tok)
         last_tok_line = pp.tok.line
         include_newline = false
      get_token(pp)

   # Add the define object unless there was an error in the `define directive.
   if len(pp.error_tokens) == 0:
      pp.defines[def.name.identifier.s] = def


proc handle_undef(pp: var Preprocessor) =
   # Scan over `undef.
   let undef_line = pp.tok.line
   get_token(pp)
   # Expect the macro name on the same line as the `undef directive.
   if pp.tok.kind != TkSymbol:
      add_error_token(pp, pp.tok.line, pp.tok.col, InvalidMacroName, pp.tok)
      get_token(pp)
      return
   elif pp.tok.line != undef_line:
      add_error_token(pp, pp.tok.line, pp.tok.col, DirectiveArgLine, pp.tok, "`undef")
      get_token(pp)
      return
   # FIXME: Undefining a macro that doesn't exist should result in an error node.
   #        Should turn up as a warning though.
   # The del() proc does nothing if the key does not exist.
   del(pp.defines, pp.tok.identifier.s)
   get_token(pp)


proc get_include_file(pp: Preprocessor, filename: string): string =
   ## Return the full path to the file with name/path ``filename``. If the file
   ## does not exist, a ``PreprocessorError`` is raised.
   # If the file exists in the current directory or is a relative path we're
   # done right away. Otherwise, check the include paths.
   # FIXME: Environment variable for include path?
   if file_exists(filename):
      result = expand_filename(filename)
   else:
      for dir in pp.include_paths:
         let tmp = dir / filename
         if file_exists(tmp):
            return expand_filename(tmp)


proc handle_include(pp: var Preprocessor) =
   # Skip over `include.
   let include_line = pp.tok.line
   get_token(pp)

   if pp.tok.kind != TkStrLit:
      add_error_token(pp, pp.tok.line, pp.tok.col, ExpectedToken, TkStrLit, pp.tok)
      get_token(pp)
      return
   elif pp.tok.line != include_line:
      add_error_token(pp, pp.tok.line, pp.tok.col, DirectiveArgLine, pp.tok, "`include")
      get_token(pp)
      return

   var filename = pp.tok.literal
   let line = pp.tok.line
   let col = pp.tok.col
   let full_path = get_include_file(pp, filename)
   get_token(pp)
   if len(full_path) == 0:
      add_error_token(pp, line, col, CannotOpenFile, filename)
      return

   # Create a new preprocessor for the include file.
   let fs = new_file_stream(full_path)
   new pp.pp_include
   # var pp_include_paths = new_seq_of_cap[string](len(pp.include_paths) + 1)
   # add(pp_include_paths, pp.include_paths)
   # add(pp_include_paths, expand_filename(pp.lex.filename))
   open_preprocessor(pp.pp_include[], pp.lex.cache, full_path,
                     pp.include_paths, fs)
   get_token(pp.pp_include[], pp.pp_tok)
   # FIXME: Ensure that the next token is on a different line?


proc handle_else(pp: var Preprocessor) =
   if pp.endif_semaphore == 0:
      add_error_token(pp, pp.tok.line, pp.tok.col, UnexpectedToken, pp.tok)
      get_token(pp)
      return

   # If we're in this proc then the preprocessor has encountered an `else
   # while tokens from an _active_ `ifdef/`ifndef/`elif branch. Now we have
   # to remove all the subsequent tokens from the stream until we hit the end
   # of the file (an error condition) or a closing `endif directive.
   let semaphore_reference = pp.endif_semaphore
   while true:
      get_token(pp)
      case pp.tok.kind
      of TkEndOfFile:
         add_error_token(pp, pp.tok.line, pp.tok.col, UnexpectedEndOfFile)
         break
      of TkDirective:
         case pp.tok.identifier.s
         of "ifdef", "ifndef":
            inc(pp.endif_semaphore)
         of "endif":
            if pp.endif_semaphore == semaphore_reference:
               get_token(pp)
               dec(pp.endif_semaphore)
               break
            else:
               dec(pp.endif_semaphore)
         else:
            discard
      else:
         discard


proc handle_endif(pp: var Preprocessor) =
   if pp.endif_semaphore == 0:
      add_error_token(pp, pp.tok.line, pp.tok.col, UnexpectedToken, pp.tok)
   else:
      dec(pp.endif_semaphore)
   get_token(pp)


proc handle_ifdef(pp: var Preprocessor, invert: bool = false) =
   # Skip over `ifdef.
   let line = pp.tok.line
   var label = pp.tok.identifier.s
   get_token(pp)

   if pp.tok.kind != TkSymbol:
      add_error_token(pp, pp.tok.line, pp.tok.col, ExpectedToken, TkSymbol, pp.tok)
      get_token(pp)
      return
   elif pp.tok.line != line:
      add_error_token(pp, pp.tok.line, pp.tok.col, DirectiveArgLine, pp.tok, "`" & label)
      get_token(pp)
      return

   var take_if_branch = pp.tok.identifier.s in pp.defines
   if invert:
      take_if_branch = not take_if_branch

   # If we should take the if-branch, we skip to the next token and increment
   # the endif semaphore to expect an `endif directive later on. Otherwise, we
   # start removing tokens until one of five things happens:
   #   1. The file ends (error condition).
   #   2. We find an `ifdef or `ifndef directive in which case we increment the
   #      semaphore to match w/ the correct `endif token and continue discarding.
   #   3. We find an `elsif directive in which case we recusively call this
   #      function and break since the logic is the same.
   #   4. We find an `else directive in which case we know that the following
   #      lines of souce code should be included. We increment the endif
   #      semaphore and break.
   #   5. We find an `endif directive in which case we remove that token from
   #      the stream and break.
   let semaphore_reference = pp.endif_semaphore
   if take_if_branch:
      get_token(pp)
      inc(pp.endif_semaphore)
   else:
      while true:
         get_token(pp)
         case pp.tok.kind
         of TkEndOfFile:
            add_error_token(pp, pp.tok.line, pp.tok.col, UnexpectedEndOfFile)
            break
         of TkDirective:
            case pp.tok.identifier.s
            of "ifdef", "ifndef":
               inc(pp.endif_semaphore)
            of "elsif":
               handle_ifdef(pp)
               break
            of "else":
               if pp.endif_semaphore == semaphore_reference:
                  get_token(pp)
                  inc(pp.endif_semaphore)
                  break
            of "endif":
               if pp.endif_semaphore == semaphore_reference:
                  get_token(pp)
                  break
               else:
                  dec(pp.endif_semaphore)
            else:
               discard
         else:
            discard


proc collect_arguments(pp: var Preprocessor, def: Define): Table[string, seq[Token]] =
   ## Attempt to collect arguments for the macro invocation of ``def``. The
   ## number of exepected arguments is the length of ``def.parameters``.
   ## Fewer arguments is an error. This proc expects the opening parenthesis
   ## as the first token in the stream.
   let nof_arguments = len(def.parameters)
   result = init_table[string, seq[Token]](right_size(nof_arguments))

   # Expect an opening parenthesis.
   var tok: Token
   get_token(pp, tok)
   if tok.kind != TkLparen:
      raise new_preprocessor_error(tok.line, tok.col, ExpectedToken, TkLparen, tok)
   let paren_line = tok.line
   let paren_col = tok.col

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
            if idx < nof_arguments:
               result[def.parameters[idx].identifier.s] = token_list
            break
      of TkComma:
         if paren_count == 0 and brace_count == 0:
            if idx < nof_arguments:
               result[def.parameters[idx].identifier.s] = token_list
            set_len(token_list, 0)
            inc(idx)
            continue
      of TkEndOfFile:
         raise new_preprocessor_error(tok.line, tok.col, UnexpectedEndOfFile)
      else:
         discard

      # If we haven't broken the control flow the token should be included in
      # the token list.
      add(token_list, tok)

   let nof_collected_arguments = idx + 1
   if nof_collected_arguments != nof_arguments:
      raise new_preprocessor_error(paren_line, paren_col, WrongNumberOfArguments,
                                   nof_arguments, nof_collected_arguments)


proc substitute_parameters(def: Define, arguments: Table[string, seq[Token]]): seq[Token] =
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
      # Collecting arguments can generate errors since a certain syntax is
      # expected. We convert exceptions into error tokens and stop the function
      # in that case.
      try:
         arguments = collect_arguments(pp, def)
         replacement_list = substitute_parameters(def, arguments)
      except PreprocessorError as e:
         add_error_token(pp, e.line, e.col, e.msg)
         return
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
      handle_ifdef(pp, invert = true)
   of "else", "elsif":
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


proc get_include_token(pp: var Preprocessor, tok: var Token) =
   tok = pp.pp_tok
   get_token(pp.pp_include[], pp.pp_tok)


proc is_macro_defined(pp: Preprocessor, tok: Token): bool =
   return tok.kind == TkDirective and tok.identifier.s in pp.defines and
          pp.defines[tok.identifier.s].is_enabled


proc merge(x: var Table[string, Define], y: Table[string, Define]) =
   # TODO: Perhaps generate a warning if a define overwrites another entry?
   for k, v in pairs(y):
      x[k] = v


proc prepare_token(pp: var Preprocessor) =
   # When this proc returns, the preprocessor is in a position to return a token
   # from either the include file, the topmost context entry or the source
   # buffer. We get to this point by examining the next token from the active
   # source to see if it should be consumed by the preprocessor or not.
   if pp.pp_include != nil:
      # The token representing the end of the include file does not propagate
      # to the caller. We use this to close the include file's preprocessor
      # and recursively call this function to prepare a token from one of the
      # other sources. Additionally, any defines active at the end of the
      # processed include file is added to the defines on this level.
      if pp.pp_tok.kind == TkEndOfFile:
         close_preprocessor(pp.pp_include[])
         merge(pp.defines, pp.pp_include.defines)
         pp.pp_include = nil
         prepare_token(pp)
   elif len(pp.context_stack) > 0:
      while true:
         let next_tok = top_context_token(pp)
         if is_macro_defined(pp, next_tok):
            # Read past the macro name.
            inc_context_stack(pp)
            # FIXME: possibly all the directives? handle_directive()?
            enter_macro_context(pp, pp.defines[next_tok.identifier.s])
         else:
            break
   else:
      while true:
         # If a include file has been set up as a token source we break out of
         # the loop.
         if pp.pp_include != nil:
            prepare_token(pp)
            break

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
   ## Read a token from the preprocessor ``pp`` into ``tok``.
   # This proc arbitrates the various token sources. There's a clear order of
   # precedence:
   #
   #   1. Tokens from an `include direcive.
   #   2. Error tokens (this is how errors are communicated to the caller).
   #   3. Tokens from an active context (macro expansion).
   #   4. Tokens from the source file.
   #
   # But before the source is selected, the preprocessor goes through a
   # preparation phase to process tokens intended for this layer and remove
   # them from the token stream.
   prepare_token(pp)
   if pp.pp_include != nil:
      get_include_token(pp, tok)
   elif len(pp.error_tokens) > 0:
      tok = pp.error_tokens.pop()
   elif len(pp.context_stack) > 0:
      get_context_token(pp, tok)
   else:
      get_source_token(pp, tok)
