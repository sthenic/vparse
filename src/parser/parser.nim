import streams
import strutils

import ../lexer/lexer
import ../lexer/identifier

import ./ast


type
   Parser* = object
      lex: Lexer
      tok: Token
      next_tok: Token

   # Enumeration for strength types used in net declarations.
   Strength = enum
      None, DriveStrength, ChargeStrength


const
   UnexpectedToken = "Unexpected token $1."
   AttributesNotAllowed = "Attributes are not allowed here."
   ExpectedToken = "Expected token $1, got $2."
   ExpectedTokens = "Expected one of the tokens $1, got $2."


proc get_token(p: var Parser) =
   # FIXME: Properly handle comments. If we want to be able to recreate the
   #        source file, the comments also need to be nodes in the AST.
   #        If it's too complicated to insert the nodes into the AST, maybe we
   #        can keep the comments in a separate list and then mix them into the
   #        tree at the end?
   p.tok = p.next_tok
   if p.next_tok.type != TkEndOfFile:
      get_token(p.lex, p.next_tok)
      while p.next_tok.type == TkComment:
         get_token(p.lex, p.next_tok)


proc open_parser*(p: var Parser, cache: IdentifierCache, filename:
                  string, s: Stream) =
   init(p.tok)
   init(p.next_tok)
   open_lexer(p.lex, cache, filename, s)
   get_token(p)


proc close_parser*(p: var Parser) =
   close_lexer(p.lex)


proc new_line_info(tok: Token): TLineInfo =
   if tok.line < int(high(uint16)):
      result.line = uint16(tok.line)
   else:
      result.line = high(uint16)

   if tok.col < int(high(int16)):
      result.col = int16(tok.col)
   else:
      result.col = -1


proc new_line_info(p: Parser): TLineInfo =
   result = new_line_info(p.tok)


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


proc new_str_lit_node(p: Parser): PNode =
   result = new_node(p, NtStrLit)
   result.s = p.tok.literal


proc new_error_node(p: Parser, msg: string, args: varargs[string, `$`]): PNode =
   result = new_node(p, NtError)
   result.msg = format(msg, args)


template expect_token(p: Parser, kinds: set[TokenType]): untyped =
   if p.tok.type notin kinds:
      return new_error_node(p, ExpectedTokens, kinds, p.tok)


template expect_token(p: Parser, kind: TokenType): untyped =
   if p.tok.type != kind:
      return new_error_node(p, ExpectedToken, kind, p.tok)


template expect_token(p: Parser, result: PNode, kinds: set[TokenType]): untyped =
   if p.tok.type notin kinds:
      add(result.sons, new_error_node(p, ExpectedTokens, kinds, p.tok))
      return


template expect_token(p: Parser, result: PNode, kind: TokenType): untyped =
   if p.tok.type != kind:
      add(result.sons, new_error_node(p, ExpectedToken, kind, p.tok))
      return


template expect_token(p: Parser, result: seq[PNode], kinds: set[TokenType]): untyped =
   if p.tok.type notin kinds:
      add(result, new_error_node(p, ExpectedTokens, kinds, p.tok))
      return


template expect_token(p: Parser, result: seq[PNode], kind: TokenType): untyped =
   if p.tok.type != kind:
      add(result, new_error_node(p, ExpectedToken, kind, p.tok))
      return


template unexpected_token(p: Parser): PNode =
   new_error_node(p, UnexpectedToken, p.tok)


template unexpected_token(p: Parser, result: PNode): untyped =
   add(result.sons, new_error_node(p, UnexpectedToken, p.tok))
   return


proc look_ahead(p: Parser, curr, next: TokenType): bool =
   result = p.tok.type == curr and p.next_tok.type == next


# Forward declarations
proc parse_constant_expression(p: var Parser): PNode
proc parse_constant_range_expression(p: var Parser): PNode

proc parse_attribute_instance(p: var Parser): PNode =
   result = new_node(p, NtAttributeInst)
   get_token(p)

   while true:
      expect_token(p, result, TkSymbol)
      add(result.sons, new_identifier_node(p, NtAttributeName))
      get_token(p)
      if p.tok.type == TkEquals:
         get_token(p)
         add(result.sons, parse_constant_expression(p))

      expect_token(p, result, {TkComma, TkRparenStar})
      case p.tok.type
      of TkComma:
         get_token(p)
      of TkRparenStar:
         get_token(p)
         break
      else:
         break


proc parse_attribute_instances(p: var Parser): seq[PNode] =
   while p.tok.type == TkLparenStar:
      add(result, parse_attribute_instance(p))


proc parse_range(p: var Parser): PNode =
   result = new_node(p, NtRange)
   expect_token(p, result, TkLbracket)
   get_token(p)
   add(result.sons, parse_constant_expression(p))
   expect_token(p, result, TkColon)
   get_token(p)
   add(result.sons, parse_constant_expression(p))
   expect_token(p, result, TkRbracket)
   get_token(p)


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
   let brace_pos = new_line_info(p.tok)
   get_token(p)
   let first = parse_constant_expression(p)

   case p.tok.type
   of TkLbrace:
      # We're parsing a constant multiple concatenation.
      result = new_node(p, NtConstantMultipleConcat)
      result.info = brace_pos
      add(result.sons, first)
      add(result.sons, parse_constant_concatenation(p))
      expect_token(p, result, TkRbrace)
      get_token(p)
   of TkComma:
      # We're parsing a constant concatenation where the entry we parsed earlier
      # is the first of several. Parse the rest and add these to the sons on
      # this level.
      result = new_node(p, NtConstantConcat)
      result.info = brace_pos
      add(result.sons, first)
      add(result.sons, parse_constant_concatenation(p).sons)
   of TkRbrace:
      # A constant concatenation that only contains the entry we parsed earlier.
      result = new_node(p, NtConstantConcat)
      add(result.sons, first)
   else:
      result = unexpected_token(p)


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
      result.info = identifier.info
      add(result.sons, identifier)

      if p.tok.type == TkLparenStar:
         add(result.sons, parse_attribute_instances(p))

      expect_token(p, result, TkLparen)

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
      if p.tok.type == TkLbracket:
         result = new_node(p, NtRangedIdentifier)
         result.info = identifier.info
         add(result.sons, identifier)
         add(result.sons, parse_constant_range_expression(p))
      else:
         result = identifier


