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
   Define* = object
      name*: Token
      comment*: Token
      loc*: Location
      tokens*: seq[Token]
      parameters*: seq[Token]
      is_expandable: bool

   Context = object
      def: Define
      tokens: seq[Token]
      idx: int

   Preprocessor* = object
      lex: Lexer
      lex_tok: Token
      lex_tok_next: Token
      include_tok: Token
      tok: Token
      tok_next: Token
      comment: Token
      endif_semaphore: int
      defines: Table[string, Define]
      include_paths: seq[string]
      context_stack: seq[Context]
      error_tokens: seq[Token]
      include_pp: ref Preprocessor
      locations: Locations

   PreprocessorError = object of ValueError
      loc: Location


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


proc merge(x: var Table[string, Define], y: Table[string, Define]) =
   # TODO: Perhaps generate a warning if a define overwrites another entry?
   for k, v in pairs(y):
      x[k] = v


proc new_preprocessor_error(loc: Location, msg: string,
                            args: varargs[string, `$`]): ref PreprocessorError =
   new result
   result.msg = format(msg, args)
   result.loc = loc


proc add_error_token(pp: var Preprocessor, loc: Location, msg: string, args: varargs[string, `$`]) =
   add(pp.error_tokens, new_error_token(loc, msg, args))


proc add_error_token(pp: var Preprocessor, msg: string, args: varargs[string, `$`]) =
   add_error_token(pp, pp.lex_tok.loc, msg, args)


# Forward declaration of public interface.
proc get_token_raw(pp: var Preprocessor, tok: var Token)
proc get_token*(pp: var Preprocessor, tok: var Token)


proc get_lexer_token(pp: var Preprocessor, ignore_comments = false) =
   ## Internal token consumer. Reads a token from the lexer and stores the result
   ## in the local ``tok`` variable. If ``ignore_comments`` is ``true``, comments
   ## are removed from the stream.
   # Comments immediately preceding `define directives are always removed under
   # the assumption that they document the directive. This feature requires us
   # to maintain a look-ahead buffer of one token.
   init(pp.comment)
   pp.lex_tok = pp.lex_tok_next
   if pp.lex_tok_next.kind != TkEndOfFile:
      get_token(pp.lex, pp.lex_tok_next)
      if ignore_comments:
         while pp.lex_tok_next.kind in {TkComment, TkBlockComment}:
            get_token(pp.lex, pp.lex_tok_next)
      elif pp.lex_tok.kind in {TkComment, TkBlockComment}:
         # We've just assigned a comment to the internal token register. If the
         # next token is a `define, we have to redirect the comment token to
         # the comment register instead, removing it from the token stream.
         if pp.lex_tok_next.kind == TkDirective and pp.lex_tok_next.identifier.s == "define":
            pp.comment = pp.lex_tok
            pp.lex_tok = pp.lex_tok_next
            get_token(pp.lex, pp.lex_tok_next)


proc handle_external_define(pp: var Preprocessor, external_define: string) =
   # Open a local lexer to extract the tokens so we can initialize a define
   # entry for the incoming external define. An external define is normally
   # specified as a command line option or via a global configuration state.
   # The file id is '0' for these types of entries.
   var lex: Lexer
   var s = split(external_define, '=', maxsplit = 1).join(" ")
   open_lexer(lex, pp.lex.cache, new_string_stream(s), "", 0)

   # Read out the define name as a token.
   var tok: Token
   get_token(lex, tok)

   # External defines only support object-like macros.
   var def: Define
   init(def.comment)
   def.is_expandable = true
   def.name = tok
   def.loc = tok.loc
   def.tokens = get_all_tokens(lex)
   pp.defines[def.name.identifier.s] = def
   close_lexer(lex)


