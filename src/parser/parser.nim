import streams

import ../lexer/lexer
import ../lexer/identifier
import ../utils/log

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


proc error(p: Parser, msg: string, args: varargs[string, `$`]) =
   log.error($p.tok.line & ":" & $p.tok.col & " " & msg, args)


proc new_line_info(p: Parser): TLineInfo =
   if p.tok.line < int(high(uint16)):
      result.line = uint16(p.tok.line)
   else:
      result.line = high(uint16)

   if p.tok.col < int(high(int16)):
      result.col = int16(p.tok.col)
   else:
      result.col = -1


proc new_node(`type`: NodeType, p: Parser): PNode =
   result = new_node(`type`, new_line_info(p))


proc new_identifier_node(`type`: NodeType, p: Parser): PNode =
   result = new_node(`type`, p)
   result.identifier = p.tok.identifier


proc parse_attribute_instance(p: var Parser): PNode =
   result = new_node(NtAttributeInst, p)
   # FIXME: Properly handle this, don't just eat past it.
   while p.tok.type notin {TkRparenStar, TkEndOfFile}:
      get_token(p)

   if p.tok.type == TkRparenStar:
      get_token(p)


proc parse_range(p: var Parser): PNode =
   result = new_node(NtRange, p)

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


proc parse_constant_expression(p: var Parser): PNode =
   result = new_node(NtConstantExpression, p)
   get_token(p)


proc parse_parameter_assignment(p: var Parser): PNode =
   result = new_node(NtParamAssignment, p)

   if p.tok.type != TkSymbol:
      error(p, UnexpectedToken, p.tok)
      log.error("Expected an indentifier.")
      return new_node(NtEmpty, p)

   add(result.sons, new_identifier_node(NtParameterIdentifier, p))

   get_token(p)
   if p.tok.type != TkEquals:
      error(p, UnexpectedToken, p.tok)
      log.error("Expected '='.")
      return new_node(NtEmpty, p)

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
   result = new_node(NtParameterDecl, p)

   if p.tok.type != TkParameter:
      error(p, UnexpectedToken, p.tok)
      return new_node(NtEmpty, p)
   get_token(p)

   case p.tok.type
   of TkInteger:
      # FIXME: Communicate this somehow.
      get_token(p)
   of TkReal:
      # FIXME: Communicate this somehow.
      get_token(p)
   of TkRealtime:
      # FIXME: Communicate this somehow.
      get_token(p)
   of TkTime:
      # FIXME: Communicate this somehow.
      get_token(p)
   of TkSigned:
      # FIXME: Communicate this somehow.
      get_token(p)
      if p.tok.type == TkLbracket:
         add(result.sons, parse_range(p))
   of TkLbracket:
      add(result.sons, parse_range(p))
   of TkSymbol:
      discard
   else:
      error(p, UnexpectedToken, p.tok)
      return new_node(NtEmpty, p)

   # Try parsing a list of parameter assignments.
   add(result.sons, parse_list_of_parameter_assignments(p))


proc parse_parameter_port_list*(p: var Parser): PNode =
   result = new_node(NtModuleParameterPortList, p)

   get_token(p)
   if p.tok.type != TkLparen:
      error(p, UnexpectedToken, p.tok)
      return new_node(NtEmpty, p)

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
         error(p, UnexpectedToken, p.tok)
         result = new_node(NtEmpty, p)
         break


proc parse_module_declaration(p: var Parser, attributes: seq[PNode]): PNode =
   result = new_node(NtModuleDecl, p)
   if len(attributes) > 0:
      add(result.sons, attributes)

   # Expect an idenfitier as the first token after the module keyword.
   get_token(p)
   if p.tok.type == TkSymbol:
      add(result.sons, new_identifier_node(NtModuleIdentifier, p))
      discard
   else:
      error(p, UnexpectedToken, p.tok)

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
   while p.tok.type notin {TkEndmodule, TkEndOfFile}:
      get_token(p)

   if p.tok.type == TkEndmodule:
      get_token(p)
   elif p.tok.type == TkEndOfFile:
      result = new_node(NtEmpty, p)
      error(p, "Unexpected end of file when parsing module.")


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
      error(p, UnsupportedToken, p.tok)
      result = new_node(NtEmpty, p)
      get_token(p)
   else:
      error(p, UnexpectedToken, p.tok)
      result = new_node(NtEmpty, p)
      get_token(p)


proc parse_all*(p: var Parser): PNode =
   result = new_node(NtSourceText, p) # FIXME: Proper init value

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
      log.error("Unsupported specific grammar '$1'.", $`type`)

   close_parser(p)

