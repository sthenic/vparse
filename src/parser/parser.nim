import streams
import strutils

import ../lexer/lexer
import ../lexer/identifier

import ./ast


type
   Parser* = object
      lex: Lexer
      tok: Token

const
   UnexpectedToken = "Unexpected token '$1'"
   UnsupportedToken = "Unsupported token '$1'"


proc open_parser*(p: var Parser, cache: IdentifierCache, filename:
                  string, s: Stream) =
   init(p.tok)
   open_lexer(p.lex, cache, filename, s)


proc close_parser*(p: var Parser) =
   close_lexer(p.lex)


proc get_token*(p: var Parser) =
   get_token(p.lex, p.tok)


proc new_line_info(p: Parser): TLineInfo =
   if p.tok.line < int(high(uint16)):
      result.line = uint16(p.tok.line)
   else:
      result.line = high(uint16)

   if p.tok.col < int(high(int16)):
      result.col = int16(p.tok.col)
   else:
      result.col = -1


proc new_node(p: Parser, `type`: NodeType): PNode =
   result = new_node(`type`, new_line_info(p))


proc new_identifier_node(p: Parser, `type`: NodeType): PNode =
   result = new_node(p, `type`)
   result.identifier = p.tok.identifier


proc new_inumber_node(p: Parser, `type`: NodeType, inumber: BiggestInt,
                      raw: string, base: NumericalBase, size: int): PNode =
   result = new_node(p, `type`)
   result.inumber = inumber
   result.iraw = raw
   result.base = base
   result.size = size


proc new_fnumber_node(p: Parser, `type`: NodeType, fnumber: BiggestFloat,
                      raw: string): PNode =
   result = new_node(p, `type`)
   result.fnumber = fnumber
   result.fraw = raw


proc new_error_node(p: Parser, msg: string, args: varargs[string, `$`]): PNode =
   result = new_node(p, NtError)
   result.msg = format(msg, args)


template expect_token(p: Parser, kinds: set[TokenType]): untyped =
   if p.tok.type notin kinds:
      return new_error_node(p, "Expected tokens: $1, got $2.", kinds, p.tok)


template expect_token(p: Parser, kind: TokenType): untyped =
   if p.tok.type != kind:
      return new_error_node(p, "Expected token: $1, got $2.", kind, p.tok)


template unexpected_token(p: Parser): PNode =
   new_error_node(p, "Unexpected token '$1'.", p.tok)


# Forward declarations
proc parse_constant_expression(p: var Parser): PNode


proc parse_attribute_instance(p: var Parser): PNode =
   result = new_node(p, NtAttributeInst)
   # FIXME: Properly handle this, don't just eat past it.
   while p.tok.type notin {TkRparenStar, TkEndOfFile}:
      get_token(p)

   if p.tok.type == TkRparenStar:
      get_token(p)


proc parse_range(p: var Parser): PNode =
   result = new_node(p, NtRange)

   # FIXME: Actual implementation
   get_token(p)
   while true:
      case p.tok.type
      of TkRbracket:
         get_token(p)
         break
      of TkEndOfFile:
         break
      else:
         get_token(p)


proc parse_constant_min_typ_max_expression(p: var Parser): PNode =
   result = new_node(p, NtConstantMinTypMaxExpression)

   get_token(p)
   add(result.sons, parse_constant_expression(p))

   # If there's no ':' following the first constant expression, we stop.
   if p.tok.type == TkColon:
      get_token(p)
      add(result.sons, parse_constant_expression(p))
      expect_token(p, TkColon)

      get_token(p)
      add(result.sons, parse_constant_expression(p))

   # Expect a closing parenthesis.
   expect_token(p, TkRparen)
   get_token(p)


# TODO: Remove if unused
proc parse_constant_function_call(p: var Parser): PNode =
   result = new_node(p, NtConstantFunctionCall)

   expect_token(p, TkSymbol)
   add(result.sons, new_identifier_node(p, NtFunctionIdentifier))

   # FIXME: Make this into a function returning seq[PNode]
   while p.tok.type == TkLparenStar:
      add(result.sons, parse_attribute_instance(p))

   expect_token(p, TkLparen)

   # FIXME: Make this into a function (shared w/ parse_constant_concatenation)
   get_token(p)
   while true:
      add(result.sons, parse_constant_expression(p))
      case p.tok.type
      of TkComma:
         get_token(p)
      of TkRparen:
         get_token(p)
         break
      else:
         break