proc parse_mintypmax_expression(p: var Parser): PNode =
   # Expect an expression. This may be the first of a triplet constituting a
   # min:typ:max expression. We'll know if we encounter a colon.
   let first = parse_constant_expression(p)
   if p.tok.type == TkColon:
      result = new_node(p, NtConstantMinTypMaxExpression)
      result.info = first.info
      add(result.sons, first)
      get_token(p)
      add(result.sons, parse_constant_expression(p))
      expect_token(p, result, TkColon)
      get_token(p)
      add(result.sons, parse_constant_expression(p))
   else:
      result = first


proc parse_parenthesis(p: var Parser): PNode =
   result = new_node(p, NtParenthesis)
   get_token(p)
   if p.tok.type != TkRparen:
      add(result.sons, parse_mintypmax_expression(p))
   expect_token(p, result, TkRparen)
   get_token(p)


proc parse_constant_primary(p: var Parser): PNode =
   case p.tok.type
   of TkOperator:
      # Prefix node
      result = new_node(p, NtPrefix)
      add(result.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
      if p.tok.type == TkLparenStar:
         add(result.sons, parse_attribute_instances(p))
      add(result.sons, parse_constant_primary(p))
   of TkSymbol:
      # We have no way of knowing if this is a _valid_ (constant) symbol:
      # genvar, param or specparam. Maybe that's ok and actually something for
      # the next layer.
      result = parse_constant_primary_identifier(p)
   of TkLbrace:
      result = parse_constant_multiple_or_regular_concatenation(p)
   of TkDollar:
      result = new_node(p, NtConstantSystemFunctionCall)
      add(result.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
      expect_token(p, result, TkLparen)
      get_token(p)
      while true:
         add(result.sons, parse_constant_expression(p))
         case p.tok.type
         of TkComma:
            get_token(p)
         else:
            break
      expect_token(p, result, TkRparen)
      get_token(p)
   of TkLparen:
      # Handle parenthesis, the token is required when constructing a
      # min-typ-max expression and optional when indicating expression
      # precedence.
      result = parse_parenthesis(p)
   of NumberTokens:
      result = parse_number(p)
   of TkStrLit:
      result = new_str_lit_node(p)
      get_token(p)
   else:
      result = unexpected_token(p)


proc parse_constant_conditional_expression(p: var Parser, head: PNode): PNode =
   result = new_node(p, NtConstantConditionalExpression)
   expect_token(p, result, TkQuestionMark)
   get_token(p)
   add(result.sons, head)

   if p.tok.type == TkLparenStar:
      add(result.sons, parse_attribute_instances(p))

   add(result.sons, parse_constant_expression(p))
   expect_token(p, result, TkColon)
   get_token(p)
   add(result.sons, parse_constant_expression(p))


proc is_right_associative(tok: Token): bool =
   result = tok.type in {TkQuestionMark, TkColon}


proc parse_constant_expression_aux(p: var Parser, limit: int): PNode


proc parse_operator(p: var Parser, head: PNode, limit: int): PNode =
   result = head
   var precedence = get_binary_precedence(p.tok)
   while precedence >= limit:
      expect_token(p, result, {TkOperator, TkQuestionMark})
      let left_associative = 1 - ord(is_right_associative(p.tok))
      if p.tok.type == TkQuestionMark:
         result = parse_constant_conditional_expression(p, result)
      else:
         let infix = new_node(p, NtInfix)
         let op = new_identifier_node(p, NtIdentifier)
         get_token(p)
         var rhs_attributes: seq[PNode] = @[]
         if p.tok.type == TkLparenStar:
            add(rhs_attributes, parse_attribute_instances(p))
         # Return the right hand side of the expression, parsing any expressions
         # with a precedence greater than the current expression, if left
         # associative, and any expressions with precedence greater than or
         # equal to the current expression if right associative.
         let rhs = parse_constant_expression_aux(p, precedence + left_associative)
         add(infix.sons, op)
         add(infix.sons, result)
         if len(rhs_attributes) > 0:
            add(infix.sons, rhs_attributes)
         add(infix.sons, rhs)
         result = infix
      precedence = get_binary_precedence(p.tok)


proc parse_constant_expression_aux(p: var Parser, limit: int): PNode =
   result = parse_constant_primary(p)
   result = parse_operator(p, result, limit)


proc parse_constant_expression(p: var Parser): PNode =
   result = parse_constant_expression_aux(p, -1)


proc parse_parameter_assignment(p: var Parser): PNode =
   result = new_node(p, NtParamAssignment)

   expect_token(p, result, TkSymbol)
   add(result.sons, new_identifier_node(p, NtParameterIdentifier))
   get_token(p)

   expect_token(p, result, TkEquals)
   get_token(p)

   add(result.sons, parse_constant_expression(p))


proc parse_parameter_declaration(p: var Parser): PNode =
   result = new_node(p, NtParameterDecl)
   expect_token(p, result, TkParameter)
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
      unexpected_token(p, result)

   # Parse a list of parameter assignments, there should be at least one.
   while true:
      add(result.sons, parse_parameter_assignment(p))
      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)


proc parse_parameter_port_list(p: var Parser): PNode =
   result = new_node(p, NtModuleParameterPortList)
   expect_token(p, result, TkHash)
   get_token(p)
   expect_token(p, result, TkLparen)
   get_token(p)

   # Parse the contents, at least one parameter declaration is expected.
   while true:
      add(result.sons, parse_parameter_declaration(p))
      if p.tok.type == TkComma:
         get_token(p)
      else:
         break

   expect_token(p, result, TkRparen)
   get_token(p)

proc parse_inout_or_input_port_declaration(p: var Parser,
                                           attributes: seq[PNode]): PNode =
   # Inout or input ports have a common syntax.
   result = new_node(p, NtPortDecl)
   if len(attributes) > 0:
      add(result.sons, attributes)

   expect_token(p, result, {TkInout, TkInput})
   add(result.sons, new_identifier_node(p, NtDirection))
   get_token(p)

   # Optional net type (Verilog keywords).
   if p.tok.type in NetTypeTokens:
      add(result.sons, new_identifier_node(p, NtNetType))
      get_token(p)

   # Optional 'signed' specifier.
   if p.tok.type == TkSigned:
      add(result.sons, new_identifier_node(p, NtType))
      get_token(p)

   # Optional range.
   if p.tok.type == TkLbracket:
      add(result.sons, parse_range(p))

   # Parse a list of port identifiers, the syntax requires at least one item.
   while true:
      expect_token(p, result, TkSymbol)
      add(result.sons, new_identifier_node(p, NtPortIdentifier))
      get_token(p)
      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)


