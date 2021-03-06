import strutils
import math
import bignum
import macros

import ./ast
import ./lexer
export lexer, ast

type
   ExpressionContext* = object
      ast_context: AstContext
      kind: TokenKind
      size: int
      allow_unsized: bool
      allow_real: bool
      allow_zero_replication: bool

const
   INTEGER_BITS* = 32

   ConversionFunctions = ["unsigned", "signed", "rtoi", "itor", "realtobits", "bitstoreal"]

   RealMathFunctions = ["ln", "log10", "exp", "sqrt", "pow", "floor", "ceil", "sin", "cos", "tan",
                        "asin", "acos", "atan", "atan2", "hypot", "sinh", "cosh", "tanh", "asinh",
                        "acosh", "atanh"]


proc init(context: var ExpressionContext) =
   set_len(context.ast_context, 0)
   context.kind = TkInvalid
   context.size = -1
   context.allow_unsized = true
   context.allow_real = true
   context.allow_zero_replication = false


proc new_expression_context(ast_context: AstContext): ExpressionContext =
   ## Create a default expression context initialized with the input AST context.
   init(result)
   result.ast_context = ast_context


# Forward declarations
proc evaluate_constant_expression*(n: PNode, context: ExpressionContext): Token
proc determine_kind_and_size*(n: PNode, context: AstContext): tuple[kind: TokenKind, size: int]
proc determine_expression_kind(x, y: TokenKind): TokenKind


template evaluate_constant_expression*(n: PNode, ast_context: AstContext, tkind: TokenKind, tsize: int): Token =
   ## Shorthand to create a self-determined expression with a target
   ## ``ast_context``, ``kind`` and ``size``.
   var context = new_expression_context(ast_context)
   context.kind = tkind
   context.size = tsize
   evaluate_constant_expression(n, context)


template evaluate_constant_expression*(n: PNode, ast_context: AstContext): Token =
   ## Shorthand to create a self-determined expression with a target
   ## ``ast_context``.
   let (kind, size) = determine_kind_and_size(n, ast_context)
   evaluate_constant_expression(n, ast_context, kind, size)


proc new_evaluation_error(msg: string, args: varargs[string, `$`]): ref EvaluationError =
   new result
   result.msg = format(msg, args)


proc to_binary_literal(tok: Token): string =
   ## Convert a token's literal value (string) into binary representation.
   proc conversion_helper(literal: string, nof_bits_per_char: int): string =
      for c in literal:
         if c in ZChars + XChars:
            add(result, repeat(c, nof_bits_per_char))
         else:
            try:
               add(result, to_bin(from_hex[BiggestInt]($c), nof_bits_per_char))
            except ValueError:
               raise new_evaluation_error("Failed to convert literal '$1' to a binary literal.", literal)

   case tok.base
   of Base10:
      if tok.kind notin AmbiguousTokens:
         result = `$`(new_int(tok.literal) and new_int(repeat('1', tok.size), base = 2), base = 2)
      else:
         result = repeat(tok.literal[0], tok.size)
         return
   of Base2:
      result = tok.literal
   of Base8:
      result = conversion_helper(tok.literal, 3)
   of Base16:
      result = conversion_helper(tok.literal, 4)

   # As per Section 3.5.1 in the standard, if the size of the literal is
   # smaller than the specified size of the token, we left-pad with zeros.
   # Otherwise, we truncate from the left.
   let delta = tok.size - len(result)
   if delta > 0:
      result = repeat('0', delta) & result
   else:
      result = result[-delta..^1]


proc extend_or_truncate(tok: var Token, kind: TokenKind, size: int) =
   if size <= 0:
      raise new_evaluation_error("Cannot extend or truncate to size '$1'.", size)

   # To make this easy, we will represent the value as a binary encoded string.
   # If the target expression is signed, then we sign extend the value up to the
   # given size. If the size is smaller than the current size of the token, the
   # value is truncated from the left.
   var literal = to_binary_literal(tok)
   let sign_character = if kind in SignedTokens:
      literal[0]
   else:
      '0'

   let extended_length = size - len(literal)
   if extended_length > 0:
      literal = repeat(sign_character, extended_length) & literal
   else:
      literal = literal[abs(extended_length)..^1]

   tok.size = size
   tok.base = Base2
   tok.literal = literal


proc to_gmp_int(tok: Token): Int =
   ## Convert the integer token ``tok`` into a GMP integer ready for
   ## calculations. The numerical base is assumed to be ``Base2`` (binary encoded
   ## literal value).
   result = new_int()
   case tok.kind
   of TkIntLit:
      # The token is signed, check the sign bit. If it's set, we manipulate the
      # literal.
      if tok.literal[0] == '1':
         let sign = "-1" & repeat("0", tok.size - 1)
         let literal = '0' & tok.literal[1..^1]
         result = new_int(sign, base = 2) + new_int(literal, base = 2)
      else:
         result = new_int(tok.literal, base = 2)
   of TkUIntLit:
      # The token is unsigned.
      result = new_int(tok.literal, base = 2)
   else:
      # FIXME: Exception
      discard


proc from_gmp_int(tok: var Token, i: Int) =
   ## Convert a GMP integer into a binary literal that matches the token's size.
   tok.literal = `$`(i and new_int(repeat('1', tok.size), base = 2), base = 2)
   extend_or_truncate(tok, tok.kind, tok.size)


proc from_gmp_int(tok: var Token, b: bool) =
   tok.literal = if b: "1" else: "0"
   extend_or_truncate(tok, tok.kind, tok.size)


proc via_gmp_int(tok: Token): int =
   if tok.kind notin IntegerTokens or tok.kind in AmbiguousTokens:
      raise new_evaluation_error("Cannot interpret token '$1' as a GMP integer.", $tok.kind)

   let gmp_int = to_gmp_int(tok)
   if not fits_int(gmp_int):
      raise new_evaluation_error("GMP integer too big to fit into type 'int'.")
   result = to_int(gmp_int)


proc via_gmp_uint(tok: Token): uint64 =
   if tok.kind notin IntegerTokens or tok.kind in AmbiguousTokens:
      raise new_evaluation_error("Cannot interpret token '$1' as a GMP integer.", $tok.kind)

   let gmp_int = to_gmp_int(tok)
   let masked_gmp_int = gmp_int div new_int('1' & repeat('0', 64), base = 2)
   if not is_zero(masked_gmp_int):
      raise new_evaluation_error("GMP integer too big to fit into type 'uint64'.")
   result = parse_biggest_uint(`$`(gmp_int, base = 10))