template open_preprocessor_common(pp: var Preprocessor, cache: IdentifierCache,
                                  s: Stream, file_map: FileMap,
                                  locations: Locations,
                                  include_paths: openarray[string]) =
   ## Open the preprocessor and prepare to process the target file.
   init(pp.lex_tok)
   init(pp.lex_tok_next)
   init(pp.include_tok)
   init(pp.tok)
   init(pp.tok_next)
   init(pp.comment)
   pp.endif_semaphore = 0
   pp.defines = init_table[string, Define](64)
   pp.include_paths = new_seq_of_cap[string](len(pp.include_paths))
   pp.context_stack = new_seq_of_cap[Context](32)
   pp.error_tokens = new_seq_of_cap[Token](32)
   pp.include_pp = nil
   pp.locations = locations

   add(pp.include_paths, include_paths)
   open_lexer(pp.lex, cache, s, file_map.filename,
              add_file_map(pp.locations, file_map))
   # We have to call the internal lexer token consumer twice to correctly set up
   # the token chain.
   get_lexer_token(pp)
   get_lexer_token(pp)


proc open_preprocessor*(pp: var Preprocessor, cache: IdentifierCache,
                        s: Stream, file_map: FileMap,
                        locations: Locations,
                        include_paths: openarray[string],
                        external_defines: openarray[string]) =
   ## Open the preprocessor and prepare to process the target file.
   open_preprocessor_common(pp, cache, s, file_map, locations, include_paths)

   for def in external_defines:
      handle_external_define(pp, def)

   var tok: Token
   get_token(pp, tok)
   get_token(pp, tok)


proc open_preprocessor(pp: var Preprocessor, cache: IdentifierCache,
                                    s: Stream, file_map: FileMap,
                                    locations: Locations,
                                    include_paths: openarray[string],
                                    external_defines: Table[string, Define]) =
   ## Internal proc to set up a preprocessor for an include file.
   open_preprocessor_common(pp, cache, s, file_map, locations, include_paths)
   merge(pp.defines, external_defines)
   var tok: Token
   get_token(pp, tok)
   get_token(pp, tok)


proc close_preprocessor*(pp: var Preprocessor) =
   ## Close the preprocessor.
   close_lexer(pp.lex)


proc handle_parameter_list(pp: var Preprocessor, def: var Define) =
   ## Collect the parameter list of ``def`` from the source buffer. When this
   ## proc returns, the closing parenthesis has been removed from the buffer.
   # Skip over the opening parenthesis and collect a list of comma-separated
   # identifiers.
   get_lexer_token(pp, true)
   while true:
      if pp.lex_tok.kind != TkSymbol:
         break
      add(def.parameters, pp.lex_tok)
      get_lexer_token(pp, true)
      if (pp.lex_tok.kind != TkComma):
         break
      get_lexer_token(pp, true)

   # Expect a closing parenthesis but don't remove the token. The caller needs
   # to know the position of the token.
   if pp.lex_tok.kind != TkRparen:
      add_error_token(pp, ExpectedToken, TkRparen, pp.lex_tok)


proc immediately_follows(x, y: Token): bool =
   ## Check if ``x`` immediately follows ``y`` in the source buffer.
   assert(y.kind == TkSymbol)
   return x.loc.line == y.loc.line and x.loc.col == (y.loc.col + len(y.identifier.s))