proc parse_constant_concatenation(p: var Parser): PNode =
   result = new_node(p, NtConstantConcat)
   get_token(p)
   while true:
      add(result.sons, parse_constant_expression(p))
      case p.tok.type
      of TkComma:
         get_token(p)
      of TkRbrace:
         get_token(p)
         break
      else:
         break


proc parse_constant_multiple_or_regular_concatenation(p: var Parser): PNode =
   get_token(p)
   let first = parse_constant_expression(p)

   case p.tok.type
   of TkLbrace:
      # We're parsing a constant multiple concatenation.
      result = new_node(p, NtConstantMultipleConcat)
      add(result.sons, first)
      add(result.sons, parse_constant_concatenation(p))
      # Expect a closing brace.
      expect_token(p, TkRbrace)
      get_token(p)
   of TkComma:
      # We're parsing a constant concatenation where the entry we parsed earlier
      # is the first of several. Parse the rest and add these to the sons on
      # this level.
      result = new_node(p, NtConstantConcat)
      add(result.sons, first)
      add(result.sons, parse_constant_concatenation(p).sons)
   of TkRbrace:
      # A constant concatenation that only contains the entry we parsed earlier.
      result = new_node(p, NtConstantConcat)
      add(result.sons, first)
   else:
      return new_error_node(p, UnexpectedToken, p.tok)


proc parse_number(p: var Parser): PNode =
   # FIXME: Improve structure.
   let t = p.tok
   case t.type
   of TkIntLit:
      result = new_inumber_node(p, NtIntLit, t.inumber, t.literal, t.base, t.size)
   of TkUIntLit:
      result = new_inumber_node(p, NtUIntLit, t.inumber, t.literal, t.base, t.size)
   of TkAmbIntLit:
      result = new_inumber_node(p, NtAmbIntLit, t.inumber, t.literal, t.base, t.size)
   of TkAmbUIntLit:
      result = new_inumber_node(p, NtAmbUIntLit, t.inumber, t.literal, t.base, t.size)
   of TkRealLit:
      result = new_fnumber_node(p, NtRealLit, t.fnumber, t.literal)
   else:
      return new_error_node(p, "Expected a number, got '$1'.", p.tok)

   get_token(p)


proc parse_constant_primary_identifier(p: var Parser): PNode =
   expect_token(p, TkSymbol)
   let identifier = new_identifier_node(p, NtIdentifier)

   get_token(p)
   case p.tok.type
   of TkLparenStar, TkLparen:
      # Parsing a constant function call.
      result = new_node(p, NtConstantFunctionCall)
      add(result.sons, identifier)

      # FIXME: Make this into a function returning seq[PNode]
      while p.tok.type == TkLparenStar:
         add(result.sons, parse_attribute_instance(p))

      expect_token(p, TkLparen)

      # FIXME: Make this into a function (shared w/ parse_constant_concatenation)
      get_token(p)
      while true:
         add(result.sons, parse_constant_expression(p))
         case p.tok.type
         of TkComma:
            get_token(p)
         of TkRparen:
            get_token(p)
            break
         else:
            break
   else:
      # We've parsed a simple identifier.
      result = identifier


proc parse_constant_primary(p: var Parser): PNode =
   result = new_node(p, NtConstantPrimary)

   case p.tok.type
   of TkLbrace:
      add(result.sons, parse_constant_multiple_or_regular_concatenation(p))
   of TkLparen:
      add(result.sons, parse_constant_min_typ_max_expression(p))
   of TkSymbol:
      # FIXME: We have no way of knowing if this is a _valid_ (constant) symbol:
      #        genvar, param or specparam.
      add(result.sons, parse_constant_primary_identifier(p))
   of NumberTokens:
      add(result.sons, parse_number(p))
   else:
      return new_error_node(p, "Unexpected token '$1'.", p.tok)


proc parse_constant_expression(p: var Parser): PNode =
   result = new_node(p, NtConstantExpression)
   add(result.sons, parse_constant_primary(p))


proc parse_parameter_assignment(p: var Parser): PNode =
   result = new_node(p, NtParamAssignment)

   expect_token(p, TkSymbol)
   add(result.sons, new_identifier_node(p, NtParameterIdentifier))

   get_token(p)
   expect_token(p, TkEquals)

   get_token(p)
   add(result.sons, parse_constant_expression(p))


proc parse_list_of_parameter_assignments(p: var Parser): seq[PNode] =
   while true:
      add(result, parse_parameter_assignment(p))
      case p.tok.type
      of TkComma:
         get_token(p)
      else:
         break