proc convert(tok: Token, kind: TokenKind, size: int): Token =
   ## Convert the integer token to the target kind and size. If the target kind
   ## is signed, the resulting token will be sign extended. An unsigned integer
   ## is exteded with zeros and a signed integer is extended with its sign bit.
   ## If the target size is smaller than the size of the integer, the value is
   ## truncated. If the target kind is real, the integer just gets converted via
   ## the GMP functions.
   # TODO: Think about if it's worth warning about truncated values?
   result = tok
   case kind
   of TkUIntLit, TkAmbUIntLit:
      # The result should be unsigned, check what the token is.
      if tok.kind in AmbiguousTokens:
         result.kind = TkAmbUIntLit
      else:
         result.kind = TkUIntLit
      extend_or_truncate(result, kind, size)
      # If it turns out that truncation removed the ambiguous characters, we
      # remove the ambiguity identifier.
      if XChars + ZChars notin result.literal:
         result.kind = TkUIntLit
   of TkIntLit, TkAmbIntLit:
      # The result should be signed, check what the token is.
      if tok.kind in AmbiguousTokens:
         result.kind = TkAmbIntLit
      else:
         result.kind = TkIntLit
      extend_or_truncate(result, kind, size)
      if XChars + ZChars notin result.literal:
         result.kind = TkIntLit
   of TkRealLit:
      result = convert(result, result.kind, result.size)
      let fnumber = to_float(new_rat(to_gmp_int(result)))
      init(result)
      result.fnumber = fnumber
      result.literal = $result.fnumber
      result.kind = TkRealLit
      result.size = -1
   else:
      discard


proc set_ambiguous*(tok: var Token) =
   lexer.set_ambiguous(tok.kind)
   if tok.kind in IntegerTokens:
      tok.literal = repeat('x', tok.size)


macro make_prefix(x: typed, op: string): untyped =
   result = new_nim_node(nnkPrefix)
   add(result, new_ident_node(op.str_val))
   add(result, x)


macro make_infix(x, y: typed, op: string): untyped =
   result = new_nim_node(nnkInfix)
   add(result, new_ident_node(op.str_val))
   add(result, x)
   add(result, y)


template unary_sign(n: PNode, context: ExpressionContext, op: string): Token =
   init(result)
   let tok = evaluate_constant_expression(n, context)
   result.kind = context.kind
   result.size = context.size

   case context.kind
   of TkIntLit, TkUIntLit:
      result.base = Base2
      when op == "+":
         result.literal = tok.literal
      else:
         from_gmp_int(result, make_prefix(to_gmp_int(tok), op))
   of TkRealLit:
      result.fnumber = make_prefix(tok.fnumber, op)
      result.literal = $result.fnumber
   of AmbiguousTokens:
      result.base = Base2
      set_ambiguous(result)
   else:
      raise new_evaluation_error("Unary operator '$1' cannot yield kind '$2'.", op, $context.kind)
   result


proc binary_negation(n: PNode, context: ExpressionContext): Token =
   init(result)
   let tok = evaluate_constant_expression(n, context)
   result.kind = context.kind
   result.size = context.size

   case context.kind
   of IntegerTokens:
      result.base = Base2
      for c in tok.literal:
         case c
         of '0':
            add(result.literal, '1')
         of '1':
            add(result.literal, '0')
         of ZChars, XChars:
            add(result.literal, 'x')
         else:
            raise new_evaluation_error("Invalid binary literal character '$1'.", c)
      extend_or_truncate(result, result.kind, result.size)
   else:
      raise new_evaluation_error("Bitwise negation cannot yield kind '$1'.", $context.kind)


proc logical_negation(n: PNode, context: ExpressionContext): Token =
   init(result)
   # The operand is self-determined in a logical negation.
   let tok = evaluate_constant_expression(n, context.ast_context)
   result.kind = TkUIntLit
   result.size = 1

   case tok.kind
   of TkIntLit, TkUIntLit:
      if is_zero(to_gmp_int(tok)):
         from_gmp_int(result, new_int(1))
      else:
         from_gmp_int(result, new_int(0))
   of TkRealLit:
      if tok.fnumber != 0.0:
         from_gmp_int(result, new_int(0))
      else:
         from_gmp_int(result, new_int(1))
   of AmbiguousTokens:
      result.base = Base2
      set_ambiguous(result)
   else:
      raise new_evaluation_error("Logical negation cannot parse kind '$1'.", $tok.kind)


template unary_reduction(n: PNode, context: ExpressionContext, op: string): Token =
   init(result)
   # The operand is self-determined in a unary reduction.
   let tok = evaluate_constant_expression(n, context.ast_context)
   result.kind = TkUIntLit
   result.size = 1

   case tok.kind
   of TkIntLit, TkUIntLit:
      # FIXME: Assert len > 0?
      var carry = ord(tok.literal[^1]) - ord('0')
      for i in 2..len(tok.literal):
         let c = ord(tok.literal[^i]) - ord('0')
         carry = make_infix(carry, c , op)
      from_gmp_int(result, new_int(carry))
   of TkAmbIntLit, TkAmbUIntLit:
      result.base = Base2
      set_ambiguous(result)
   else:
      raise new_evaluation_error("Unary reduction cannot parse kind '$1'.", $tok.kind)
   result


proc evaluate_constant_prefix(n: PNode, context: ExpressionContext): Token =
   template invert(result: Token) =
      if result.kind == TkUIntLit:
         if result.literal[0] == '0':
            result.literal = "1"
         else:
            result.literal = "0"

   init(result)
   let op_idx = find_first_index(n, NkIdentifier)
   let expression_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   if op_idx < 0 or expression_idx < 0:
      raise new_evaluation_error("Invalid infix node.")

   let expression = n[expression_idx]
   let op = n[op_idx].identifier.s
   case op
   of "+":
      result = unary_sign(expression, context, "+")
   of "-":
      result = unary_sign(expression, context, "-")
   of "~":
      result = binary_negation(expression, context)
   of "!":
      result = logical_negation(expression, context)
   of "&":
      result = unary_reduction(expression, context, "and")
   of "|":
      result = unary_reduction(expression, context, "or")
   of "^":
      result = unary_reduction(expression, context, "xor")
   of "~&":
      result = unary_reduction(expression, context, "and")
      invert(result)
   of "~|":
      result = unary_reduction(expression, context, "or")
      invert(result)
   of "~^", "^~":
      result = unary_reduction(expression, context, "xor")
      invert(result)
   else:
      raise new_evaluation_error("Prefix operator '$1' not implemented.", op)