proc handle_define(pp: var Preprocessor) =
   ## Handle the ``define`` directive.
   var def: Define
   def.is_expandable = true
   def.comment = pp.comment

   # Scan over `define.
   let def_line = pp.lex_tok.loc.line
   get_lexer_token(pp)
   def.loc = pp.lex_tok.loc
   # Expect the macro name on the same line as the `define directive.
   if pp.lex_tok.kind != TkSymbol:
      add_error_token(pp, InvalidMacroName, pp.lex_tok)
      get_lexer_token(pp)
      return
   elif pp.lex_tok.loc.line != def_line:
      add_error_token(pp, DirectiveArgLine, pp.lex_tok, "`define")
      get_lexer_token(pp)
      return
   def.name = pp.lex_tok
   var last_tok_line = def.loc.line

   if def.name.identifier.s in Directives:
      add_error_token(pp, RedefineProtected, def.name)
      get_lexer_token(pp)
      return

   # If the next character is '(', and it follows the macro name w/o any
   # whitespace, this is a function like macro and we attempt to read the
   # parameter list.
   get_lexer_token(pp)
   if pp.lex_tok.kind == TkLparen and immediately_follows(pp.lex_tok, def.name):
      handle_parameter_list(pp, def)
      last_tok_line = pp.lex_tok.loc.line
      get_lexer_token(pp)

   var include_newline = false
   while true:
      case pp.lex_tok.kind
      of TkEndOfFile:
         break
      of TkComment, TkBlockComment:
         # A one-line comment breaks the replacement list, unless we've scanned
         # over a backslash before this token. In that case, we ignore the
         # comment and continue looking for tokens.
         if not include_newline:
            break
         last_tok_line = pp.lex_tok.loc.line
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
         let line_delta = pp.lex_tok.loc.line - last_tok_line
         if (line_delta > 1) or (line_delta == 1 and not include_newline):
            break
         if pp.lex_tok.kind == TkDirective and pp.lex_tok.identifier.s == def.name.identifier.s:
            add_error_token(pp, RecursiveDefinition, def.name.identifier.s)
         add(def.tokens, pp.lex_tok)
         last_tok_line = pp.lex_tok.loc.line
         include_newline = false
      get_lexer_token(pp)

   # Add the define object unless there was an error in the `define directive.
   if len(pp.error_tokens) == 0:
      pp.defines[def.name.identifier.s] = def


proc handle_undef(pp: var Preprocessor) =
   # Scan over `undef.
   let undef_line = pp.lex_tok.loc.line
   get_lexer_token(pp)
   # Expect the macro name on the same line as the `undef directive.
   if pp.lex_tok.kind != TkSymbol:
      add_error_token(pp, InvalidMacroName, pp.lex_tok)
      get_lexer_token(pp)
      return
   elif pp.lex_tok.loc.line != undef_line:
      add_error_token(pp, DirectiveArgLine, pp.lex_tok, "`undef")
      get_lexer_token(pp)
      return
   # FIXME: Undefining a macro that doesn't exist should result in an error node.
   #        Should turn up as a warning though.
   # The del() proc does nothing if the key does not exist.
   del(pp.defines, pp.lex_tok.identifier.s)
   get_lexer_token(pp)


proc handle_undefall(pp: var Preprocessor) =
   # Scan over `undefall
   get_lexer_token(pp)
   clear(pp.defines)


proc get_include_file(pp: Preprocessor, filename: string): string =
   ## Return the full path to the file with name/path ``filename``.
   # FIXME: Environment variable for include path?
   # If the file exists relative to the parent directory of the current file,
   # we're done right away. Otherwise, we go through the include paths. If the
   # path ends with '**', that implies a recursive search through all the
   # directories. The first matching file is returned so the order is important.
   const RECURSIVE_TAIL = DirSep & "**"
   let path_relative_parent_dir = parent_dir(pp.lex.filename) / filename
   if file_exists(path_relative_parent_dir):
      return expand_filename(path_relative_parent_dir)
   else:
      for path in pp.include_paths:
         if ends_with(path, RECURSIVE_TAIL):
            var head = path
            remove_suffix(head, RECURSIVE_TAIL)
            # Since the recursive walk will not yield for the root directory, we
            # check that manually before we begin.
            let tmp = head / filename
            if file_exists(tmp):
               return expand_filename(tmp)
            for tail in walk_dir_rec(head, yield_filter = {pcDir}, relative = true):
               let tmp = head / tail / filename
               if file_exists(tmp):
                  return expand_filename(tmp)
         else:
            let tmp = path / filename
            if file_exists(tmp):
               return expand_filename(tmp)


proc open_include_file(pp: var Preprocessor, loc: Location, filename: string) =
   # Create a new preprocessor for the include file. All the defines known at
   # this point gets passed on to the preprocessor handling the include file.
   # We also create a file map entry which includes the location of the `include
   # directive. This will allow any token consumer to trace tokens across files,
   # similar to what macro maps allow.
   let fs = new_file_stream(filename)
   new pp.include_pp
   open_preprocessor(pp.include_pp[], pp.lex.cache, fs, new_file_map(filename, loc),
                     pp.locations, pp.include_paths, pp.defines)
   get_token(pp.include_pp[], pp.include_tok)