proc parse_list_of_variable_port_identifiers(p: var Parser): seq[PNode] =
   # Expect at least one port identifier. Unless we see an equals sign, the
   # AST node is a regular identifier.
   while true:
      expect_token(p, result, TkSymbol)
      let identifier = new_identifier_node(p, NtPortIdentifier)
      get_token(p)

      if p.tok.type == TkEquals:
         get_token(p)
         let n = new_node(p, NtVariablePort)
         n.info = identifier.info
         add(n.sons, identifier)
         add(n.sons, parse_constant_expression(p))
         add(result, n)
      else:
         add(result, identifier)

      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)


proc parse_list_of_port_identifiers(p: var Parser): seq[PNode] =
   while true:
      expect_token(p, result, TkSymbol)
      # FIXME: Make this a regular NtIdentifier?
      add(result, new_identifier_node(p, NtPortIdentifier))
      get_token(p)

      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)


proc parse_output_port_declaration(p: var Parser, attributes: seq[PNode]): PNode =
   # Inout or input ports have a common syntax.
   result = new_node(p, NtPortDecl)
   if len(attributes) > 0:
      add(result.sons, attributes)

   expect_token(p, result, TkOutput)
   add(result.sons, new_identifier_node(p, NtDirection))
   get_token(p)

   case p.tok.type
   of TkReg:
      add(result.sons, new_identifier_node(p, NtNetType))
      get_token(p)

      if p.tok.type == TkSigned:
         add(result.sons, new_identifier_node(p, NtType))
         get_token(p)

      if p.tok.type == TkLbracket:
         add(result.sons, parse_range(p))

      add(result.sons, parse_list_of_variable_port_identifiers(p))

   of TkInteger, TkTime:
      add(result.sons, new_identifier_node(p, NtNetType))
      get_token(p)

      add(result.sons, parse_list_of_variable_port_identifiers(p))

   else:
      if p.tok.type in NetTypeTokens:
         add(result.sons, new_identifier_node(p, NtNetType))
         get_token(p)

      if p.tok.type == TkSigned:
         add(result.sons, new_identifier_node(p, NtType))
         get_token(p)

      if p.tok.type == TkLbracket:
         add(result.sons, parse_range(p))

      add(result.sons, parse_list_of_port_identifiers(p))


proc parse_port_declaration(p: var Parser, attributes: seq[PNode]): PNode =
   case p.tok.type
   of TkInout, TkInput:
      result = parse_inout_or_input_port_declaration(p, attributes)
   of TkOutput:
      result = parse_output_port_declaration(p, attributes)
   else:
      result = unexpected_token(p)


proc parse_list_of_port_declarations(p: var Parser): PNode =
   # The enclosing parenthesis will be removed by the calling procedure.
   result = new_node(p, NtListOfPortDeclarations)

   while true:
      # FIXME: May be removed? Token is checked twice.
      var attributes: seq[PNode] = @[]
      if p.tok.type == TkLparenStar:
         add(attributes, parse_attribute_instances(p))

      expect_token(p, result, {TkInout, TkInput, TkOutput})
      add(result.sons, parse_port_declaration(p, attributes))
      if p.tok.type != TkComma:
         break
      get_token(p)