template infix_operation(x, y: PNode, context: ExpressionContext, iop, fop: string): Token =
   init(result)
   let xtok = evaluate_constant_expression(x, context)
   let ytok = evaluate_constant_expression(y, context)
   result.kind = context.kind
   result.size = context.size

   case context.kind
   of TkIntLit, TkUIntLit:
      let ytok_int = to_gmp_int(ytok)
      if iop == "div" and is_zero(ytok_int):
         result.base = Base2
         set_ambiguous(result)
      else:
         result.base = Base2
         from_gmp_int(result, make_infix(to_gmp_int(xtok), ytok_int, iop))
   of TkRealLit:
      if fop == "/" and ytok.fnumber == 0.0:
         set_ambiguous(result)
      else:
         result.fnumber = make_infix(xtok.fnumber, ytok.fnumber, fop)
         result.literal = $result.fnumber
   of AmbiguousTokens - {TkAmbRealLit}:
      result.base = Base2
      set_ambiguous(result)
   of TkAmbRealLit:
      set_ambiguous(result)
   else:
      raise new_evaluation_error("Infix operation '$1'/'$2' cannot yield kind '$3'.", iop, fop, $context.kind)
   result


template infix_operation(x, y: PNode, context: ExpressionContext, op: string): Token =
   infix_operation(x, y, context, op, op)


proc modulo(x, y: PNode, context: ExpressionContext): Token =
   init(result)
   let xtok = evaluate_constant_expression(x, context)
   let ytok = evaluate_constant_expression(y, context)
   result.kind = context.kind
   result.size = context.size
   result.base = Base2

   let ytok_int = to_gmp_int(ytok)
   case context.kind
   of IntegerTokens:
      if context.kind in AmbiguousTokens or is_zero(ytok_int):
         set_ambiguous(result)
      else:
         # The modulo operation always takes the sign of the first operand. This
         # is exactly how GMP's mod operation behaves so we just use it directly.
         from_gmp_int(result, to_gmp_int(xtok) mod ytok_int)
   else:
      raise new_evaluation_error("Modulo operation not allowed for kind '$1'.", $context.kind)


proc power(x, y: PNode, context: ExpressionContext): Token =
   init(result)
   let xtok = evaluate_constant_expression(x, context)
   # The second operand is always self-determined, so we don't pass the
   # context's kind and size when evaluating this operand.
   let ytok = evaluate_constant_expression(y, context.ast_context)

   if context.kind in AmbiguousTokens:
      result.kind = context.kind
      set_ambiguous(result)

   elif xtok.kind == TkRealLit and ytok.kind == TkRealLit:
      result.kind = TkRealLit
      result.size = -1
      if (xtok.fnumber == 0.0 and ytok.fnumber < 0) or (xtok.fnumber < 0):
         set_ambiguous(result)
      else:
         result.fnumber = pow(xtok.fnumber, ytok.fnumber)
         result.literal = $result.fnumber

   elif xtok.kind == TkRealLit:
      result.kind = TkRealLit
      result.size = -1
      let ytok_float = to_float(new_rat(to_gmp_int(ytok)))
      if (xtok.fnumber == 0.0 and ytok_float < 0.0) or (xtok.fnumber < 0):
         set_ambiguous(result)
      else:
         result.fnumber = pow(xtok.fnumber, ytok_float)
         result.literal = $result.fnumber

   elif ytok.kind == TkRealLit:
      result.kind = TkRealLit
      result.size = -1
      let xtok_float = to_float(new_rat(to_gmp_int(xtok)))
      if xtok_float < 0.0:
         set_ambiguous(result)
      else:
         result.fnumber = pow(xtok_float, ytok.fnumber)
         result.literal = $result.fnumber

   elif xtok.kind in IntegerTokens and ytok.kind in IntegerTokens:
      result.kind = context.kind
      result.size = context.size
      result.base = Base2
      let xtok_int = to_gmp_int(xtok)
      let ytok_int = to_gmp_int(ytok)

      if xtok_int < -1 or xtok_int > 1:
         if ytok_int > 0:
            if not fits_culong(ytok_int):
               raise new_evaluation_error("Exponent too large, a value < $1 is required.", high(culong))
            # FIXME: If the result is really big, libgmp will terminate w/
            # SIGABRT. We'd have to install a signal handler to catch this
            # event.
            from_gmp_int(result, xtok_int ^ to_culong(ytok_int))
         elif ytok_int == 0:
            from_gmp_int(result, new_int(1))
         else:
            from_gmp_int(result, new_int(0))
      elif xtok_int == -1:
         if ytok_int == 0:
            from_gmp_int(result, new_int(1))
         elif (ytok_int mod 2) == 0:
            from_gmp_int(result, new_int(1))
         else:
            from_gmp_int(result, new_int(-1))
      elif xtok_int == 0:
         if ytok_int > 0:
            from_gmp_int(result, new_int(0))
         elif ytok_int == 0:
            from_gmp_int(result, new_int(1))
         else:
            result.base = Base2
            set_ambiguous(result)
      elif xtok_int == 1:
         from_gmp_int(result, new_int(1))

   else:
      raise new_evaluation_error("Power operation not allowed for kind '$1'.", $context.kind)


template logical_operation(x, y: PNode, context: ExpressionContext, op: string): Token =
   init(result)
   # The operands are self-determined in a logical operation.
   let xtok = evaluate_constant_expression(x, context.ast_context)
   let ytok = evaluate_constant_expression(y, context.ast_context)
   result.kind = TkUIntLit
   result.size = 1

   var ambiguous = false
   let xres = case xtok.kind
   of TkIntLit, TkUIntLit:
      not is_zero(to_gmp_int(xtok))
   of TkRealLit:
      xtok.fnumber != 0.0
   of AmbiguousTokens:
      ambiguous = true
      false
   else:
      raise new_evaluation_error("Logical operation cannot parse kind '$1'.", $xtok.kind)

   let yres = case ytok.kind
   of TkIntLit, TkUIntLit:
      not is_zero(to_gmp_int(ytok))
   of TkRealLit:
      ytok.fnumber != 0.0
   of AmbiguousTokens:
      ambiguous = true
      false
   else:
      raise new_evaluation_error("Logical operation cannot parse kind '$1'.", $ytok.kind)

   if ambiguous:
      result.base = Base2
      set_ambiguous(result)
   else:
      result.base = Base2
      from_gmp_int(result, make_infix(xres, yres, op))
   result