proc parse_parameter_declaration(p: var Parser): PNode =
   result = new_node(p, NtParameterDecl)

   expect_token(p, TkParameter)
   get_token(p)

   # Check for type and range specifiers.
   case p.tok.type
   of TkInteger, TkReal, TkRealtime, TkTime:
      add(result.sons, new_identifier_node(p, NtType))
      get_token(p)
   of TkSigned:
      add(result.sons, new_identifier_node(p, NtType))
      get_token(p)
      if p.tok.type == TkLbracket:
         add(result.sons, parse_range(p))
   of TkLbracket:
      add(result.sons, parse_range(p))
   of TkSymbol:
      discard
   else:
      return new_error_node(p, "Unexpected token '$1'.", p.tok)

   # Try parsing a list of parameter assignments.
   add(result.sons, parse_list_of_parameter_assignments(p))


proc parse_parameter_port_list*(p: var Parser): PNode =
   result = new_node(p, NtModuleParameterPortList)

   get_token(p)
   expect_token(p, TkLparen)

   # Parse the contents.
   get_token(p)
   while true:
      if p.tok.type == TkRparen:
         get_token(p)
         break

      add(result.sons, parse_parameter_declaration(p))
      case p.tok.type
      of TkComma, TkSemicolon:
         get_token(p)
      else:
         # FIXME: Should this be an error? We potentially overwrite the entire
         # seq of sons, some of which could be okay.
         # result = new_error_node(p, UnexpectedToken, p.tok)
         break


proc parse_module_declaration(p: var Parser, attributes: seq[PNode]): PNode =
   result = new_node(p, NtModuleDecl)
   if len(attributes) > 0:
      add(result.sons, attributes)

   # Expect an idenfitier as the first token after the module keyword.
   get_token(p)
   expect_token(p, TkSymbol)
   add(result.sons, new_identifier_node(p, NtModuleIdentifier))

   # FIXME: Parse the optional parameter port list.
   get_token(p)
   if p.tok.type == TkHash:
      add(result.sons, parse_parameter_port_list(p))

   # FIXME: Parse the optional list or ports/port declarations. This will
   #        determine what to allow as the module contents.

   # FIXME: Expect a semicolon.

   # FIXME: Parse module items or non_port

   # FIXME: Expect endmodule.

   # FIXME: Properly handle this, don't just eat past it.
   while true:
      case p.tok.type
      of TkEndmodule:
         get_token(p)
         break
      of TkEndOfFile:
         break
      else:
         get_token(p)


proc assume_source_text(p: var Parser): PNode =
   # Parse source text (A.1.3)
   # Check for attribute instances.
   var attributes: seq[PNode]
   while p.tok.type == TkLparenStar:
      add(attributes, parse_attribute_instance(p))

   case p.tok.type
   of TkModule, TkMacromodule:
      result = parse_module_declaration(p, attributes)
   of TkPrimitive:
      result = unexpected_token(p) # FIXME: Actually unsupported for now
      get_token(p)
   else:
      result = unexpected_token(p)
      get_token(p)


proc parse_all*(p: var Parser): PNode =
   result = new_node(p, NtSourceText) # FIXME: Proper init value

   get_token(p)
   while p.tok.type != TkEndOfFile:
      let n = assume_source_text(p)
      # echo "Got node ", n
      if n.type != NtEmpty:
         add(result.sons, n)


proc parse_string*(s: string, cache: IdentifierCache,
                   filename: string = ""):  PNode =
   var p: Parser
   var ss = new_string_stream(s)
   open_parser(p, cache, filename, ss)
   result = parse_all(p)
   close_parser(p)


# Procedure used by the test framework to parse subsets of the grammar.
proc parse_specific_grammar*(s: string, cache: IdentifierCache,
                             `type`: NodeType, filename: string = ""): PNode =
   var p: Parser
   var ss = new_string_stream(s)
   open_parser(p, cache, filename, ss)

   var parse_proc: proc (p: var Parser): PNode
   case `type`
   of NtModuleParameterPortList:
      parse_proc = parse_parameter_port_list
   else:
      parse_proc = nil

   if parse_proc != nil:
      # Expect only one top-level statement per call.
      get_token(p)
      result = parse_proc(p)
   else:
      result = new_error_node(p, "Unsupported specific grammar '$1'.", $`type`)

   close_parser(p)