proc parse_constant_range_expression(p: var Parser): PNode =
   result = new_node(p, NtConstantRangeExpression)
   get_token(p)

   let first = parse_constant_expression(p)
   case p.tok.type
   of TkColon:
      get_token(p)
      add(result.sons, first)
      add(result.sons, parse_constant_expression(p))
   of TkPlusColon, TkMinusColon:
      let infix = new_node(p, NtInfix)
      add(infix.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
      add(infix.sons, first)
      add(infix.sons, parse_constant_expression(p))
      add(result.sons, infix)
   of TkRbracket:
      add(result.sons, first)
   else:
      unexpected_token(p, result)

   expect_token(p, result, TkRbracket)
   get_token(p)


proc parse_port_reference(p: var Parser): PNode =
   result = new_node(p, NtPortReference)
   expect_token(p, result, TkSymbol)
   add(result.sons, new_identifier_node(p, NtPortIdentifier))
   get_token(p)

   if p.tok.type == TkLbracket:
      add(result.sons, parse_constant_range_expression(p))


proc parse_port_reference_concat(p: var Parser): PNode =
   expect_token(p, TkLbrace)
   result = new_node(p, NtPortReferenceConcat)
   get_token(p)

   while true:
      add(result.sons, parse_port_reference(p))
      case p.tok.type
      of TkComma:
         get_token(p)
      of TkRbrace:
         get_token(p)
         break
      else:
         break


proc parse_port_expression(p: var Parser): PNode =
   expect_token(p, {TkSymbol, TkLbrace})
   if p.tok.type == TkSymbol:
      result = parse_port_reference(p)
   elif p.tok.type == TkLbrace:
      result = parse_port_reference_concat(p)


proc parse_port(p: var Parser): PNode =
   result = new_node(p, NtPort)

   case p.tok.type
   of TkDot:
      get_token(p)
      expect_token(p, result, TkSymbol)
      add(result.sons, new_identifier_node(p, NtPortIdentifier))
      get_token(p)

      expect_token(p, result, TkLparen)
      get_token(p)

      if p.tok.type != TkRparen:
         add(result.sons, parse_port_expression(p))
      expect_token(p, result, TkRparen)
      get_token(p)

   of TkSymbol, TkLbrace:
      add(result.sons, parse_port_expression(p))

   else:
      # An empty port is also valid.
      discard


proc parse_list_of_ports(p: var Parser): PNode =
   # The enclosing parenthesis will be removed by the calling procedure.
   result = new_node(p, NtListOfPorts)

   while true:
      add(result.sons, parse_port(p))
      case p.tok.type
      of TkComma:
         get_token(p)
      else:
         break # FIXME: Error?


proc parse_list_of_ports_or_port_declarations(p: var Parser): PNode =
   expect_token(p, TkLparen)
   get_token(p)

   # TODO: The enclosing parenthesis could be removed in the respective
   #       functions w/ the new look ahead support.
   if p.tok.type == TkRparen:
      # The node should be an empty list of port declarations.
      result = new_node(p, NtListOfPortDeclarations)
   elif p.tok.type in {TkInout, TkInput, TkOutput, TkLparenStar}:
      # Assume a list of port declarations.
      result = parse_list_of_port_declarations(p)
   else:
      # Assume a list of ports.
      result = parse_list_of_ports(p)

   expect_token(p, result, TkRparen)
   get_token(p)


proc parse_array_identifier(p: var Parser, identifier: PNode): PNode =
   result = new_node(p, NtArrayIdentifer)
   result.info = identifier.info
   add(result.sons, identifier)
   # Handle any number of dimension specifiers (array).
   while true:
      if p.tok.type != TkLbracket:
         break
      add(result.sons, parse_range(p))


proc parse_list_of_variable_identifiers(p: var Parser): seq[PNode] =
   # Expect at least one variable identifier. Unless we see an equals sign
   # (assignment) or a left bracket (array), the AST node is a regular
   # identifier.
   while true:
      expect_token(p, result, TkSymbol)
      let identifier = new_identifier_node(p, NtIdentifier)
      get_token(p)

      case p.tok.type
      of TkLbracket:
         add(result, parse_array_identifier(p, identifier))
      of TkEquals:
         let n = new_node(p, NtAssignment)
         n.info = identifier.info
         add(n.sons, identifier)
         get_token(p)
         add(n.sons, parse_constant_expression(p))
         add(result, n)
      else:
         add(result, identifier)

      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)


proc parse_list_of_array_identifiers(p: var Parser): seq[PNode] =
   while true:
      expect_token(p, result, TkSymbol)
      let identifier = new_identifier_node(p, NtIdentifier)
      get_token(p)

      if p.tok.type == TkLbracket:
         add(result, parse_array_identifier(p, identifier))
      else:
         add(result, identifier)

      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)


proc parse_list_of_assignments(p: var Parser): seq[PNode] =
   while true:
      expect_token(p, result, TkSymbol)
      let n = new_node(p, NtAssignment)
      add(n.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
      expect_token(p, result, TkEquals)
      get_token(p)
      add(n.sons, parse_constant_expression(p))
      add(result, n)

      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)


proc parse_list_of_net_identifiers_or_declaration_assignments(p: var Parser): seq[PNode] =
   # It's not until we've parsed the first identifier that we know which syntax
   # to expect.
   expect_token(p, result, TkSymbol)
   let first = new_identifier_node(p, NtIdentifier)
   get_token(p)

   if p.tok.type == TkEquals:
      # We're parsing a list of net declaration assignments. Handle the first
      # one manually.
      let n = new_node(p, NtAssignment)
      n.info = first.info
      get_token(p)
      add(n.sons, first)
      add(n.sons, parse_constant_expression(p))
      add(result, n)
      if p.tok.type == TkComma:
         get_token(p)
         add(result, parse_list_of_assignments(p))
   else:
      # We're parsing a list of net identifiers. These may be arrays.
      if p.tok.type == TkLbracket:
         add(result, parse_array_identifier(p, first))
      else:
         add(result, first)

      if p.tok.type == TkComma:
         get_token(p)
         add(result, parse_list_of_array_identifiers(p))