template relational_operation(x, y: PNode, context: ExpressionContext, op: string, allow_ambiguous: bool = false): Token =
   init(result)
   # Operands are self-determined and sized to max(x, y).
   let xprop = determine_kind_and_size(x, context.ast_context)
   let yprop = determine_kind_and_size(y, context.ast_context)
   let kind = determine_expression_kind(xprop.kind, yprop.kind)
   let size = max(xprop.size, yprop.size)
   let xtok = evaluate_constant_expression(x, context.ast_context, kind, size)
   let ytok = evaluate_constant_expression(y, context.ast_context, kind, size)
   result.base = Base2
   result.kind = TkUIntLit
   result.size = 1

   case kind
   of TkIntLit, TkUIntLit:
      result.literal = $ord(make_infix(to_gmp_int(xtok), to_gmp_int(ytok), op))
   of TkRealLit:
      result.literal = $ord(make_infix(xtok.fnumber, ytok.fnumber, op))
   of AmbiguousTokens:
      if allow_ambiguous:
         let xliteral = to_binary_literal(xtok)
         let yliteral = to_binary_literal(ytok)
         result.literal = $ord(make_infix(xliteral, yliteral, op))
      else:
         result.base = Base2
         set_ambiguous(result)
   else:
      raise new_evaluation_error("Relational operator '$1' cannot parse kind '$2'.", op, $kind)
   result


proc evaluate_constant_infix(n: PNode, context: ExpressionContext): Token =
   let op_idx = find_first_index(n, NkIdentifier)
   let lhs_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if op_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid infix node.")

   let lhs = n[lhs_idx]
   let rhs = n[rhs_idx]
   let op = n[op_idx].identifier.s
   case op
   of "+":
      result = infix_operation(lhs, rhs, context, "+")
   of "-":
      result = infix_operation(lhs, rhs, context, "-")
   of "/":
      result = infix_operation(lhs, rhs, context, "div", "/")
   of "*":
      result = infix_operation(lhs, rhs, context, "*")
   of "%":
      result = modulo(lhs, rhs, context)
   of "**":
      result = power(lhs, rhs, context)
   of "&&":
      result = logical_operation(lhs, rhs, context, "and")
   of "||":
      result = logical_operation(lhs, rhs, context, "or")
   of ">":
      result = relational_operation(lhs, rhs, context, ">")
   of ">=":
      result = relational_operation(lhs, rhs, context, ">=")
   of "<":
      result = relational_operation(lhs, rhs, context, "<")
   of "<=":
      result = relational_operation(lhs, rhs, context, "<=")
   of "==":
      result = relational_operation(lhs, rhs, context, "==")
   of "!=":
      result = relational_operation(lhs, rhs, context, "!=")
   of "===":
      result = relational_operation(lhs, rhs, context, "==", allow_ambiguous = true)
   of "!==":
      result = relational_operation(lhs, rhs, context, "!=", allow_ambiguous = true)
   else:
      raise new_evaluation_error("Infix operator '$1' not implemented.", op)


proc evaluate_constant_function_call(n: PNode, context: ExpressionContext): Token =
   # FIXME: Implement
   raise new_evaluation_error("Constant function calls are not supported.")


proc evaluate_constant_identifier(n: PNode, context: ExpressionContext): Token =
   # To evaluate a constant identifier we look up its declaration in the context
   # and evaluate what we find.
   let (declaration, _, expression, _) = find_declaration(context.ast_context, n.identifier)
   if is_nil(declaration):
      raise new_evaluation_error("Failed to find the declaration of identifier '$1'.", n.identifier)
   if is_nil(expression):
      raise new_evaluation_error("The declaration of '$1' does not contain an expression.", n.identifier)
   result = evaluate_constant_expression(expression, context)


proc evaluate_constant_multiple_concat(n: PNode, context: ExpressionContext): Token =
   init(result)
   let constant_idx = find_first_index(n, ExpressionTypes)
   let concat_idx = find_first_index(n, NkConstantConcat, constant_idx + 1)
   if constant_idx < 0 or concat_idx < 0:
      raise new_evaluation_error("Invalid multiple concatenation node.")

   # The replication constant is self-determined and so is the concatenation.
   # The multiplier has to be nonnegative and not ambiguous. We also assume that
   # the multiplier fits in an int.
   let constant_tok = evaluate_constant_expression(n[constant_idx], context.ast_context)
   if constant_tok.kind in AmbiguousTokens:
      raise new_evaluation_error("Replication constant cannot be ambiguous.")
   let constant = via_gmp_int(constant_tok)
   if constant < 0:
      raise new_evaluation_error("Replication constant cannot be negative.")
   elif constant == 0:
      if context.allow_zero_replication:
         result.kind = TkInvalid
         result.size = 0
         return
      else:
         raise new_evaluation_error("Replication with zero is not allowed in this context.")

   let concat_tok = evaluate_constant_expression(n[concat_idx], context.ast_context)
   for i in 0..<constant:
      add(result.literal, concat_tok.literal)

   result.kind = context.kind
   result.size = len(result.literal)
   result.base = Base2
   result = convert(result, context.kind, context.size)


proc evaluate_constant_concat(n: PNode, context: ExpressionContext): Token =
   # In constant concatenation, each son is expected to be a constant
   # expression. We work with the literal value, reading the expressions from
   # left to right, concatenating the literal value as we go. All the
   # expressions are self determined.
   init(result)
   result.kind = context.kind
   result.base = Base2
   result.size = context.size

   # Create a new expression context that allows replication with zero.
   var lcontext = new_expression_context(context.ast_context)
   lcontext.allow_zero_replication = true
   lcontext.allow_unsized = false
   lcontext.allow_real = false
   var idx = -1
   var valid = false
   while true:
      idx = find_first_index(n, ExpressionTypes, idx + 1)
      if idx < 0:
         break
      valid = true
      # The constant expression is self-determined and replication with zero is
      # allowed in this context.
      (lcontext.kind, lcontext.size) = determine_kind_and_size(n[idx], lcontext.ast_context)
      let tok = evaluate_constant_expression(n[idx], lcontext)
      add(result.literal, tok.literal)

   if not valid or len(result.literal) == 0:
      raise new_evaluation_error("A constant concatenation must contain at least one expression " &
                                 "with a positive size.")

   result.kind = context.kind
   result.size = context.size
   result.base = Base2
   result = convert(result, context.kind, context.size)