proc handle_quoted_include(pp: var Preprocessor, loc: Location) =
   var filename = pp.lex_tok.literal
   let loc = pp.lex_tok.loc
   let path = get_include_file(pp, filename)
   get_lexer_token(pp)
   if len(path) == 0:
      add_error_token(pp, loc, CannotOpenFile, filename)
      return

   open_include_file(pp, loc, path)
   # FIXME: Ensure that the next token is on a different line?


proc handle_angled_include(pp: var Preprocessor, loc: Location) =
   # Scan over '<' but remember the position. We'll use this to anchor any
   # eventual error.
   let loc = pp.lex_tok.loc
   get_lexer_token(pp)
   var filename = ""
   var col = pp.lex_tok.loc.col
   var error = false
   while true:
      if pp.lex_tok.kind == TkOperator and pp.lex_tok.identifier.s == ">":
         get_lexer_token(pp)
         break
      elif pp.lex_tok.kind == TkEndOfFile:
         add_error_token(pp, "The file ended while scanning for an include path.")
         error = true
      elif pp.lex_tok.loc.line != loc.line:
         add_error_token(pp, "Unexpected token $1 while scanning for an include path.", pp.lex_tok)
         error = true
      elif pp.lex_tok.loc.col != col:
         add_error_token(pp, loc, "Invalid include path: cannot contain whitespace.")
         error = true

      if error:
         # FIXME: Remove the rest of the tokens on the same line.
         return

      let part = raw(pp.lex_tok)
      add(filename, part)
      col = pp.lex_tok.loc.col + len(part).int16
      get_lexer_token(pp)

   # FIXME: Potentially another proc that searches another set of include
   #        directories. But let's go with the same rules as quoted paths
   #        for now.
   let path = get_include_file(pp, filename)
   if len(path) == 0:
      add_error_token(pp, loc, CannotOpenFile, filename)
      return
   open_include_file(pp, loc, path)
   # FIXME: Ensure that the next token is on a different line?


proc handle_include(pp: var Preprocessor) =
   # Skip over `include.
   let include_loc = pp.lex_tok.loc
   get_lexer_token(pp)

   if pp.lex_tok.loc.line != include_loc.line:
      add_error_token(pp, DirectiveArgLine, pp.lex_tok, "`include")
      get_lexer_token(pp)
   elif pp.lex_tok.kind == TkStrLit:
      handle_quoted_include(pp, include_loc)
   elif pp.lex_tok.kind == TkOperator and pp.lex_tok.identifier.s == "<":
      handle_angled_include(pp, include_loc)
   else:
      # FIXME: Error message, not just expecting a strlit anymore.
      add_error_token(pp, ExpectedToken, TkStrLit, pp.lex_tok)
      get_lexer_token(pp)


proc handle_else(pp: var Preprocessor) =
   if pp.endif_semaphore == 0:
      add_error_token(pp, UnexpectedToken, pp.lex_tok)
      get_lexer_token(pp)
      return

   # If we're in this proc then the preprocessor has encountered an `else
   # while reading tokens from an _active_ `ifdef/`ifndef/`elif branch. Now
   # we have to remove all the subsequent tokens from the stream until we
   # hit the end of the file (an error condition) or a closing `endif
   # directive.
   let semaphore_reference = pp.endif_semaphore
   while true:
      get_lexer_token(pp)
      case pp.lex_tok.kind
      of TkEndOfFile:
         # The error is added in prepare_token_raw().
         break
      of TkDirective:
         case pp.lex_tok.identifier.s
         of "ifdef", "ifndef":
            inc(pp.endif_semaphore)
         of "endif":
            if pp.endif_semaphore == semaphore_reference:
               get_lexer_token(pp)
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
      add_error_token(pp, UnexpectedToken, pp.lex_tok)
   else:
      dec(pp.endif_semaphore)
   get_lexer_token(pp)


