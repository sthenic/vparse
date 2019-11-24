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

const
   UnexpectedToken = "Unexpected token $1."
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


proc new_operator_node(p: Parser, `type`: NodeType, op: string): PNode =
   result = new_node(p, `type`)
   result.op = op


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
   get_token(p)
   let first = parse_constant_expression(p)

   case p.tok.type
   of TkLbrace:
      # We're parsing a constant multiple concatenation.
      result = new_node(p, NtConstantMultipleConcat)
      add(result.sons, first)
      add(result.sons, parse_constant_concatenation(p))
      expect_token(p, result, TkRbrace)
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
      add(result.sons, identifier)

      if p.tok.type == TkLparenStar:
         add(result.sons, parse_attribute_instances(p))

      expect_token(p, result, TkLparen)

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


proc parse_parenthesis(p: var Parser): PNode =
   result = new_node(p, NtParenthesis)
   get_token(p)

   if p.tok.type != TkRparen:
      # Expect an expression. This may be the first of a triplet constituting a
      # min:typ:max expression. We'll know if we encounter a colon.
      let first = parse_constant_expression(p)
      if p.tok.type == TkColon:
         let mtm = new_node(p, NtConstantMinTypMaxExpression)
         add(mtm.sons, first)
         get_token(p)
         add(mtm.sons, parse_constant_expression(p))
         expect_token(p, result, TkColon)
         get_token(p)
         add(mtm.sons, parse_constant_expression(p))
         add(result.sons, mtm)
      else:
         add(result.sons, first)

   expect_token(p, result, TkRparen)
   get_token(p)


proc parse_constant_primary(p: var Parser): PNode =
   result = new_node(p, NtConstantPrimary)

   case p.tok.type
   of TkOperator:
      # Prefix node
      let n = new_node(p, NtPrefix)
      add(n.sons, new_identifier_node(p, NtIdentifier))
      get_token(p)
      if p.tok.type == TkLparenStar:
         add(n.sons, parse_attribute_instances(p))
      add(n.sons, parse_constant_primary(p))
      add(result.sons, n)
   of TkSymbol:
      # FIXME: We have no way of knowing if this is a _valid_ (constant) symbol:
      #        genvar, param or specparam.
      add(result.sons, parse_constant_primary_identifier(p))
      if p.tok.type == TkLbracket:
         add(result.sons, parse_constant_range_expression(p))
   of TkLbrace:
      add(result.sons, parse_constant_multiple_or_regular_concatenation(p))
   of TkLparen:
      # Handle parenthesis, the token is required when constructing a
      # min-typ-max expression and optional when indicating expression
      # precedence.
      result = parse_parenthesis(p)
   of NumberTokens:
      add(result.sons, parse_number(p))
   else:
      unexpected_token(p, result)


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
   add(result.sons, parse_parameter_assignment(p))
   while true:
      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)
      add(result.sons, parse_parameter_assignment(p))


proc parse_parameter_port_list(p: var Parser): PNode =
   result = new_node(p, NtModuleParameterPortList)
   expect_token(p, result, TkHash)
   get_token(p)
   expect_token(p, result, TkLparen)
   get_token(p)

   # Parse the contents, at least one parameter declaration is expected.
   add(result.sons, parse_parameter_declaration(p))

   while true:
      if p.tok.type == TkComma:
         # If the token is a comma, the current cannot be anything other than
         # the keyword 'parameter'.
         get_token(p)
         expect_token(p, result, TkParameter)
         add(result.sons, parse_parameter_declaration(p))
      else:
         # If token is not a comma, we expect a closing parenthesis.
         expect_token(p, result, TkRparen)
         get_token(p)
         break


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
   expect_token(p, result, TkSymbol)
   add(result.sons, new_identifier_node(p, NtPortIdentifier))
   get_token(p)
   while true:
      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)
      add(result.sons, new_identifier_node(p, NtPortIdentifier))
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
   expect_token(p, result, TkSymbol)
   add(result, new_identifier_node(p, NtPortIdentifier))
   get_token(p)

   while true:
      if not look_ahead(p, TkComma, TkSymbol):
         break
      get_token(p)

      expect_token(p, result, TkSymbol)
      add(result, new_identifier_node(p, NtPortIdentifier))
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


proc parse_port_declaration(p: var Parser): PNode =
   var attributes: seq[PNode] = @[]
   if p.tok.type == TkLparenStar:
      add(attributes, parse_attribute_instances(p))

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

   expect_token(p, result, {TkInout, TkInput, TkOutput, TkLparenStar})
   add(result.sons, parse_port_declaration(p))
   while true:
      if p.tok.type == TkComma:
         get_token(p)
         expect_token(p, result, {TkInout, TkInput, TkOutput})
         add(result.sons, parse_port_declaration(p))
      else:
         break


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

   # FIXME: Restructure
   add(result.sons, parse_port(p))
   while true:
      case p.tok.type
      of TkComma:
         get_token(p)
      else:
         break # FIXME: Error?

      add(result.sons, parse_port(p))


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


proc parse_module_declaration(p: var Parser, attributes: seq[PNode]): PNode =
   result = new_node(p, NtModuleDecl)
   if len(attributes) > 0:
      add(result.sons, attributes)

   # Expect an idenfitier as the first token after the module keyword.
   get_token(p)
   expect_token(p, result, TkSymbol)
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
   of NtListOfPorts, NtListOfPortDeclarations:
      parse_proc = parse_list_of_ports_or_port_declarations
   of NtModuleParameterPortList:
      parse_proc = parse_parameter_port_list
   of NtConstantExpression:
      parse_proc = parse_constant_expression
   else:
      parse_proc = nil

   if parse_proc != nil:
      # Expect only one top-level statement per call.
      get_token(p)
      result = parse_proc(p)
   else:
      result = new_error_node(p, "Unsupported specific grammar '$1'.", $`type`)

   close_parser(p)