proc parse_range_infix(n: PNode, context: AstContext): tuple[low, high: int] =
   ## Parse the infix node ``n``, allowing the operators ':', '+:' and '-:' in
   ## additional to all the others.
   let op_idx = find_first_index(n, NkIdentifier)
   let lhs_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if op_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid range.")

   let lhs_tok = evaluate_constant_expression(n[lhs_idx], context)
   let rhs_tok = evaluate_constant_expression(n[rhs_idx], context)
   case n[op_idx].identifier.s
   of "+:":
      # Expressions like [8 +: 8]
      result.low = via_gmp_int(lhs_tok)
      result.high = result.low + via_gmp_int(rhs_tok)
   of "-:":
      # Expressions like [15 -: 8]
      result.high = via_gmp_int(lhs_tok)
      result.low = result.high - via_gmp_int(rhs_tok)
   of ":":
      # Expressions like [3 : 0]
      result.low = via_gmp_int(rhs_tok)
      result.high = via_gmp_int(lhs_tok)
   else:
      # Expressions like [3 + (6/2)]
      let tok = evaluate_constant_expression(n, context)
      result.low = via_gmp_int(tok)
      result.high = result.low


proc parse_range(n: PNode, context: AstContext): tuple[low, high: int] =
   # We expect either an infix node or a regular expression node.
   case n.kind
   of NkInfix:
      result = parse_range_infix(n, context)
   of ExpressionTypes - {NkInfix}:
      let tok = evaluate_constant_expression(n, context)
      result.low = via_gmp_int(tok)
      result.high = result.low
   else:
      raise new_evaluation_error("Invalid range.")


proc evaluate_constant_bracket_expression(n: PNode, context: ExpressionContext): Token =
   let id_idx = find_first_index(n, NkIdentifier)
   let range_idx = find_first_index(n, ExpressionTypes, id_idx + 1)
   if id_idx < 0 or range_idx < 0:
      raise new_evaluation_error("Invalid ranged identifier node.")

   # Evaluating a constant ranged identifier consists of finding the constant
   # value of the identifier, then extracting the bits between the start and
   # stop indexes.
   let id = n[id_idx]
   result = evaluate_constant_expression(id, context.ast_context)
   let (low, high) = parse_range(n[range_idx], context.ast_context)
   if low < 0 or low >= result.size:
      raise new_evaluation_error("Low index '$1' out of range for identifier '$2'.", low, id.identifier.s)
   elif high < 0 or high >= result.size:
      raise new_evaluation_error("High index '$1' out of range for identifier '$2'.", high, id.identifier.s)

   result.literal = result.literal[^(high + 1)..^(low + 1)]
   result = convert(result, context.kind, context.size)


proc collect_arguments(n: PNode, nof_arguments, start: int): seq[PNode] =
   for i, s in walk_sons_index(n, ExpressionTypes, start):
      add(result, s)

   if len(result) != nof_arguments:
      let str = if len(result) < nof_arguments: "few" else: "many"
      raise new_evaluation_error("Too $1 arguments in function call.", str)


proc signed_unsigned(n: PNode, context: ExpressionContext, id_idx: int): Token =
   init(result)
   let arg = collect_arguments(n, 1, id_idx + 1)[0]
   var tok = evaluate_constant_expression(arg, context.ast_context)
   if tok.kind notin IntegerTokens:
      raise new_evaluation_error("The expression must yield an integer.")

   if n[id_idx].identifier.s == "unsigned":
      set_unsigned(tok.kind)
   else:
      set_signed(tok.kind)
   result = convert(tok, context.kind, context.size)


proc rtoi(n: PNode, context: ExpressionContext, id_idx: int): Token =
   init(result)
   # Conversion is done by truncating to the decimal point. We reset the
   # token after making a copy of the floting point value.
   let arg = collect_arguments(n, 1, id_idx + 1)[0]
   let tok = evaluate_constant_expression(arg, context.ast_context)
   if tok.kind != TkRealLit:
      raise new_evaluation_error("The expression must yield a real value.")
   init(result)
   result.kind = TkIntLit
   result.size = INTEGER_BITS
   result.base = Base2
   from_gmp_int(result, to_int(new_rat(trunc(tok.fnumber))))
   result = convert(result, context.kind, context.size)


proc itor(n: PNode, context: ExpressionContext, id_idx: int): Token =
   init(result)
   # The conversion to real happens in the call to convert() below since real
   # has the highest preceedence. Basically, it's guaranteed that
   # context.kind == TkRealLit. However, we do have to ensure that the token
   # is an unambiguous integer.
   let arg = collect_arguments(n, 1, id_idx + 1)[0]
   let tok = evaluate_constant_expression(arg, context.ast_context)
   if tok.kind notin IntegerTokens - AmbiguousTokens:
      raise new_evaluation_error("The argument must be an unambiguous integer value.")
   result = convert(tok, context.kind, context.size)


proc realtobits(n: PNode, context: ExpressionContext, id_idx: int): Token =
   init(result)
   let arg = collect_arguments(n, 1, id_idx + 1)[0]
   let tok = evaluate_constant_expression(arg, context.ast_context)
   if tok.kind != TkRealLit:
      raise new_evaluation_error("The expression must yield a real value.")
   # Since Nim uses IEEE 754 to represent floating point values we just cast
   # the token's value to a 64-bit integer.
   result.kind = TkUIntLit
   result.size = 64
   result.base = Base2
   from_gmp_int(result, new_int($to_hex(cast[uint64](tok.fnumber)), base = 16))
   result = convert(result, context.kind, context.size)


proc bitstoreal(n: PNode, context: ExpressionContext, id_idx: int): Token =
   init(result)
   # The argument is interpreted as an unsigned 64-bit value. We reevaluate
   # the expression in that context and interpret the bitpattern as an IEEE
   # 754 floating point number.
   let arg = collect_arguments(n, 1, id_idx + 1)[0]
   let (_, size) = determine_kind_and_size(arg, context.ast_context)
   let tok = evaluate_constant_expression(arg, context.ast_context, TkUIntLit, max(64, size))
   if tok.kind notin IntegerTokens - AmbiguousTokens:
      raise new_evaluation_error("The argument must be an unambiguous integer value.")
   result.fnumber = cast[float64](via_gmp_uint(tok))
   result.literal = $result.fnumber
   result.size = -1
   result.kind = TkRealLit


proc evaluate_system_function_call_conversion(n: PNode, context: ExpressionContext): Token =
   let id_idx = find_first_index(n, NkIdentifier)
   if id_idx < 0:
      raise new_evaluation_error("Invalid constant system function call.")

   let function = n[id_idx].identifier.s
   case function
   of "unsigned", "signed":
      result = signed_unsigned(n, context, id_idx)
   of "rtoi":
      result = rtoi(n, context, id_idx)
   of "itor":
      result = itor(n, context, id_idx)
   of "realtobits":
      result = realtobits(n, context, id_idx)
   of "bitstoreal":
      result = bitstoreal(n, context, id_idx)
   else:
      raise new_evaluation_error("Unsupported conversion function '$1'.", function)