proc handle_ifdef(pp: var Preprocessor, invert: bool = false) =
   # Skip over `ifdef.
   let line = pp.lex_tok.loc.line
   var label = pp.lex_tok.identifier.s
   get_lexer_token(pp)

   if pp.lex_tok.kind != TkSymbol:
      add_error_token(pp, ExpectedToken, TkSymbol, pp.lex_tok)
      get_lexer_token(pp)
      return
   elif pp.lex_tok.loc.line != line:
      add_error_token(pp, DirectiveArgLine, pp.lex_tok, "`" & label)
      get_lexer_token(pp)
      return

   var take_if_branch = pp.lex_tok.identifier.s in pp.defines
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
      get_lexer_token(pp)
      inc(pp.endif_semaphore)
   else:
      while true:
         get_lexer_token(pp)
         case pp.lex_tok.kind
         of TkEndOfFile:
            add_error_token(pp, UnexpectedEndOfFile)
            break
         of TkDirective:
            case pp.lex_tok.identifier.s
            of "ifdef", "ifndef":
               inc(pp.endif_semaphore)
            of "elsif":
               handle_ifdef(pp)
               break
            of "else":
               if pp.endif_semaphore == semaphore_reference:
                  get_lexer_token(pp)
                  inc(pp.endif_semaphore)
                  break
            of "endif":
               if pp.endif_semaphore == semaphore_reference:
                  get_lexer_token(pp)
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

   # Expect an opening parenthesis.
   var tok: Token
   get_token_raw(pp, tok)
   if tok.kind != TkLparen:
      raise new_preprocessor_error(tok.loc, ExpectedToken, TkLparen, tok)
   let paren_loc = tok.loc

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
      get_token_raw(pp, tok)
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
         raise new_preprocessor_error(tok.loc, UnexpectedEndOfFile)
      else:
         discard

      # If we haven't broken the control flow the token should be included in
      # the token list.
      add(token_list, tok)

   let nof_collected_arguments = idx + 1
   if nof_collected_arguments != nof_arguments:
      raise new_preprocessor_error(paren_loc, WrongNumberOfArguments,
                                   nof_arguments, nof_collected_arguments)


proc add_token(tokens: var seq[Token], lpairs: var seq[LocationPair],
               file: int, x, y: Location, tok: Token, whitespace: int) =
   var t = tok
   t.loc = Location(file: int32(file), line: uint16(len(lpairs)), col: 0)
   t.whitespace = whitespace
   add(tokens, t)
   add(lpairs, (x, y))


proc enter_macro_context(pp: var Preprocessor, def: var Define, loc: Location, whitespace: int) =
   ## Push a new macro context onto the context stack. This proc expects that
   ## the macro token (``def.name``) has been removed from the token stream.
   # Expect arguments to follow a function-like macro. Once we've collected the
   # arguments, we perform parameter substitution in the macro's replacement
   # list. Once parameter substitution is complete, we walk through the list of
   # tokens again, this time looking for the special SystemVerilog preprocessor
   # tokens.
   var arguments: Table[string, seq[Token]]
   var macro_map: MacroMap
   macro_map.locations = new_seq_of_cap[LocationPair](len(def.tokens))
   macro_map.name = def.name.identifier.s
   macro_map.define_loc = def.loc
   macro_map.expansion_loc = loc
   if def.comment.kind in {TkComment, TkBlockComment}:
      macro_map.comment = def.comment.literal

   var expansion_list: seq[Token]
   if len(def.parameters) > 0:
      # Collecting arguments can generate errors since a certain syntax is
      # expected. We convert exceptions into error tokens and stop the function
      # in that case.
      try:
         arguments = collect_arguments(pp, def)
      except PreprocessorError as e:
         add_error_token(pp, e.loc, e.msg)
         return

      let file = next_macro_map_index(pp.locations)
      for tok in def.tokens:
         if tok.kind == TkSymbol and tok.identifier.s in arguments:
            # Go through the replacement list for the argument, making a copy
            # with an updated position and adding an entry to the macro map. The
            # first token inherits the leading whitespace of the parameter token.
            for i, rtok in arguments[tok.identifier.s]:
               let whitespace = if i == 0:
                  tok.whitespace
               else:
                  rtok.whitespace
               add_token(expansion_list, macro_map.locations, file, rtok.loc, tok.loc, rtok, whitespace)
         else:
            add_token(expansion_list, macro_map.locations, file, tok.loc, tok.loc, tok, tok.whitespace)
   else:
      let file = next_macro_map_index(pp.locations)
      for tok in def.tokens:
         add_token(expansion_list, macro_map.locations, file, tok.loc, tok.loc, tok, tok.whitespace)

   # Avoid adding an empty replacement list. We still have to read any arguments
   # though.
   if len(expansion_list) == 0:
      return

   # The first token in the expansion list inherits the leading whitespace from
   # the macro usage directive. The return statement just above protects this
   # access.
   expansion_list[0].whitespace = whitespace

   # Add the macro map to the location tree.
   add_macro_map(pp.locations, macro_map)

   # Add the context entry to the top of the stack and disable the macro from
   # expanding until the context is popped.
   def.is_expandable = false
   let context = Context(def: def, tokens: expansion_list, idx: 0)
   add(pp.context_stack, context)