proc parse_delay(p: var Parser, nof_expressions: int): PNode =
   result = new_node(p, NtDelay)
   get_token(p)

   case p.tok.type
   of TkLparen:
      # Expect a min:typ:max expression. There should be at least one and at
      # most nof_expressions.
      for i in 0..<nof_expressions:
         add(result.sons, parse_mintypmax_expression(p))
         if p.tok.type != TkComma:
            break
         get_token(p)
   of TkSymbol:
      add(result.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
   of NumberTokens:
      add(result.sons, parse_number(p))
   else:
      unexpected_token(p, result)


proc parse_drive_strength(p: var Parser): PNode =
   result = new_node(p, NtDriveStrength)

   case p.tok.type
   of DriveStrength0Tokens, TkHighz0:
      add(result.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
      expect_token(p, result, TkComma)
      get_token(p)
      expect_token(p, result, DriveStrength1Tokens + {TkHighz1})
      add(result.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
   of DriveStrength1Tokens, TkHighz1:
      add(result.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
      expect_token(p, result, TkComma)
      get_token(p)
      expect_token(p, result, DriveStrength0Tokens + {TkHighz0})
      add(result.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
   else:
      unexpected_token(p, result)

   expect_token(p, result, TkRparen)
   get_token(p)


proc parse_net_declaration(p: var Parser): PNode =
   result = new_node(p, NtNetDecl)

   case p.tok.type
   of NetTypeTokens:
      add(result.sons, new_identifier_node(p, NtType))
      get_token(p)

      var has_drive_strength = false
      if p.tok.type == TkLparen:
         get_token(p)
         add(result.sons, parse_drive_strength(p))
         has_drive_strength = true

      if p.tok.type in {TkVectored, TkScalared}:
         add(result.sons, new_identifier_node(p, NtType))
         get_token(p)

      if p.tok.type == TkSigned:
         add(result.sons, new_identifier_node(p, NtType))
         get_token(p)

      if p.tok.type == TkLbracket:
         add(result.sons, parse_range(p))

      if p.tok.type == TkHash:
         # The syntax expects a delay3 expression.
         add(result.sons, parse_delay(p, 3))

      # If we've encountered a drive strength specifier, the syntax requires
      # that what follows is a list of net declaration assignments. Otherwise,
      # we're ready to accept a list of net identifiers as well.
      if has_drive_strength:
         add(result.sons, parse_list_of_assignments(p))
      else:
         add(result.sons,
             parse_list_of_net_identifiers_or_declaration_assignments(p))

   of TkTrireg:
      add(result.sons, new_identifier_node(p, NtType))
      get_token(p)

      var strength: Strength = None
      if p.tok.type == TkLparen:
         get_token(p)
         case p.tok.type
         of DriveStrengthTokens:
            add(result.sons, parse_drive_strength(p))
            strength = DriveStrength
         of ChargeStrengthTokens:
            let n = new_node(p, NtChargeStrength)
            add(n.sons, new_identifier_node(p, NtIdentifier))
            add(result.sons, n)
            strength = ChargeStrength
         else:
            unexpected_token(p, result)
         expect_token(p, result, TkRparen)
         get_token(p)

      if p.tok.type in {TkVectored, TkScalared}:
         add(result.sons, new_identifier_node(p, NtType))
         get_token(p)

      if p.tok.type == TkSigned:
         add(result.sons, new_identifier_node(p, NtType))
         get_token(p)

      if p.tok.type == TkLbracket:
         add(result.sons, parse_range(p))

      if p.tok.type == TkHash:
         # The syntax expects a delay3 expression.
         add(result.sons, parse_delay(p, 3))

      # If we've encountered a strength specifier, a certain syntax is expected.
      # If not, we cannot be sure of what syntax to expect until we've parsed
      # the first identifier.
      case strength
      of DriveStrength:
         add(result.sons, parse_list_of_assignments(p))
      of ChargeStrength:
         add(result.sons, parse_list_of_array_identifiers(p))
      of None:
         add(result.sons,
             parse_list_of_net_identifiers_or_declaration_assignments(p))
   else:
      unexpected_token(p, result)

   expect_token(p, result, TkSemicolon)
   get_token(p)


proc parse_event_declaration(p: var Parser): PNode =
   result = new_node(p, NtEventDecl)
   get_token(p)
   add(result.sons, parse_list_of_array_identifiers(p))
   expect_token(p, result, TkSemicolon)
   get_token(p)


proc parse_variable_declaration(p: var Parser): PNode =
   # Parse declarations of identifiers that may have a variable type. This
   # includes reg, integer, real, realtime and time.
   case p.tok.type
   of TkReg:
      result = new_node(p, NtRegDecl)
      get_token(p)

      if p.tok.type == TkSigned:
         add(result.sons, new_identifier_node(p, NtType))
         get_token(p)

      if p.tok.type == TkLbracket:
         add(result.sons, parse_range(p))
   of TkInteger:
      result = new_node(p, NtIntegerDecl)
      get_token(p)
   of TkReal:
      result = new_node(p, NtRealDecl)
      get_token(p)
   of TkRealtime:
      result = new_node(p, NtRealtimeDecl)
      get_token(p)
   of TkTime:
      result = new_node(p, NtTimeDecl)
      get_token(p)
   else:
      result = unexpected_token(p)
      return

   add(result.sons, parse_list_of_variable_identifiers(p))
   expect_token(p, result, TkSemicolon)
   get_token(p)


proc parse_genvar_declaration(p: var Parser): PNode =
   result = new_node(p, NtGenvarDecl)
   get_token(p)
   while true:
      expect_token(p, result, TkSymbol)
      add(result.sons, new_node(p, NtIdentifier))
      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)


proc parse_task_port(p: var Parser, attributes: seq[PNode]): PNode =
   result = new_node(p, NtTaskPort)
   if len(attributes) > 0:
      add(result.sons, attributes)
   expect_token(p, result, {TkInput, TkInout, TkOutput})
   add(result.sons, new_identifier_node(p, NtDirection))
   get_token(p)

   if p.tok.type in {TkInteger, TkReal, TkRealtime, TkTime}:
      add(result.sons, new_identifier_node(p, NtType))
      get_token(p)
   else:
      # Register syntax
      if p.tok.type == TkReg:
         add(result.sons, new_identifier_node(p, NtType))
         get_token(p)
      if p.tok.type == TkSigned:
         add(result.sons, new_identifier_node(p, NtType))
         get_token(p)
      if p.tok.type == TkLbracket:
         add(result.sons, parse_range(p))

   # Parse a list of port identifiers
   add(result.sons, parse_list_of_port_identifiers(p))


proc parse_task_port_list(p: var Parser): seq[PNode] =
   while true:
      var attributes: seq[PNode] = @[]
      if p.tok.type == TkLparenStar:
         add(attributes, parse_attribute_instances(p))
      add(result, parse_task_port(p, attributes))

      if p.tok.type != TkComma:
         break
      get_token(p)


proc parse_block_item_declaration(p: var Parser, attributes: seq[PNode]): PNode =
   case p.tok.type
   of TkReg, TkInteger, TkReal, TkTime, TkRealtime:
      result = parse_variable_declaration(p)
   of TkEvent:
      result = parse_event_declaration(p)
   of TkLocalparam:
      # FIXME: localparam
      get_token(p)
   of TkParameter:
      result = parse_parameter_declaration(p)
   else:
      result = unexpected_token(p)
      return

   if len(attributes) > 0:
      result.sons = attributes & result.sons

   expect_token(p, result, TkSemicolon)
   get_token(p)


proc parse_task_item_declaration(p: var Parser, attributes: seq[PNode]): PNode =
   if p.tok.type in {TkInput, TkInout, TkOutput}:
      result = parse_task_port(p, attributes)
      expect_token(p, result, TkSemicolon)
      get_token(p)
   else:
      result = parse_block_item_declaration(p, attributes)


proc parse_variable_lvalue(p: var Parser): PNode =
   case p.tok.type
   of TkSymbol:
      result = new_node(p, NtVariableLvalue)
      add(result.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)

      # The identifier may be followed by any number of bracketed expressions.
      # However, it's only the last one that's allowed to be a range expression.
      # TODO: Fix this parsing since we're allowing everything to be a range
      #       expression. We should probably have NtBrackets like we do for
      #       parentheses.
      while true:
         if p.tok.type != TkLbracket:
            break
         add(result.sons, parse_constant_range_expression(p))

   of TkLbrace:
      # Concatenation of lvalues, expecting at least one.
      result = new_node(p, NtVariableLvalueConcat)
      get_token(p)
      while true:
         add(result.sons, parse_variable_lvalue(p))
         if p.tok.type != TkComma:
            break
         get_token(p)
      expect_token(p, TkRbrace)
      get_token(p)
   else:
      result = unexpected_token(p)
      return


proc parse_event_expression(p: var Parser): seq[PNode] =
   # This function returns a sequence of nodes since the syntax allows one event
   # expression to consist of many chained expressions chained together w/ 'or'.
   let n = new_node(p, NtEventExpression)
   if p.tok.type in {TkPosedge, TkNegedge}:
      # FIXME: Improve node type?
      add(n.sons, new_identifier_node(p, NtType))
      get_token(p)
      add(n.sons, parse_constant_expression(p))
   else:
      add(n.sons, parse_constant_expression(p))
   add(result, n)

   # Check if the expression is followed by 'or', in which case we expect
   # another event expression to follow.
   if p.tok.type == TkOr:
      get_token(p)
      add(result, parse_event_expression(p))


proc parse_event_control(p: var Parser): PNode =
   result = new_node(p, NtEventControl)
   expect_token(p, result, TkAt)
   get_token(p)

   case p.tok.type
   of TkSymbol:
      add(result.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
   of TkOperator:
      if p.tok.identifier.s != "*":
         unexpected_token(p, result)
      add(result.sons, new_node(p, NtWildcard))
      get_token(p)
   of TkLparenStar:
      # If the left parenthesis is not separated from the '*' with whitespace,
      # the lexer will output this as a '(*' token used to indicate an attribute
      # instance. We have to interpret this differently.
      let n = new_node(p, NtParenthesis)
      let wc = new_node(p, NtWildcard)
      inc(wc.info.col)
      add(n.sons, wc)
      get_token(p)
      expect_token(p, result, TkRparen)
      get_token(p)
      add(result.sons, n)
   of TkLparen:
      let n = new_node(p, NtParenthesis)
      get_token(p)
      if p.tok.type == TkOperator and p.tok.identifier.s == "*":
         add(n.sons, new_node(p, NtWildcard))
         get_token(p)
      else:
         add(n.sons, parse_event_expression(p))

      expect_token(p, result, TkRparen)
      get_token(p)
      add(result.sons, n)
   else:
      unexpected_token(p, result)


proc parse_delay_or_event_control(p: var Parser): PNode =
   case p.tok.type
   of TkHash:
      result = parse_delay(p, 1)
   of TkAt:
      result = parse_event_control(p)
   of TkRepeat:
      result = new_node(p, NtRepeat)
      get_token(p)
      expect_token(p, result, TkLparen)
      get_token(p)
      add(result.sons, parse_constant_expression(p))
      expect_token(p, result, TkRparen)
      get_token(p)
      add(result.sons, parse_event_control(p))
   else:
      result = unexpected_token(p)


proc parse_blocking_or_nonblocking_assignment(p: var Parser): PNode =
   let lvalue = parse_variable_lvalue(p)

   # Initialize the node depending on the next token.
   case p.tok.type
   of TkEquals:
      result = new_node(p, NtBlockingAssignment)
   of TkOperator:
      if p.tok.identifier.s != "<=":
         result = unexpected_token(p)
         return
      result = new_node(p, NtNonblockingAssignment)
   else:
      result = unexpected_token(p)
      return

   get_token(p)
   result.info = lvalue.info
   add(result.sons, lvalue)

   # Handle a delay or event control specifier.
   if p.tok.type in {TkHash, TkAt, TkRepeat}:
      add(result.sons, parse_delay_or_event_control(p))

   add(result.sons, parse_constant_expression(p))


proc parse_statement(p: var Parser, attributes: seq[PNode]): PNode =
   case p.tok.type
   of TkCase, TkCasex, TkCasez:
      # FIXME: Case statement
      get_token(p)
   of TkIf:
      # FIXME: Conditional statement
      get_token(p)
   of TkDisable:
      # FIXME: Disable statement
      get_token(p)
   of TkRightArrow:
      # FIXME: Event trigger
      get_token(p)
   of TkForever, TkRepeat, TkWhile, TkFor:
      # FIXME: Loop statement
      get_token(p)
   of TkFork:
      # FIXME: Parallel block
      get_token(p)
   of TkBegin:
      # FIXME: Sequential block
      get_token(p)
   of TkAssign, TkDeassign, TkForce, TkRelease:
      # FIXME: Procedural continuouos assignment
      get_token(p)
      # FIXME: Make sure result is not nil.
      expect_token(p, result, TkSemicolon)
      get_token(p)
   of TkHash, TkAt:
      # FIXME: Procedural timing control statement.
      get_token(p)
   of TkDollar:
      # FIXME: System task identifier
      get_token(p)
   of TkWait:
      # FIXME: Wait statement
      get_token(p)
   of TkSymbol:
      # FIXME: Task identifier if followed by parentheses or by a semicolon.
      # FIXME: Blocking assignment if followed by '='.
      # FIXME: Nonblocking assignment if followed by '<='.
      get_token(p)
   of TkLbrace:
      # FIXME: blocking or nonblocking assignment.
      get_token(p)
   else:
      result = unexpected_token(p)
      return

   if len(attributes) > 0:
      result.sons = attributes & result.sons


proc parse_statement_or_null(p: var Parser, attributes: seq[PNode]): PNode =
   if p.tok.type == TkSemicolon:
      # This is a null statement.
      # FIXME: use a better node type, include attributes.
      result = new_node(p, NtEmpty)
      get_token(p)
   else:
      # Parse a statement.
      result = parse_statement(p, attributes)
      discard


proc parse_task_declaration(p: var Parser): PNode =
   result = new_node(p, NtTaskDecl)
   get_token(p)

   if p.tok.type == TkAutomatic:
      # FIXME: Is NtType the best option?
      add(result.sons, new_identifier_node(p, NtType))
      get_token(p)

   # Expect the task identifier.
   expect_token(p, result, TkSymbol)
   add(result.sons, new_identifier_node(p, NtIdentifier))
   get_token(p)

   # Parse the task port list. If ports are specified, the syntax does not allow
   # port declarations within the task itself.
   var parse_body_declaration = parse_task_item_declaration
   var expected_tokens = DeclarationTokens + {TkInput, TkInout, TkOutput}
   if p.tok.type == TkLparen:
      get_token(p)
      add(result.sons, parse_task_port_list(p))
      expect_token(p, result, TkRparen)
      get_token(p)
      parse_body_declaration = parse_block_item_declaration
      expected_tokens = DeclarationTokens

   expect_token(p, result, TkSemicolon)
   get_token(p)

   var attributes: seq[PNode] = @[]
   # Parse zero or more declarations with parse_body_declaration.
   while true:
      if p.tok.type == TkLparenStar:
         add(attributes, parse_attribute_instances(p))
      if p.tok.type notin expected_tokens:
         break
      add(result.sons, parse_body_declaration(p, attributes))

   # Parse a statement or null (a single semicolon)
   if p.tok.type == TkLparenStar:
      add(attributes, parse_attribute_instances(p))

   add(result.sons, parse_statement_or_null(p, attributes))

   expect_token(p, result, TkEndtask)
   get_token(p)


proc parse_specparam_declaration(p: var Parser): PNode =
   # FIXME: Implement
   get_token(p)

   while true:
      if p.tok.type in {TkSemicolon, TkEndOfFile}:
         break
      get_token(p)

   expect_token(p, result, TkSemicolon)
   get_token(p)


proc parse_generate_region(p: var Parser): PNode =
   result = new_node(p, NtGenerateRegion)
   get_token(p)

   # FIXME: Implement
   while true:
      if p.tok.type in {TkEndgenerate, TkEndOfFile}:
         break
      get_token(p)

   expect_token(p, result, TkEndgenerate)
   get_token(p)


proc parse_specify_block(p: var Parser): PNode =
   result = new_node(p, NtSpecifyBlock)
   get_token(p)

   # FIXME: Implement
   while true:
      if p.tok.type in {TkEndspecify, TkEndOfFile}:
         break
      get_token(p)

   expect_token(p, result, TkEndspecify)
   get_token(p)


proc parse_module_or_generate_item_declaration(p: var Parser,
                                               attributes: seq[PNode]): PNode =
   case p.tok.type
   of NetTypeTokens, TkTrireg:
      result = parse_net_declaration(p)
      if len(attributes) > 0:
         result.sons = attributes & result.sons
   of TkReg, TkInteger, TkReal, TkTime, TkRealtime:
      result = parse_variable_declaration(p)
      if len(attributes) > 0:
         result.sons = attributes & result.sons
   of TkEvent:
      result = parse_event_declaration(p)
      if len(attributes) > 0:
         result.sons = attributes & result.sons
   of TkGenvar:
      result = parse_genvar_declaration(p)
      if len(attributes) > 0:
         result.sons = attributes & result.sons
   of TkTask:
      result = parse_task_declaration(p)
      if len(attributes) > 0:
         result.sons = attributes & result.sons
   of TkFunction:
      # FIXME: function decl.
      get_token(p)
   else:
      result = unexpected_token(p)


proc parse_module_or_generate_item(p: var Parser, attributes: seq[PNode]): PNode =
   case p.tok.type
   of TkLocalparam:
      # FIXME: localparam
      get_token(p)
   of TkDefparam:
      # FIXME: parameter override
      get_token(p)
   of TkAssign:
      # FIXME: continuous assing
      get_token(p)
   of GateSwitchTypeTokens:
      result = new_error_node(p, "Gate instantiatiation is currently not supported.")
      get_token(p)
   of TkInitial:
      # FIXME: Parse initial statement
      get_token(p)
   of TkAlways:
      # FIXME: Parse always statement
      get_token(p)
   of TkFor:
      # FIXME: Parse loop generate construct
      get_token(p)
   of TkIf, TkCase:
      # FIXME: Parse conditional generate construct
      get_token(p)
   of TkSymbol:
      # Might be UDP or module instantiation
      get_token(p)
   else:
      result = parse_module_or_generate_item_declaration(p, attributes)


proc parse_non_port_module_item(p: var Parser, attributes: seq[PNode]): PNode =
   # Specify blocks and generate regions are not allowed attribute instances
   # so if there's anything in the input argument we should return an error.
   case p.tok.type
   of TkGenerate:
      if len(attributes) > 0:
         result = new_error_node(p, AttributesNotAllowed)
         result.info = attributes[0].info
      else:
         result = parse_generate_region(p)
   of TkSpecify:
      if len(attributes) > 0:
         result = new_error_node(p, AttributesNotAllowed)
         result.info = attributes[0].info
      else:
         result = parse_specify_block(p)
   of TkParameter:
      # A parameter declaration with optional attributes and ending w/ a
      # semicolon.
      result = parse_parameter_declaration(p)
      if len(attributes) > 0:
         result.sons = attributes & result.sons
      expect_token(p, result, TkSemicolon)
      get_token(p)
   of TkSpecparam:
      result = parse_specparam_declaration(p)
      if len(attributes) > 0:
         result.sons = attributes & result.sons
   else:
      # Assume module or generate item.
      result = parse_module_or_generate_item(p, attributes)


proc parse_module_item(p: var Parser, attributes: seq[PNode]): PNode =
   if p.tok.type in {TkInout, TkInput, TkOutput}:
      result = parse_port_declaration(p, attributes)
      expect_token(p, result, TkSemicolon)
      get_token(p)
   else:
      result = parse_non_port_module_item(p, attributes)


proc parse_module_declaration(p: var Parser, attributes: seq[PNode]): PNode =
   result = new_node(p, NtModuleDecl)
   get_token(p)
   if len(attributes) > 0:
      add(result.sons, attributes)

   # Expect an idenfitier as the first token after the module keyword.
   expect_token(p, result, TkSymbol)
   add(result.sons, new_identifier_node(p, NtModuleIdentifier))
   get_token(p)

   # Parse the optional parameter port list.
   if p.tok.type == TkHash:
      add(result.sons, parse_parameter_port_list(p))

   # Parse the optional list or ports/port declarations. This will determine
   # what to allow as the module contents.
   var parse_body = parse_non_port_module_item
   if p.tok.type == TkLparen:
      let n = parse_list_of_ports_or_port_declarations(p)
      if n.type == NtListOfPorts:
         parse_body = parse_module_item
      add(result.sons, n)

   # Expect a semicolon.
   expect_token(p, result, TkSemicolon)
   get_token(p)

   # Parse the body of the module using the function pointed to by parse_body.
   # For each statement, parse any attribute instances. It's not until we're
   # past these in the token stream that we can determine what syntax to parse
   # next and even if the attributes were allowed or not.
   while true:
      if p.tok.type in {TkEndmodule, TkEndOfFile}:
         break
      var attributes: seq[PNode] = @[]
      if p.tok.type == TkLparenStar:
         add(attributes, parse_attribute_instances(p))
      add(result.sons, parse_body(p, attributes))

   # Expect the 'endmodule' keyword.
   expect_token(p, result, TkEndmodule)
   get_token(p)


proc assume_source_text(p: var Parser): PNode =
   # Parse source text (A.1.3)
   # Check for attribute instances.
   var attributes: seq[PNode] = @[]
   if p.tok.type == TkLparenStar:
      add(attributes, parse_attribute_instances(p))

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
   get_token(p)
   result = new_node(p, NtSourceText) # FIXME: Proper init value
   while p.tok.type != TkEndOfFile:
      let n = assume_source_text(p)
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
   of NtListOfPorts, NtListOfPortDeclarations:
      parse_proc = parse_list_of_ports_or_port_declarations
   of NtModuleParameterPortList:
      parse_proc = parse_parameter_port_list
   of NtConstantExpression:
      parse_proc = parse_constant_expression
   of NtRegDecl, NtIntegerDecl, NtRealDecl, NtRealtimeDecl, NtTimeDecl:
      parse_proc = parse_variable_declaration
   of NtEventDecl:
      parse_proc = parse_event_declaration
   of NtNetDecl:
      parse_proc = parse_net_declaration
   of NtTaskDecl:
      parse_proc = parse_task_declaration
   of NtBlockingAssignment, NtNonblockingAssignment:
      parse_proc = parse_blocking_or_nonblocking_assignment
   else:
      parse_proc = nil

   if parse_proc != nil:
      # Expect only one top-level statement per call.
      get_token(p)
      result = parse_proc(p)
   else:
      result = new_error_node(p, "Unsupported specific grammar '$1'.", $`type`)

   close_parser(p)