macro make_call(name: string, args: varargs[untyped]): untyped =
   result = new_nim_node(nnkCall)
   add(result, new_ident_node(name.str_val))
   for arg in args:
      add(result, arg)


template ensure_real(n: PNode, context: AstContext): Token =
   result = evaluate_constant_expression(n, context)
   if result.kind != TkRealLit:
      raise new_evaluation_error("Argument must be a real number.")
   result


template real_math(x: PNode, context: AstContext, op: string): untyped =
   let xtok = ensure_real(x, context)
   make_call(op, xtok.fnumber)


template real_math(x, y: PNode, context: AstContext, op: string): untyped =
   let xtok = ensure_real(x, context)
   let ytok = ensure_real(y, context)
   make_call(op, xtok.fnumber, ytok.fnumber)


template real_math_one_arg(n: PNode, context: AstContext, id_idx: int, op: string): untyped =
   let args = collect_arguments(n, 1, id_idx + 1)
   result.fnumber = real_math(args[0], context, op)
   result.literal = $result.fnumber


template real_math_two_args(n: PNode, context: AstContext, id_idx: int, op: string): untyped =
   let args = collect_arguments(n, 2, id_idx + 1)
   result.fnumber = real_math(args[0], args[1], context, op)
   result.literal = $result.fnumber


proc evaluate_system_function_call_real_math(n: PNode, context: ExpressionContext): Token =
   init(result)
   let id_idx = find_first_index(n, NkIdentifier)
   if id_idx < 0:
      raise new_evaluation_error("Invalid constant system function call.")

   result.kind = TkRealLit
   result.size = -1

   let id = n[id_idx]
   case id.identifier.s
   of "ln":
      real_math_one_arg(n, context.ast_context, id_idx, "ln")
   of "log10":
      real_math_one_arg(n, context.ast_context, id_idx, "log10")
   of "exp":
      real_math_one_arg(n, context.ast_context, id_idx, "exp")
   of "sqrt":
      real_math_one_arg(n, context.ast_context, id_idx, "sqrt")
   of "pow":
      real_math_two_args(n, context.ast_context, id_idx, "pow")
   of "floor":
      real_math_one_arg(n, context.ast_context, id_idx, "floor")
   of "ceil":
      real_math_one_arg(n, context.ast_context, id_idx, "ceil")
   of "sin":
      real_math_one_arg(n, context.ast_context, id_idx, "sin")
   of "cos":
      real_math_one_arg(n, context.ast_context, id_idx, "cos")
   of "tan":
      real_math_one_arg(n, context.ast_context, id_idx, "tan")
   of "asin":
      real_math_one_arg(n, context.ast_context, id_idx, "arcsin")
   of "acos":
      real_math_one_arg(n, context.ast_context, id_idx, "arccos")
   of "atan":
      real_math_one_arg(n, context.ast_context, id_idx, "arctan")
   of "atan2":
      real_math_two_args(n, context.ast_context, id_idx, "arctan2")
   of "hypot":
      real_math_two_args(n, context.ast_context, id_idx, "hypot")
   of "sinh":
      real_math_one_arg(n, context.ast_context, id_idx, "sinh")
   of "cosh":
      real_math_one_arg(n, context.ast_context, id_idx, "cosh")
   of "tanh":
      real_math_one_arg(n, context.ast_context, id_idx, "tanh")
   of "asinh":
      real_math_one_arg(n, context.ast_context, id_idx, "arcsinh")
   of "acosh":
      real_math_one_arg(n, context.ast_context, id_idx, "arccosh")
   of "atanh":
      real_math_one_arg(n, context.ast_context, id_idx, "arctanh")
   else:
      raise new_evaluation_error("Unsupported real function '$1'.", id.identifier.s)


proc clog2(n: PNode, context: ExpressionContext, id_idx: int): Token =
   init(result)
   result.base = Base2
   # The argument is always treated as an unsigned value. However, if it's
   # anything other than an unambiguous integer, it's an error.
   let arg = collect_arguments(n, 1, id_idx + 1)[0]
   let (kind, size) = determine_kind_and_size(arg, context.ast_context)
   if kind notin IntegerTokens - AmbiguousTokens:
      raise new_evaluation_error("The argument must be an unambiguous integer value.")

   let inumber = via_gmp_int(evaluate_constant_expression(arg, context.ast_context, TkUIntLit, size))
   let clog2_result = if inumber != 0:
      ceil(log2(to_biggest_float(inumber)))
   else:
      0

   result.kind = TkUIntLit
   result.size = size
   from_gmp_int(result, new_int(to_int(clog2_result)))
   result = convert(result, context.kind, context.size)


proc evaluate_system_function_call_integer_math(n: PNode, context: ExpressionContext): Token =
   init(result)
   let id_idx = find_first_index(n, NkIdentifier)
   if id_idx < 0:
      raise new_evaluation_error("Invalid constant system function call.")

   let id = n[id_idx]
   case id.identifier.s
   of "clog2":
      result = clog2(n, context, id_idx)
   else:
      raise new_evaluation_error("Unsupported integer function '$1'.", id.identifier.s)


proc evaluate_constant_system_function_call(n: PNode, context: ExpressionContext): Token =
   # The system functions allowed in a constant expression are conversion
   # functions and math functions.
   init(result)
   let id_idx = find_first_index(n, NkIdentifier)
   if id_idx < 0:
      raise new_evaluation_error("Invalid constant system function call.")

   let function = n[id_idx].identifier.s
   case function
   of ConversionFunctions:
      result = evaluate_system_function_call_conversion(n, context)
   of "clog2":
      result = evaluate_system_function_call_integer_math(n, context)
   of RealMathFunctions:
      result = evaluate_system_function_call_real_math(n, context)
   else:
      raise new_evaluation_error("Unsupported system function '$1'.", function)