proc handle_line(pp: var Preprocessor) =
   # TODO: Implement
   let line = pp.lex_tok.loc.line
   add_error_token(pp, "The `line directive is currently not supported.")
   while true:
      get_lexer_token(pp)
      if pp.lex_tok.kind == TkEndOfFile or pp.lex_tok.loc.line - line > 0:
         break


proc handle_insert_line(pp: var Preprocessor) =
   # We replace the current lexer token (which should be the __LINE__ directive)
   # with an unsized integer literal holding the current line number.
   let loc = pp.lex_tok.loc
   init(pp.lex_tok)
   pp.lex_tok.kind = TkIntLit
   pp.lex_tok.loc = loc
   pp.lex_tok.size = -1
   pp.lex_tok.base = Base10
   pp.lex_tok.literal = $loc.line


proc handle_insert_file(pp: var Preprocessor) =
   # We replace the current lexer token (which should be the __FILE__ directive)
   # with a string literal holding the full path to the current file.
   let loc = pp.lex_tok.loc
   init(pp.lex_tok)
   pp.lex_tok.kind = TkStrLit
   pp.lex_tok.loc = loc
   pp.lex_tok.literal = pp.lex.filename


proc handle_directive(pp: var Preprocessor): bool =
   result = true
   case pp.lex_tok.identifier.s
   of "define":
      handle_define(pp)
   of "undef":
      handle_undef(pp)
   of "include":
      # TODO: Have to move this to the prepare_token() proc to support expanding
      # arguments to `include.
      handle_include(pp)
   of "ifdef":
      handle_ifdef(pp)
   of "ifndef":
      handle_ifdef(pp, invert = true)
   of "else", "elsif":
      handle_else(pp)
   of "endif":
      handle_endif(pp)
   of "line":
      handle_line(pp)
   of "resetall":
      # The `resetall directive should propagate out of the preprocessor since
      # the implementation of the various directive handlers are spread between
      # the preprocessor and the parser.
      clear(pp.defines)
      result = false
   of "__FILE__":
      handle_insert_file(pp)
   of "__LINE__":
      handle_insert_line(pp)
   of "undefall":
      handle_undefall(pp)
   else:
      # If we don't recognize the directive, check if it's a macro usage which
      # has a matching entry in the macro table. Otherwise, leave the token as
      # it is. The parser will deal with it.
      let macro_name = pp.lex_tok.identifier.s
      if macro_name in pp.defines:
         let loc = pp.lex_tok.loc
         let whitespace = pp.lex_tok.whitespace
         get_lexer_token(pp)
         enter_macro_context(pp, pp.defines[macro_name], loc, whitespace)
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
      pp.defines[context.def.name.identifier.s].is_expandable = enable


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
   # Copy the token at the cursor position and then call the internal token
   # consumer to correctly advance the cursor.
   tok = pp.lex_tok
   get_lexer_token(pp)


proc get_include_token(pp: var Preprocessor, tok: var Token) =
   tok = pp.include_tok
   get_token(pp.include_pp[], pp.include_tok)


proc is_macro_defined(pp: Preprocessor, tok: Token): bool =
   return tok.kind == TkDirective and tok.identifier.s in pp.defines and
          pp.defines[tok.identifier.s].is_expandable


proc prepare_token_raw(pp: var Preprocessor) =
   # When this proc returns, the preprocessor is in a position to return a token
   # from either the include file, the topmost context entry or the source
   # buffer. We get to this point by examining the next token from the active
   # source to see if it should be consumed by the preprocessor or not.
   if pp.include_pp != nil:
      # The token representing the end of the include file does not propagate
      # to the caller. We use this to close the include file's preprocessor
      # and recursively call this function to prepare a token from one of the
      # other sources. Additionally, any defines active at the end of the
      # processed include file is added to the defines on this level.
      if pp.include_tok.kind == TkEndOfFile:
         # FIXME: Include file stream is dangling and not being closed.
         close_preprocessor(pp.include_pp[])
         merge(pp.defines, pp.include_pp.defines)
         pp.include_pp = nil
         prepare_token_raw(pp)
   elif len(pp.context_stack) > 0:
      while true:
         let next_tok = top_context_token(pp)
         if is_macro_defined(pp, next_tok):
            # Read past the macro name.
            inc_context_stack(pp)
            # FIXME: possibly all the directives? handle_directive()?
            enter_macro_context(pp, pp.defines[next_tok.identifier.s], next_tok.loc,
                                next_tok.whitespace)
         else:
            break
   else:
      while true:
         # If a include file has been set up as a token source we break out of
         # the loop.
         if pp.include_pp != nil:
            prepare_token_raw(pp)
            break

         # If there's an error token to propagate we break out of the loop.
         if len(pp.error_tokens) > 0:
            break

         # If by handling a directive, the context stack is no longer empty, we
         # perform a recursive call to run the code block above. A macro
         # invocation may be the first context token.
         if len(pp.context_stack) > 0:
            prepare_token_raw(pp)
            break

         case pp.lex_tok.kind
         of TkEndOfFile:
            # If we've reached the end of the file, check if it's expected.
            # We could be waiting for an `endif. After we've added the error
            # token we set the semaphore to zero to avoid to keep on generating
            # errors indefinitely.
            if pp.endif_semaphore > 0:
               add_error_token(pp, UnexpectedEndOfFile)
               pp.endif_semaphore = 0
            break
         of TkDirective:
            if not handle_directive(pp):
               break
         else:
            break


proc get_token_raw(pp: var Preprocessor, tok: var Token) =
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
   prepare_token_raw(pp)
   if pp.include_pp != nil:
      get_include_token(pp, tok)
   elif len(pp.error_tokens) > 0:
      tok = pop(pp.error_tokens)
   elif len(pp.context_stack) > 0:
      get_context_token(pp, tok)
   else:
      get_source_token(pp, tok)


proc merge_macro_sized_integer_literal(pp: var Preprocessor) =
   # First we unroll the location of the first token (which is guaranteed to be
   # the result of at least one macro expansion) until we reach the same file
   # level as the second token---the unsized integer literal we're about to
   # modify.
   let expansion_loc = unroll_to_same_file(pp.locations, pp.tok.loc, pp.tok_next.loc.file)
   if expansion_loc == InvalidLocation:
      return

   # However, we want to filter out situations where the tokens are separated by
   # whitespace. For example, we want to merge `WIDTH'hF0 but leave `WIDTH 'hF0
   # intact. To do this we convert the the expansion location (now representing
   # the first token) and the location of the second token to their physical
   # coordinates and check the distance between them. '+1' compensates for the
   # backtick character.
   let name = pp.locations.macro_maps[find_map_expanded_at(pp.locations, expansion_loc)].name
   let ploc = to_physical(pp.locations, expansion_loc)
   let ploc_next = to_physical(pp.locations, pp.tok_next.loc)
   if ploc.col + len(name) + 1 != ploc_next.col:
      return

   var size: int
   try:
      size = parse_int(pp.tok.literal)
   except ValueError:
      return
   pp.tok_next.size = size
   pp.tok_next.loc = expansion_loc
   pp.tok = pp.tok_next
   if pp.tok_next.kind != TkEndOfFile:
      get_token_raw(pp, pp.tok_next)