proc evaluate_constant_conditional_expression(n: PNode, context: ExpressionContext): Token =
   init(result)
   let cond_idx = find_first_index(n, ExpressionTypes)
   let lhs_idx = find_first_index(n, ExpressionTypes, cond_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if cond_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid infix node.")

   # The condition is always self-determined.
   let cond_tok = evaluate_constant_expression(n[cond_idx], context.ast_context)
   # FIXME: There's something about the operands being zero-extended, regardless
   # of the sign of the surronding expression. That's not how it works currently.
   let rhs_tok = evaluate_constant_expression(n[rhs_idx], context.ast_context)
   let lhs_tok = evaluate_constant_expression(n[lhs_idx], context.ast_context)
   if cond_tok.kind in AmbiguousTokens:
      result.base = Base2
      result.kind = context.kind
      result.size = context.size
      if rhs_tok.kind in RealTokens or lhs_tok.kind in RealTokens:
         from_gmp_int(result, new_int(0))
      else:
         for i in 0..<context.size:
            if lhs_tok.literal[i] == '0' and rhs_tok.literal[i] == '0':
               add(result.literal, '0')
            elif lhs_tok.literal[i] == '1' and rhs_tok.literal[i] == '1':
               add(result.literal, '1')
            else:
               add(result.literal, 'x')
         if XChars in result.literal:
            lexer.set_ambiguous(result.kind)
         extend_or_truncate(result, result.kind, result.size)
   elif is_zero(to_gmp_int(cond_tok)):
      result = rhs_tok
   else:
      result = lhs_tok


proc evaluate_constant_expression(n: PNode, context: ExpressionContext): Token =
   ## Evalue the constant expression starting in ``n`` in the given ``context``.
   ## The result is represented using a Verilog ``Token`` and an
   ## ``EvaluationError`` is raised if the evaluation fails.
   if is_nil(n):
      raise new_evaluation_error("Invalid node (nil).")

   case n.kind
   of NkPrefix:
      result = evaluate_constant_prefix(n, context)
   of NkInfix:
      result = evaluate_constant_infix(n, context)
   of NkConstantFunctionCall:
      result = evaluate_constant_function_call(n, context)
   of NkIdentifier:
      result = evaluate_constant_identifier(n, context)
   of NkConstantMultipleConcat:
      result = evaluate_constant_multiple_concat(n, context)
   of NkConstantConcat:
      result = evaluate_constant_concat(n, context)
   of NkBracketExpression:
      result = evaluate_constant_bracket_expression(n, context)
   of NkConstantSystemFunctionCall:
      result = evaluate_constant_system_function_call(n, context)
   of NkParenthesis:
      result = evaluate_constant_expression(find_first(n, ExpressionTypes), context)
   of NkConstantConditionalExpression:
      result = evaluate_constant_conditional_expression(n, context)
   of NkStrLit:
      init(result)
      result.kind = TkStrLit
      result.literal = n.s
   of NkRealLit:
      if not context.allow_real:
         raise new_evaluation_error("A real value is not allowed in this context.")
      init(result)
      result.kind = TkRealLit
      result.fnumber = n.fnumber
      result.literal = n.fraw
   of IntegerTypes:
      init(result)
      result.kind = TokenKind(ord(TkIntLit) + ord(n.kind) - ord(NkIntLit))
      result.literal = n.iraw
      result.base = n.base
      result.size = if n.size < 0:
         if not context.allow_unsized:
            raise new_evaluation_error("An unsized integer is not allowed in this context.")
         INTEGER_BITS
      else:
         n.size
      # When we reach a primitive integer token, we convert the token into the
      # propagated kind and size. If the expression is signed, the token is sign
      # extended. If the integer is part of a real expression, we convert the
      # token to real after sign extending it as a self-determined operand.
      case context.kind
      of TkRealLit:
         result = convert(result, result.kind, result.size)
         result.fnumber = to_float(new_rat(to_gmp_int(result)))
         result.literal = $result.fnumber
         result.kind = TkRealLit
         result.size = -1
      of IntegerTokens:
         result = convert(result, context.kind, context.size)
      of TkAmbRealLit:
         discard
      else:
         raise new_evaluation_error("Cannot convert a primitive integer token to kind '$1'.", context.kind)
   else:
      raise new_evaluation_error("The node '$1' is not an expression.", n.kind)


proc determine_expression_kind(x, y: TokenKind): TokenKind =
   if x == TkRealLit or y == TkRealLit:
      # If any operand is real, the result is real. If any operand is
      # ambiguous (containing X or Z), the result is also ambiguous.
      if x in AmbiguousTokens or y in AmbiguousTokens:
         result = TkAmbRealLit
      else:
         result = TkRealLit
   elif x in UnsignedTokens or y in UnsignedTokens:
      # If any operand is unsigned, the result is unsigned. If any operand is
      # ambiguous (containing X or Z), the result is also ambiguous.
      if x in AmbiguousTokens or y in AmbiguousTokens:
         result = TkAmbUIntLit
      else:
         result = TkUIntLit
   elif x in SignedTokens and x in SignedTokens:
      # If both operands are signed, the result is signed. If any operand is
      # ambiguous, the result is also ambiguous.
      if x in AmbiguousTokens or y in AmbiguousTokens:
         result = TkAmbIntLit
      else:
         result = TkIntLit
   else:
      raise new_evaluation_error("Cannot determine expression kind of '$1' and '$2'.", $x, $y)


proc determine_kind_and_size_prefix(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   let op_idx = find_first_index(n, NkIdentifier)
   let expr_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   if op_idx < 0 or expr_idx < 0:
      raise new_evaluation_error("Invalid prefix node.")

   case n[op_idx].identifier.s
   of "+", "-", "~":
      result = determine_kind_and_size(n[expr_idx], context)
   of "&", "~&", "|", "~|", "^", "~^", "^~", "!":
      result.size = 1
      result.kind = TkUIntLit
   else:
      raise new_evaluation_error("Invalid prefix operator '$1'.", n[op_idx].identifier.s)


proc determine_kind_and_size_infix(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   let op_idx = find_first_index(n, NkIdentifier)
   let lhs_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if op_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid infix node.")

   let lhs = determine_kind_and_size(n[lhs_idx], context)
   let rhs = determine_kind_and_size(n[rhs_idx], context)
   let op = n[op_idx].identifier.s
   result.kind = determine_expression_kind(lhs.kind, rhs.kind)

   case op
   of "+", "-", "*", "/", "%", "&", "|", "^", "^~", "~^":
      result.size = max(lhs.size, rhs.size)
   of "===", "!==", "==", "!=", ">", ">=", "<", "<=", "&&", "||":
      result.size = 1
      result.kind = TkUIntLit
   of ">>", "<<", "**", ">>>", "<<<":
      result = lhs
   else:
      raise new_evaluation_error("Unsupported infix  operator '$1'.", op)

   if result.kind in RealTokens:
      result.size = -1


proc determine_kind_and_size_function_call(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   raise new_evaluation_error("Not implemented")


proc determine_kind_and_size_identifier(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   let (declaration, _, expression, _) = find_declaration(context, n.identifier)
   if is_nil(declaration):
      raise new_evaluation_error("Failed to find the declaration of identifier '$1'.", n.identifier)
   if is_nil(expression):
      raise new_evaluation_error("The declaration of '$1' does not contain an expression.", n.identifier)
   result = determine_kind_and_size(expression, context)


proc determine_kind_and_size_concat(n: PNode, context: AstContext): tuple[kind: TokenKind, size: int] =
   result = (TkInvalid, 0)
   for s in walk_sons(n, ExpressionTypes):
      let (kind, size) = determine_kind_and_size(s, context)
      if result.kind == TkInvalid:
         result.kind = kind
      else:
         result.kind = determine_expression_kind(result.kind, kind)
      inc(result.size, size)


proc determine_kind_and_size_multiple_concat(n: PNode, context: AstContext): tuple[kind: TokenKind, size: int] =
   let constant_idx = find_first_index(n, ExpressionTypes)
   let concat_idx = find_first_index(n, NkConstantConcat, constant_idx + 1)
   if constant_idx < 0 or concat_idx < 0:
      raise new_evaluation_error("Invalid multiple concatenation node.")

   let constant_tok = evaluate_constant_expression(n[constant_idx], context)
   let (kind, size) = determine_kind_and_size_concat(n[concat_idx], context)
   result.size = via_gmp_int(constant_tok) * size
   result.kind = kind


proc determine_kind_and_size_bracket_expression(n: PNode, context: AstContext): tuple[kind: TokenKind, size: int] =
   let id_idx = find_first_index(n, NkIdentifier)
   let range_idx = find_first_index(n, NkInfix, id_idx + 1)
   if id_idx < 0 or range_idx < 0:
      raise new_evaluation_error("Invalid ranged identifier node.")

   let id = n[id_idx]
   let tok = evaluate_constant_expression(id, context)
   let (low, high) = parse_range(n[range_idx], context)
   if low < 0 or low > tok.size:
      raise new_evaluation_error("Low index '$1' out of range for identifier '$2'.", low, id.identifier.s)
   elif high < 0 or high > tok.size:
      raise new_evaluation_error("High index '$1' out of range for identifier '$2'.", high, id.identifier.s)

   # The kind of part- or bit-select result is always unsigned, regardless of the operand.
   result.kind = TkUIntLit
   result.size = high - low + 1


proc determine_kind_and_size_system_function_call_conversion(n: PNode, context: AstContext):
                                                             tuple[kind: TokenKind, size: int] =
   let id_idx = find_first_index(n, NkIdentifier)
   let arg_idx = find_first_index(n, ExpressionTypes, id_idx + 1)
   if id_idx < 0 or arg_idx < 0:
      raise new_evaluation_error("Invalid constant system function call.")

   # The argument expression is self-determined.
   result = determine_kind_and_size(n[arg_idx], context)

   let function = n[id_idx].identifier.s
   case function
   of "unsigned":
      set_unsigned(result.kind)
   of "signed":
      set_signed(result.kind)
   of "rtoi":
      result = (TkIntLit, INTEGER_BITS)
   of "itor", "bitstoreal":
      result = (TkRealLit, -1)
   of "realtobits":
      result = (TkUIntLit, 64)
   else:
      raise new_evaluation_error("Unsupported conversion function '$1'.", function)


proc determine_kind_and_size_system_function_call(n: PNode, context: AstContext): tuple[kind: TokenKind, size: int] =
   let id_idx = find_first_index(n, NkIdentifier)
   if id_idx < 0:
      raise new_evaluation_error("Invalid constant system function call.")

   let id = n[id_idx]
   case id.identifier.s
   of ConversionFunctions:
      result = determine_kind_and_size_system_function_call_conversion(n, context)
   of "clog2":
      result = (TkUIntLit, INTEGER_BITS)
   of RealMathFunctions:
      # The result of a system math function is always a real number.
      result = (TkRealLit, -1)
   else:
      raise new_evaluation_error("Unsupported system function '$1'.", id.identifier.s)


proc determine_kind_and_size_conditional_expression(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   let condition_idx = find_first_index(n, ExpressionTypes)
   let lhs_idx = find_first_index(n, ExpressionTypes, condition_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if condition_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid conditional expression node.")

   let lhs = determine_kind_and_size(n[lhs_idx], context)
   let rhs = determine_kind_and_size(n[rhs_idx], context)
   result.size = max(lhs.size, rhs.size)
   result.kind = determine_expression_kind(lhs.kind, rhs.kind)


proc determine_kind_and_size*(n: PNode, context: AstContext): tuple[kind: TokenKind, size: int] =
   if is_nil(n):
      raise new_evaluation_error("Invalid node (nil).")

   case n.kind
   of NkPrefix:
      result = determine_kind_and_size_prefix(n, context)
   of NkInfix:
      result = determine_kind_and_size_infix(n, context)
   of NkConstantFunctionCall:
      result = determine_kind_and_size_function_call(n, context)
   of NkIdentifier:
      result = determine_kind_and_size_identifier(n, context)
   of NkConstantMultipleConcat:
      result = determine_kind_and_size_multiple_concat(n, context)
   of NkConstantConcat:
      result = determine_kind_and_size_concat(n, context)
   of NkBracketExpression:
      result = determine_kind_and_size_bracket_expression(n, context)
   of NkConstantSystemFunctionCall:
      result = determine_kind_and_size_system_function_call(n, context)
   of NkParenthesis:
      result = determine_kind_and_size(find_first(n, ExpressionTypes), context)
   of NkConstantConditionalExpression:
      result = determine_kind_and_size_conditional_expression(n, context)
   of NkStrLit:
      result.kind = TkStrLit
      result.size = -1
   of NkRealLit:
      result.kind = TkRealLit
      result.size = -1
   of IntegerTypes:
      # We have to set up a self-determined conversion of the integer token in
      # order to properly decide if it's ambiguous or not. It's legal to declare
      # an ambiguous integer where the ambiguous bits are truncated away.
      var tok: Token
      init(tok)
      tok.kind = TokenKind(ord(TkIntLit) + ord(n.kind) - ord(NkIntLit))
      tok.literal = n.iraw
      tok.base = n.base
      tok.size = if n.size < 0: INTEGER_BITS else: n.size
      tok = convert(tok, tok.kind, tok.size)
      result.kind = tok.kind
      result.size = tok.size
   else:
      raise new_evaluation_error("The node '$1' is not an expression.", n.kind)