proc handle_token_pasting(pp: var Preprocessor) =
   # When this proc gets called, pp.tok_next is a double backtick token
   # indicating that the two identifier tokens surrounding it should be glued
   # together. Unless both are identifiers, the operation is a noop and the
   # double backtick character is silently removed. We intentionally avoid
   # modifying the macro map where we potentially could remove the location
   # entries associated with the merged tokens. It's not really necessary since
   # an overdetermined AST is not a problem.
   var tail: Token
   get_token_raw(pp, tail)
   if pp.tok.kind == TkSymbol and tail.kind == TkSymbol and pp.tok.loc.file == tail.loc.file:
      # Even if both symbols are an
      let s = pp.tok.identifier.s & tail.identifier.s
      pp.tok.identifier = get_identifier(pp.lex.cache, s)
      get_token_raw(pp, pp.tok_next)
   else:
      pp.tok_next = tail

   if pp.tok_next.kind == TkDoubleBacktick:
      handle_token_pasting(pp)


proc handle_expanded_string_literal(pp: var Preprocessor) =
   # We read tokens until we encounter the closing '`"' or the end of the file,
   # which is an error. Since we're reconstructing a string literal from lexed
   # tokens, all the whitespace information is gone. We use a cursor that points
   # just past the last character added to the string. This is effectively the
   # length of the string but we try to avoid recomputing it in each iteration.
   let loc = pp.tok.loc
   init(pp.tok)
   pp.tok.kind = TkStrLit
   pp.tok.loc = loc
   while true:
      case pp.tok_next.kind
      of TkEndOfFile:
         pp.tok = new_error_token(loc, UnexpectedEndOfFile)
         break
      of TkBacktickDoubleQuotes:
         get_token_raw(pp, pp.tok_next)
         break
      of TkEscapedDoubleQuotes:
         add(pp.tok.literal, repeat(' ', pp.tok_next.whitespace) & "\"")
      else:
         add(pp.tok.literal, repeat(' ', pp.tok_next.whitespace) & raw(pp.tok_next))

      get_token_raw(pp, pp.tok_next)


proc prepare_token(pp: var Preprocessor) =
   if pp.tok.kind == TkIntLit and pp.tok.size == -1 and
      pp.tok_next.kind in {TkIntLit, TkUIntLit} and pp.tok_next.size == -1 and
      pp.tok.loc.file < 0 and pp.tok_next.loc.file != pp.tok.loc.file:
      # While it's not strictly legal according to the standard, many parsers
      # appear to support a syntax like `WIDTH'hF0 where `WIDTH has been defined as
      # another integer literal. We try to detect the this case and merge the two
      # integer literals by letting the value of the first specify the size of the
      # second. At this point we know that:
      #
      #   - pp.tok holds an unsized (signed) integer literal that is the result
      #     of a macro expansion; and
      #   - pp.tok_next holds an unsized integer literal whose file location is
      #     not the same as pp.tok.
      #
      # and we can try to proceed with the merge.
      merge_macro_sized_integer_literal(pp)
   elif pp.tok_next.kind == TkDoubleBacktick:
      # A double backtick '``' indicates preprocessor token pasting, just like
      # '##' in C.
      handle_token_pasting(pp)
   elif pp.tok.kind == TkBacktickDoubleQuotes:
      # A backtick followed by a double quote '`"' implies a string literal
      # whose contents is subject to the regular rules of expansion.
      handle_expanded_string_literal(pp)


proc get_token*(pp: var Preprocessor, tok: var Token) =
   ## Read a token from the preprocessor ``pp`` into ``tok``.
   # This is the external token interface and sits on top of the internal
   # preprocessor token interface that arbitrates the various token sources.
   # This layer implements a look-ahead buffer of one token to allow us to catch
   # a few special events. These are handled in prepare_token().
   prepare_token(pp)
   tok = pp.tok
   pp.tok = pp.tok_next
   if pp.tok_next.kind != TkEndOfFile:
      get_token_raw(pp, pp.tok_next)
