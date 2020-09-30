# Abstract syntax tree and symbol table
import strutils
import json
import macros
import math
import bignum

import ./lexer

type
   NodeKind* = enum
      NkInvalid, # An invalid node, indicates an error
      NkCritical, # A critical error, e.g. an unsupported syntax tree
      NkTokenError, # A token error node, e.g. an unexpected token
      NkTokenErrorSync, # Indicates that the token stream was resynchronized
      NkExpectError,
      # Atoms
      NkEmpty, # An empty node
      NkIdentifier, # The node is an identifier
      NkStrLit, # the node is a string literal
      NkIntLit, # the node is an integer literal
      NkUIntLit, # the node is an unsigned integer literal
      NkAmbIntLit, # the node is an integer literal
      NkAmbUIntLit, # the node is an unsigned integer literal
      NkRealLit, # the node is a real value
      NkType,
      NkPrefix,
      NkInfix,
      NkParenthesis,
      NkDirection,
      NkWildcard, # Symbolizes a '*' in an event expression.
      NkComment,
      # Custom node types
      NkRangedIdentifier, # FIXME: Still useful? Same as NkArrayIdentifier?
      NkArrayIdentifer,
      NkAssignment,
      # Modules A.1.3
      NkSourceText,
      NkModuleDecl,
      NkModuleIdentifier,
      # Module parameters and ports A.1.4
      NkModuleParameterPortList, NkListOfPorts, NkListOfPortDeclarations,
      NkPort, NkPortExpression, NkPortReference, NkPortReferenceConcat,
      NkPortIdentifier, NkPortDecl, NkVariablePort,
      # Parameter declarations A.2.1.1
      NkLocalparamDecl, NkDefparamDecl, NkParameterDecl, NkSpecparamDecl,
      # Port declarations A.2.1.2
      NkInoutDecl, NkInputDecl, NkOutputDecl, # FIXME: Remove if unused
      # Type declarations A.2.1.3
      NkEventDecl, NkGenvarDecl, NkIntegerDecl, NkNetDecl, NkRealDecl,
      NkRealtimeDecl, NkRegDecl, NkTimeDecl,
      # Net and variable types A.2.2.1
      NkNetType,
      # Drive strengths A.2.2.2
      NkDriveStrength, NkChargeStrength,
      # Delays A.2.2.3
      NkDelay,
      # Declaration assignments A.2.4
      NkParamAssignment, NkNetDeclAssignment, # FIXME: NkNetDeclAssignment unused
      # Declaration ranges A.2.5
      NkRange,
      # Function declarations A.2.6
      NkFunctionDecl,
      # Task declarations A.2.7
      NkTaskDecl, NkTaskFunctionPortDecl,
      # Module instantiation A.4.1
      NkModuleInstantiation, NkParameterValueAssignment, NkModuleInstance,
      NkOrderedParameterAssignment, NkNamedParameterAssignment,
      NkOrderedPortConnection, NkNamedPortConnection,
      # Generate construct A.4.2
      NkGenerateRegion, NkLoopGenerate, NkGenerateBlock, NkIfGenerate,
      NkCaseGenerate, NkCaseGenerateItem,
      # Procedural blocks and assignments A.6.2
      NkContinuousAssignment, NkBlockingAssignment, NkNonblockingAssignment,
      NkProceduralContinuousAssignment, NkInitial, NkAlways,
      # Parallel and sequential blocks A.6.3
      NkParBlock, NkSeqBlock,
      # Statements A.6.4
      NkTaskEnable, NkSystemTaskEnable,
      # Timing control statements A.6.5
      NkEventControl, NkEventExpression, NkEventOr, NkEventComma, NkRepeat,
      NkWait, NkProceduralTimingControl, NkEventTrigger, NkDisable,
      # Conditional statements A.6.6
      NkIf,
      # Case statements A.6.7
      NkCase, NkCasez, NkCasex, NkCaseItem,
      # Looping statements A.6.8
      NkForever, NkWhile, NkFor,
      # Specify section A.7.1
      NkSpecifyBlock,
      # Concatenations A.8.1
      NkConstantConcat, NkConstantMultipleConcat,
      # Function calls A.8.2
      NkConstantFunctionCall,
      NkConstantSystemFunctionCall,
      # Expressions A.8.3
      NkConstantExpression, NkConstantMinTypMaxExpression,
      NkConstantConditionalExpression, NkConstantRangeExpression,
      # Primaries A.8.4
      NkConstantPrimary,
      # Expression left-side values A.8.5
      NkVariableLvalue,
      NkVariableLvalueConcat,
      # Operators A.8.6
      NkUnaryOperator, NkBinaryOperator,
      # Attributes A.9.1
      NkAttributeInst, NkAttributeSpec, NkAttributeName,
      # Identifiers A.9.3
      NkParameterIdentifier, NkSpecparamIdentifier, NkFunctionIdentifier,
      NkGenvarIdentifier,

   NodeKinds* = set[NodeKind]


const
   IdentifierTypes* =
      {NkIdentifier, NkAttributeName, NkModuleIdentifier, NkPortIdentifier,
       NkParameterIdentifier, NkSpecparamIdentifier, NkType,
       NkFunctionIdentifier, NkGenvarIdentifier, NkDirection, NkNetType,
       NkAttributeName}

   IntegerTypes* =
      {NkIntLit, NkUIntLit, NkAmbIntLit, NkAmbUIntLit}

   # FIXME: Unused right now
   OperatorTypes* = {NkUnaryOperator, NkBinaryOperator}

   ErrorTypes* = {NkTokenError, NkTokenErrorSync, NkCritical}

   PrimitiveTypes* =
      ErrorTypes + IdentifierTypes + IntegerTypes + OperatorTypes +
      {NkRealLit, NkStrLit, NkWildcard, NkComment}

   DeclarationTypes* =
      {NkNetDecl, NkRegDecl, NkPortDecl, NkRealDecl, NkTaskDecl, NkTimeDecl,
       NkEventDecl, NkInoutDecl, NkInputDecl, NkOutputDecl, NkGenvarDecl,
       NkModuleDecl, NkIntegerDecl, NkDefparamDecl, NkFunctionDecl,
       NkRealtimeDecl, NkParameterDecl, NkSpecparamDecl, NkLocalparamDecl,
       NkModuleParameterPortList, NkListOfPortDeclarations, NkListOfPorts,
       NkTaskFunctionPortDecl}

   ConcatenationTypes* =
      {NkConstantConcat, NkConstantMultipleConcat, NkPortReferenceConcat,
       NkVariableLvalueConcat}

   ExpressionTypes* =
      IntegerTypes + {NkRealLit, NkPrefix, NkInfix, NkConstantFunctionCall,
      NkIdentifier, NkRangedIdentifier, NkConstantMultipleConcat,
      NkConstantConcat, NkConstantSystemFunctionCall, NkParenthesis,
      NkStrLit, NkConstantConditionalExpression}


type
   PNode* = ref TNode
   TNodeSeq* = seq[PNode]
   # FIXME: Add .acyclic. later on when it's supported by a new release.
   TNode {.final.} = object
      loc*: Location
      case kind*: NodeKind
      of NkStrLit, NkComment:
         s*: string
      of IntegerTypes:
         inumber*: BiggestInt
         iraw*: string
         base*: NumericalBase
         size*: int
      of NkRealLit:
         fnumber*: BiggestFloat
         fraw*: string
      of IdentifierTypes:
         identifier*: PIdentifier
      of ErrorTypes:
         msg*: string # TODO: Combine w/ NkStrLit?
         eraw*: string
      of OperatorTypes:
         # FIXME: Unused right now
         op*: string
      of NkWildcard:
         discard
      else:
         sons*: TNodeSeq

   # An AST context item represents a specific node and its position in the
   # parent node's list of sons.
   PAstContextItem* = ref AstContextItem
   AstContextItem* = object
      pos*: int
      n*: PNode

   PAstContext* = ref AstContext
   AstContext* = seq[AstContextItem]

   EvaluationError* = object of ValueError


proc init*(c: var AstContext, len: int) =
   c = new_seq_of_cap[AstContextItem](len)


proc add*(c: var AstContext, pos: int, n: PNode) =
   add(c, AstContextItem(pos: pos, n: n))


proc pretty*(n: PNode, indent: int = 0): string =
   if is_nil(n):
      return
   result = spaces(indent) & $n.kind & $n.loc
   case n.kind
   of IdentifierTypes:
      add(result, ": " & $n.identifier.s & "\n")
   of IntegerTypes:
      add(result, format(": $1 (raw: '$2', base: $3, size: $4)\n",
                         n.inumber, n.iraw, n.base, n.size))
   of NkRealLit:
      add(result, format(": $1 (raw: '$2')\n", n.fnumber, n.fraw))
   of OperatorTypes:
      # FIXME: Unused right now
      add(result, format(": $1\n", n.op))
   of ErrorTypes:
      var msg = ": $1"
      var args = @[n.msg]
      if len(n.eraw) > 0:
         add(msg, " ($2)")
         add(args, n.eraw)
      add(msg, "\n")
      add(result, format(msg, args))
   of NkStrLit, NkComment:
      add(result, format(": $1\n", n.s))
   of NkWildcard:
      add(result, "\n")
   else:
      add(result, "\n")
      var sons_str = ""
      for s in n.sons:
         add(sons_str, pretty(s, indent + 2))

      add(result, sons_str)


proc pretty*(nodes: openarray[PNode]): string =
   for n in nodes:
      add(result, pretty(n))


proc `%`*(n: PNode): JsonNode =
   if n == nil:
      return
   case n.kind
   of IdentifierTypes:
      result = %*{
         "kind": $n.kind,
         "loc": n.loc,
         "identifier": n.identifier.s
      }
   of IntegerTypes:
      result = %*{
         "kind": $n.kind,
         "loc": n.loc,
         "number": n.inumber,
         "raw": n.iraw,
         "base": to_int(n.base),
         "size": n.size
      }
   of NkRealLit:
      result = %*{
         "kind": $n.kind,
         "loc": n.loc,
         "number": n.fnumber,
         "raw": n.fraw
      }
   of OperatorTypes:
      result = %*{
         "kind": $n.kind,
         "loc": n.loc,
         "operator": n.identifier.s
      }
   of ErrorTypes:
      result = %*{
         "kind": $n.kind,
         "loc": n.loc,
         "message": n.msg,
         "raw": n.eraw
      }
   of NkStrLit, NkComment:
      result = %*{
         "kind": $n.kind,
         "loc": n.loc,
         "string": n.s
      }
   of NkWildcard:
      result = %*{
         "kind": $n.kind,
         "loc": n.loc
      }
   else:
      result = %*{
         "kind": $n.kind,
         "loc": n.loc,
         "sons": %n.sons
      }


proc `==`*(x, y: PNode): bool =
   if is_nil(x) or is_nil(y):
      return false

   if x.loc != y.loc:
      return false

   if x.kind != y.kind:
      return false

   case x.kind
   of IdentifierTypes:
      result = x.identifier.s == y.identifier.s
   of IntegerTypes:
      result = x.inumber == y.inumber and x.iraw == y.iraw and
               x.base == y.base and x.size == y.size
   of NkRealLit:
      result = x.fnumber == y.fnumber
   of OperatorTypes:
      # FIXME: Unused right now
      result = x.op == y.op
   of NkStrLit, NkComment:
      result = x.s == y.s
   of ErrorTypes, NkWildcard:
      return true
   else:
      if len(x.sons) != len(y.sons):
         return false

      result = true
      for i in 0..<len(x.sons):
         if x.sons[i] != y.sons[i]:
            result = false
            break


proc detailed_compare*(x, y: PNode) =
   ## Compare the two nodes ``x`` and ``y``, highlighting the differences in
   ## the AST.
   const indent = 2
   if is_nil(x):
      echo "LHS node is nil"
      return

   if is_nil(y):
      echo "RHS node is nil"
      return

   if x.loc != y.loc:
      echo "Location differs:\n", pretty(x, indent), pretty(y, indent)
      return

   if x.kind != y.kind:
      echo "Kind differs:\n", pretty(x, indent), pretty(y, indent)
      return

   case x.kind
   of IdentifierTypes, IntegerTypes, NkRealLit, OperatorTypes, ErrorTypes,
      NkStrLit, NkWildcard:
      if x != y:
         echo "Node contents differs:\n", pretty(x, indent), pretty(y, indent)
         return
   else:
      if len(x.sons) != len(y.sons):
         let str = format("Length of subtree differs, LHS($1), RHS($2):\n",
                          len(x.sons), len(y.sons))
         echo str, pretty(x, indent), pretty(y, indent)
         return

      for i in 0..<len(x.sons):
         detailed_compare(x.sons[i], y.sons[i])


proc has_errors*(n: PNode): bool =
   ## Returns ``true`` if the AST starting with the node ``n`` contains errors.
   case n.kind
   of ErrorTypes:
      return true
   of PrimitiveTypes - ErrorTypes:
      return false
   else:
      for i in 0..<len(n.sons):
         if has_errors(n.sons[i]):
            return true
      return false


proc new_node*(kind: NodeKind, loc: Location): PNode =
   result = PNode(kind: kind, loc: loc)


proc new_node*(kind: NodeKind, loc: Location, sons: seq[PNode]): PNode =
   result = new_node(kind, loc)
   result.sons = sons


proc new_identifier_node*(kind: NodeKind, loc: Location,
                          identifier: PIdentifier): PNode =
   result = new_node(kind, loc)
   result.identifier = identifier


proc new_inumber_node*(kind: NodeKind, loc: Location, inumber: BiggestInt,
                       raw: string, base: NumericalBase, size: int): PNode =
   result = new_node(kind, loc)
   result.inumber = inumber
   result.iraw = raw
   result.base = base
   result.size = size


proc new_fnumber_node*(kind: NodeKind, loc: Location, fnumber: BiggestFloat,
                       raw: string): PNode =
   result = new_node(kind, loc)
   result.fnumber = fnumber
   result.fraw = raw


proc new_str_lit_node*(loc: Location, s: string): PNode =
   result = new_node(NkStrLit, loc)
   result.s = s


proc new_comment_node*(loc: Location, s: string): PNode =
   result = new_node(NkComment, loc)
   result.s = s


proc new_error_node*(kind: NodeKind, loc: Location, raw, msg: string,
                     args: varargs[string, `$`]): PNode =
   result = new_node(kind, loc)
   result.msg = format(msg, args)
   result.eraw = raw


proc find_first*(n: PNode, kinds: NodeKinds, start: Natural = 0): PNode =
   ## Return the first son in ``n`` whose kind is in ``kinds``. If a matching
   ## node cannot be found, ``nil`` is returned. The search begins at ``start``.
   result = nil
   if n.kind notin PrimitiveTypes and start < len(n.sons):
      for i in start..high(n.sons):
         if n.sons[i].kind in kinds:
            return n.sons[i]


template find_first*(n: PNode, kind: NodeKind, start: Natural = 0): PNode =
   ## Return the first son in ``n`` whose kind is ``kind``. If a matching node
   ## cannot be found, ``nil`` is returned. The search begins at ``start``.
   find_first(n, {kind}, start)


proc find_first_chain*(n: PNode, kind_chain: openarray[NodeKind]): PNode =
   if len(kind_chain) == 0:
      return nil
   result = n
   for kind in kind_chain:
      result = find_first(result, kind)
      if is_nil(result):
         break


proc find_first_index*(n: PNode, kinds: NodeKinds, start: Natural = 0): int =
   ## Return the index of the first son in ``n`` whose kind is in ``kinds``.
   ## If a matching node cannot be found, ``-1`` is returned. The search
   ## begins at ``start``.
   result = -1
   if n.kind notin PrimitiveTypes and start < len(n.sons):
      for i in start..high(n.sons):
         if n.sons[i].kind in kinds:
            return i


template find_first_index*(n: PNode, kind: NodeKind, start: Natural = 0): int =
   ## Return the index of the first son in ``n`` whose kind is ``kind``.
   ## If a matching node cannot be found, ``-1`` is returned. The search
   ## begins at ``start``.
   find_first_index(n, {kind}, start)


template walk_sons_common(n: PNode, kinds: NodeKinds, start: Natural = 0) =
   if n.kind notin PrimitiveTypes and start < len(n.sons):
      for i in start..high(n.sons):
         if n.sons[i].kind in kinds:
            yield n.sons[i]


template walk_sons_common_index(n: PNode, kinds: NodeKinds, start: Natural = 0) =
   if n.kind notin PrimitiveTypes and start < len(n.sons):
      var idx = 0
      for i in start..high(n.sons):
         if n.sons[i].kind in kinds:
            yield (idx, n.sons[i])
            inc(idx)


iterator walk_sons*(n: PNode, kinds: NodeKinds, start: Natural = 0): PNode {.inline.} =
   ## Starting at ``start``, walk the sons in ``n`` whose kind is in ``kinds``.
   walk_sons_common(n, kinds, start)


iterator walk_sons_index*(n: PNode, kinds: NodeKinds, start: Natural = 0): tuple[i: int, n: PNode] {.inline.} =
   ## Starting at ``start``, walk the sons in ``n`` whose kind is in ``kinds``.
   walk_sons_common_index(n, kinds, start)


iterator walk_sons*(n: PNode, kind: NodeKind, start: Natural = 0): PNode {.inline.} =
   ## Starting at ``start``, walk the sons in ``n`` whose kind is ``kind``.
   walk_sons_common(n, {kind}, start)


iterator walk_sons_index*(n: PNode, kind: NodeKind, start: Natural = 0): tuple[i: int, n: PNode] {.inline.} =
   ## Starting at ``start``, walk the sons in ``n`` whose kind is ``kind``.
   walk_sons_common_index(n, {kind}, start)


iterator walk_sons*(n: PNode, start: Natural, stop: int = -1): PNode =
   ## Walk the sons in ``n`` between indexes ``start`` and ``stop``. If ``stop`` is omitted,
   ## the iterator continues until the last son has been returned.
   if n.kind notin PrimitiveTypes:
      var lstop = stop
      var lstart = start
      if stop < 0 or stop > high(n.sons):
         lstop = high(n.sons)
      for i in lstart..lstop:
         yield n.sons[i]


iterator walk_ports*(n: PNode): PNode {.inline.} =
   ## Walk the ports of a module. The node ``n`` is expected to be a ``NkModuleDecl``.
   ## This iterator yields nodes of type ``NkPortDecl`` or ``NkPort``.
   if n.kind == NkModuleDecl:
      for s in n.sons:
         if s.kind in {NkListOfPortDeclarations, NkListOfPorts}:
            for p in s.sons:
               if p.kind in {NkPortDecl, NkPort}:
                  yield p


iterator walk_parameter_ports*(n: PNode): PNode {.inline.} =
   ## Walk the parameter ports of a module. The node ``n`` is expected to be a ``NkModuleDecl``.
   ## This iterator yields nodes of type ``NkParameterDecl``.
   if n.kind == NkModuleDecl:
      for s in n.sons:
         if s.kind == NkModuleParameterPortList:
            for p in s.sons:
               if p.kind == NkParameterDecl:
                  yield p


iterator walk_nodes_starting_with*(nodes: openarray[PNode], prefix: string): PNode =
   for n in nodes:
      if n.kind in IdentifierTypes and starts_with(n.identifier.s, prefix):
         yield n


proc find_identifier*(n: PNode, loc: Location, context: var AstContext,
                      added_length: int = 0): PNode =
   ## Descend into ``n``, searching for the identifier at the target location
   ## ``loc``. If an identifier is found, ``context`` will specify the AST
   ## context from the node ``n`` down to the matching identifier, i.e. the
   ## tree where its declaration is likely to be found. The length of the
   ## identifier may be extended by specifying a nonzero value for
   ## ``added_length``. This effectively grows the bounding box on the right.
   ## If the search yields no result, ``nil`` is returned.
   case n.kind
   of IdentifierTypes:
      # If the node is an identifier type, check if the location is pointing to
      # anywhere within the identifier. Otherwise, we skip it. If end_cursor is
      # true, we make the identifier appear to be one character longer than its
      # natural length.
      if in_bounds(loc, n.loc, len(n.identifier.s) + added_length):
         result = n
      else:
         result = nil
   of PrimitiveTypes - IdentifierTypes:
      result = nil
   else:
      # TODO: Perhaps we can improve the search here? Skipping entire subtrees
      #       depending on the location of the first node within?
      for i, s in n.sons:
         add(context, i, n)
         result = find_identifier(s, loc, context, added_length)
         if not is_nil(result):
            return
         discard pop(context)


proc find_identifier_physical*(n: PNode, locs: PLocations, loc: Location, context: var AstContext,
                               added_length: int = 0): PNode =
   ## Descend into ``n``, searching for the identifier at the physical location
   ## ``loc``, i.e. ``loc.file`` > 0 is assumed. The length of the identifier
   ## may be extended by specifying a nonzero value for ``added_length``.
   ## This effectively grows the bounding box on the right. If the search yields
   ## no result, ``nil`` is returned.
   for i, map in locs.macro_maps:
      for j, lpair in map.locations:
         # The macro map's location database only stores the locations of the
         # first character in the token and not the length of the token. Given
         # that the location we're given as an input argument may point to
         # anywhere within the token, we have check each likely candidate token
         # in the macro.
         if loc.file == lpair.x.file and loc.line == lpair.x.line and loc.col >= lpair.x.col:
            set_len(context, 0)
            var macro_loc = new_location(-(i + 1), j, 0)
            unroll_location(locs, macro_loc)
            let identifier = find_identifier(n, macro_loc, context, added_length)
            if is_nil(identifier):
               continue
            if in_bounds(loc, lpair.x, len(identifier.identifier.s) + added_length):
               return identifier

   # Make the lookup if the macro map search didn't yield a result.
   set_len(context, 0)
   result = find_identifier(n, loc, context, added_length)


proc find_declaration*(n: PNode, identifier: PIdentifier): tuple[declaration, identifier, expression: PNode] =
   ## Descend into ``n``, searching for the AST node that declares
   ## ``identifier``. The proc returns a tuple of the declaration node, the
   ## matching identifier node within that AST and any corresponding expression
   ## if the declaration contains an assignment. If the search failes, all tuple
   ## fields are set to ``nil``.
   result = (nil, nil, nil)

   # We have to hande each type of declaration node individually in order to find
   # the correct identifier node.
   case n.kind
   of NkPortDecl:
      # A port declaration allows a list of identifiers.
      for id in walk_sons(n, NkPortIdentifier):
         if id.identifier.s == identifier.s:
            return (n, id, nil)

   of NkGenvarDecl:
      # A genvar declaration allows a list of identifiers.
      for id in walk_sons(n, NkIdentifier):
         if id.identifier.s == identifier.s:
            return (n, id, nil)

   of NkTaskDecl, NkFunctionDecl:
      let id = find_first(n, NkIdentifier)
      if not is_nil(id) and id.identifier.s == identifier.s:
         return (n, id, nil)

      # If we didn't get a hit for the task/function name itself, we check the
      # parameter list.
      for s in walk_sons(n, NkTaskFunctionPortDecl):
         for id in walk_sons(s, NkPortIdentifier):
            if id.identifier.s == identifier.s:
               return (s, id, nil)

   of NkRegDecl, NkIntegerDecl, NkRealDecl, NkRealtimeDecl, NkTimeDecl, NkNetDecl, NkEventDecl:
      for s in n.sons:
         case s.kind
         of NkArrayIdentifer, NkAssignment:
            let id = find_first(s, NkIdentifier)
            if not is_nil(id) and id.identifier.s == identifier.s:
               return (n, id, find_first(s, ExpressionTypes))
         of NkIdentifier:
            if s.identifier.s == identifier.s:
               return (n, s, nil)
         else:
            discard

   of NkParameterDecl, NkLocalparamDecl:
      # When we find a NkParamAssignment node, the first son is expected to be
      # the identifier.
      for s in walk_sons(n, NkParamAssignment):
         let id = find_first(s, NkParameterIdentifier)
         if not is_nil(id) and id.identifier.s == identifier.s:
            return (n, id, find_first(s, ExpressionTypes))

   of NkSpecparamDecl:
      # When we find a NkAssignment node, the first son is expected to be the
      # identifier.
      for s in walk_sons(n, NkAssignment):
         let id = find_first(s, NkIdentifier)
         if not is_nil(id) and id.identifier.s == identifier.s:
            return (n, id, find_first(s, ExpressionTypes))

   of NkModuleDecl:
      let id = find_first(n, NkModuleIdentifier)
      if not is_nil(id) and id.identifier.s == identifier.s:
         return (n, id, nil)

   of PrimitiveTypes + {NkDefparamDecl}:
      # Defparam declarations specifically targets an existing parameter and
      # changes its value. Looking up a declaration should never lead to this
      # node.
      discard

   else:
      for s in n.sons:
         result = find_declaration(s, identifier)
         if not is_nil(result.declaration):
            break


proc find_declaration*(context: AstContext, identifier: PIdentifier):
      tuple[declaration, identifier, expression: PNode, context: AstContextItem] =
   ## Traverse the AST ``context`` bottom-up, descending into any declaration
   ## nodes found along the way searching for the declaration of ``identifier``.
   ## The proc returns a tuple of the declaration node, the matching identifier
   ## node within that AST, any corresponding expression (if the declaration
   ## contains an assignment) and the context in which it applies. If the search
   ## failes, the declaration node is set to ``nil``.
   result.declaration = nil
   result.identifier = nil
   result.expression = nil
   for i in countdown(high(context), 0):
      let context_item = context[i]
      if context_item.n.kind notin PrimitiveTypes:
         for pos in countdown(context_item.pos, 0):
            let s = context_item.n.sons[pos]
            if s.kind in DeclarationTypes - {NkDefparamDecl}:
               (result.declaration, result.identifier, result.expression) = find_declaration(s, identifier)
               if not is_nil(result.declaration):
                  if context_item.n.kind in {NkModuleParameterPortList, NkListOfPortDeclarations, NkListOfPorts}:
                     # If the declaration was enclosed in any of the list types,
                     # its scope stretches from the parent node and onwards.
                     result.context = context[i-1]
                  else:
                     result.context.pos = pos
                     result.context.n = context[i].n
                  return


proc find_all_declarations*(n: PNode, recursive: bool = false): seq[tuple[declaration, identifier: PNode]] =
   ## Search ``n`` for all declaration nodes.  The result is a sequence of tuples
   ## where each element represents a declared identifier. The definition is the
   ## same as for ``find_declarations``. If ``descend`` is ``true``, then the
   ## sons in ``n`` are searched too.
   case n.kind
   of NkPortDecl:
      for id in walk_sons(n, NkPortIdentifier):
         add(result, (n, id))

   of NkGenvarDecl:
      for id in walk_sons(n, NkIdentifier):
         add(result, (n, id))

   of NkTaskDecl, NkFunctionDecl:
      let id = find_first(n, NkIdentifier)
      if not is_nil(id):
         add(result, (n, id))

      for s in walk_sons(n, NkTaskFunctionPortDecl):
         for id in walk_sons(s, NkTaskFunctionPortDecl):
            add(result, (s, id))

   of NkRegDecl, NkIntegerDecl, NkRealDecl, NkRealtimeDecl, NkTimeDecl, NkNetDecl, NkEventDecl:
      for s in n.sons:
         case s.kind
         of NkArrayIdentifer, NkAssignment:
            let id = find_first(s, NkIdentifier)
            add(result, (n, id))
         of NkIdentifier:
            add(result, (n, s))
         else:
            discard

   of NkParameterDecl, NkLocalparamDecl:
      for s in walk_sons(n, NkParamAssignment):
         let id = find_first(s, NkParameterIdentifier)
         if not is_nil(id):
            add(result, (n, id))

   of NkSpecparamDecl:
      for s in walk_sons(n, NkAssignment):
         let id = find_first(s, NkIdentifier)
         if not is_nil(id):
            add(result, (n, id))

   of NkModuleDecl:
      let idx = find_first_index(n, NkModuleIdentifier)
      if idx > -1:
         add(result, (n, n.sons[idx]))
      for s in walk_sons(n, idx + 1):
         add(result, find_all_declarations(s, recursive))

   of NkModuleParameterPortList, NkListOfPortDeclarations:
      for s in n.sons:
         add(result, find_all_declarations(s, recursive))

   of PrimitiveTypes + {NkDefparamDecl}:
      discard

   else:
      if recursive:
         for s in n.sons:
            add(result, find_all_declarations(s, recursive))


proc find_all_declarations*(context: AstContext): seq[tuple[declaration, identifier: PNode]] =
   ## Find all declaration nodes in the given ``context``. The result is a
   ## sequence of tuples where each element represents a declared identifier. The
   ## definition is the same as for ``find_declarations``.
   for context_item in context:
      if context_item.n.kind notin PrimitiveTypes:
         for pos in 0..<context_item.pos:
            add(result, find_all_declarations(context_item.n.sons[pos]))


proc find_references*(n: PNode, identifier: PIdentifier): seq[PNode] =
   ## Descend into ``n``, finding all references to the ``identifier``,
   ## i.e. matching identifier nodes.
   case n.kind
   of IdentifierTypes:
      if n.identifier.s == identifier.s:
         add(result, n)
   of PrimitiveTypes - IdentifierTypes:
      discard
   of NkNamedPortConnection, NkNamedParameterAssignment:
      # For named port connections and named parameter assignments, we have to
      # skip the first identifier since that's the name of the port.
      for s in walk_sons(n, find_first_index(n, NkIdentifier) + 1):
         add(result, find_references(s, identifier))
   else:
      for s in n.sons:
         add(result, find_references(s, identifier))


proc find_all_module_instantiations*(n: PNode): seq[PNode] =
   ## Descend into ``n``, finding all module instantiations.
   case n.kind
   of PrimitiveTypes:
      discard
   of NkModuleInstantiation:
      add(result, n)
   else:
      for s in n.sons:
         add(result, find_all_module_instantiations(s))


proc find_all_lvalues*(n: PNode): seq[PNode] =
   if is_nil(n):
      return

   case n.kind
   of NkVariableLvalue:
      let id = find_first(n, NkIdentifier)
      add(result, id)
   of NkVariableLvalueConcat:
      for s in walk_sons(n, {NkVariableLvalue, NkVariableLvalueConcat}):
         add(result, find_all_lvalues(s))
   else:
      discard


proc find_all_drivers*(n: PNode, recursive: bool = false): seq[tuple[driver, identifier: PNode]] =
   ## Search ``n`` for all driver nodes.  The result is a sequence of tuples
   ## where each element represents a driver. If ``descend`` is ``true``, then
   ## the sons in ``n`` are searched too.
   case n.kind
   of NkPortDecl:
      let direction = find_first(n, NkDirection)
      if not is_nil(direction) and direction.identifier.s == "input":
         for id in walk_sons(n, NkPortIdentifier):
            add(result, (n, id))

   of NkContinuousAssignment:
      for assignment in walk_sons(n, NkAssignment):
         let lvalue_node = find_first(assignment, {NkVariableLvalue, NkVariableLvalueConcat})
         for lvalue in find_all_lvalues(lvalue_node):
            add(result, (n, lvalue))

   of NkProceduralContinuousAssignment, NkBlockingAssignment, NkNonblockingAssignment:
      let lvalue_node = find_first(n, {NkVariableLvalue, NkVariableLvalueConcat})
      for lvalue in find_all_lvalues(lvalue_node):
         add(result, (n, lvalue))

   of PrimitiveTypes:
      discard

   else:
      if recursive:
         for s in n.sons:
            add(result, find_all_drivers(s, recursive))


proc find_all_drivers*(context: AstContext): seq[tuple[driver, identifier: PNode]] =
   # Find all drivers in the given ``context``. The result is a sequence of
   # tuples where each element represents the driver assignment. The definition
   # is the same as for ``find_declarations``.
   for context_item in context:
      if context_item.n.kind notin PrimitiveTypes:
         for pos in 0..<context_item.pos:
            add(result, find_all_drivers(context_item.n.sons[pos]))


proc find_all_ports*(n: PNode): seq[tuple[port, identifier: PNode]] =
   ## Find all ports of the module declaration ``n``.
   template add_port_declarations_from_sons(result: seq[(PNode, PNode)], n: PNode) =
      for port in walk_sons(n, NkPortDecl):
         for id in walk_sons(port, NkPortIdentifier):
            add(result, (port, id))

   if n.kind != NkModuleDecl:
      return

   # Add any port declarations from the list of port declarations. Otherwise, we
   # check the module body for port declarations. The two are mutually exclusive.
   let port_declarations = find_first(n, NkListOfPortDeclarations)
   if is_nil(port_declarations):
      add_port_declarations_from_sons(result, n)
   else:
      add_port_declarations_from_sons(result, port_declarations)


proc find_all_parameters*(n: PNode): seq[tuple[parameter, identifier: PNode]] =
   ## Find all parameter of the module declaration ``n``.
   template add_parameter_declarations_from_sons(result: seq[(PNode, PNode)], n: PNode) =
      for parameter in walk_sons(n, NkParameterDecl):
         for assignment in walk_sons(parameter, NkParamAssignment):
            let id = find_first(assignment, NkParameterIdentifier)
            if not is_nil(id):
               add(result, (parameter, id))

   if n.kind != NkModuleDecl:
      return

   # Add parameter declarations from the parameter port list. Otherwise, we
   # check the module body for parameter declarations. The two are mutually
   # exclusive according to Section 4.10.1.
   let parameter_declarations = find_first(n, NkModuleParameterPortList)
   if not is_nil(parameter_declarations):
      add_parameter_declarations_from_sons(result, parameter_declarations)
   else:
      add_parameter_declarations_from_sons(result, n)


proc `$`*(n: PNode): string =
   if n == nil:
      return

   case n.kind:
   of IdentifierTypes:
      result = n.identifier.s

   of NkRangedIdentifier:
      for i, s in n.sons:
         add(result, $s)

   of NkConstantRangeExpression:
      add(result, '[')
      add(result, $n.sons[0])
      add(result, ']')

   of IntegerTypes:
      if n.size != -1:
         result = $n.size
         case n.base
         of Base2:
            add(result, "'b")
         of Base8:
            add(result, "'o")
         of Base10:
            add(result, "'d")
         of Base16:
            add(result, "'h")
      add(result, n.iraw)

   of NkRealLit:
      result = n.fraw

   of NkStrLit:
      result = '"' & n.s & '"'

   of NkWildcard:
      result = "*"

   of NkInfix:
      add(result, $n.sons[1])
      add(result, ' ' & $n.sons[0] & ' ')
      add(result, $n.sons[2])

   of NkRange:
      add(result, '[')
      add(result, $n.sons[0])
      add(result, ':')
      add(result, $n.sons[1])
      add(result, ']')

   of NkAssignment, NkParamAssignment:
      add(result, $n.sons[0])
      add(result, " = ")
      add(result, $n.sons[1])

   of NkAttributeInst:
      add(result, "(* ")
      for i in countup(0, high(n.sons), 2):
         add(result, format("$1 = $2", n.sons[i], n.sons[i+1]))
      add(result, " *)")

   of NkPort:
      let id = find_first(n, NkPortIdentifier)
      if not is_nil(id):
         add(result, format(".$1($2)", $id, $n.sons[1]))
      else:
         add(result, $n.sons[0])

   of ErrorTypes, NkExpectError, NkComment, OperatorTypes:
      # FIXME: OperatorTypes are unused right now.
      discard

   of NkDelay:
      add(result, '#')
      if n.sons[0].kind == NkParenthesis:
         add(result, '(')
         for i, s in n.sons[0].sons:
            if i > 0:
               add(result, ", ")
            add(result, $s)
         add(result, ')')
      else:
         for s in n.sons:
            add(result, $s)

   of NkTaskDecl, NkFunctionDecl:
      if n.kind == NkTaskDecl:
         add(result, "task ")
      else:
         add(result, "function ")

      let idx = find_first_index(n, NkIdentifier)
      if idx > 0:
         for s in walk_sons(n, 0, idx - 1):
            if s.kind == NkComment:
               continue
            add(result, $s & ' ')

      if idx >= 0:
         add(result, n.sons[idx].identifier.s)
         add(result, '(')
         for i, s in walk_sons_index(n, NkTaskFunctionPortDecl):
            if i > 0:
               add(result, ", ")
            add(result, $s)
         add(result, ')')

   of DeclarationTypes - {NkFunctionDecl, NkTaskDecl}:
      case n.kind
      of NkRegDecl:
         add(result, "reg ")
      of NkIntegerDecl:
         add(result, "integer ")
      of NkRealDecl:
         add(result, "real ")
      of NkRealtimeDecl:
         add(result, "realtime ")
      of NkTimeDecl:
         add(result, "time ")
      of NkLocalparamDecl:
         add(result, "localparam ")
      of NkParameterDecl:
         add(result, "parameter ")
      else:
         discard

      var seen_identifier = false
      var nof_nodes = 0
      for s in n.sons:
         if s.kind == NkComment:
            continue
         if s.kind in {NkIdentifier, NkParamAssignment, NkAssignment}:
            if seen_identifier:
               add(result, ',')
            seen_identifier = true
         if nof_nodes > 0:
            add(result, ' ')
         add(result, $s)
         inc(nof_nodes)
      # TODO: Whether to add a semicolon or not depends on the syntax enclosing
      #       the declaration so that will have to be handled outside this case.
   of NkChargeStrength, NkDriveStrength:
      add(result, '(')
      for i, s in n.sons:
         if i > 0:
            add(result, ", ")
         add(result, $s)
      add(result, ')')

   of NkConstantMultipleConcat:
      add(result, '{')
      add(result, $n.sons[0])
      add(result, $n.sons[1])
      add(result, '}')

   of ConcatenationTypes - {NkConstantMultipleConcat}:
      add(result, '{')
      for i, s in n.sons:
         if i > 0:
            add(result, ", ")
         add(result, $s)
      add(result, '}')

   else:
      if n.kind == NkParenthesis:
         add(result, '(')

      for i, s in n.sons:
         if i > 0:
            add(result, " ")
         add(result, $s)

      if n.kind == NkParenthesis:
         add(result, ')')


# Forward declarations
const INTEGER_BITS* = 32
proc evaluate_constant_expression*(n: PNode, context: AstContext, kind: TokenKind, size: int): Token
proc determine_kind_and_size*(n: PNode, context: AstContext): tuple[kind: TokenKind, size: int]
proc determine_expression_kind(x, y: TokenKind): TokenKind


template evaluate_constant_expression*(n: PNode, context: AstContext): Token =
   evaluate_constant_expression(n, context, TkInvalid, -1)


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


proc set_inumber_from_literal(tok: var Token) =
   if tok.kind notin IntegerTokens or tok.kind in AmbiguousTokens:
      return

   let signed_number = new_int(tok.literal, base = 2) and new_int('1' & repeat('0', tok.size - 1), base = 2)
   let unsigned_number = new_int(tok.literal, base = 2) and new_int('0' & repeat('1', tok.size - 1), base = 2)
   let i = if tok.kind == TkIntLit:
      unsigned_number - signed_number
   else:
      unsigned_number + signed_number

   if fits_int(i):
      tok.inumber = to_int(i)


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
   set_inumber_from_literal(tok)


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
      # FIXME: Exception/
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


proc convert(tok: Token, kind: TokenKind, size: int): Token =
   ## Convert the integer token to the target kind and size. If the target kind
   ## is signed, the resulting token will be sign extended. An unsigned integer
   ## is exteded with zeros and a signed integer is extended with its sign bit.
   ## If the target size is smaller than the size of the integer, the value is
   ## truncated.
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
   else:
      discard


macro make_prefix(x: typed, op: string): untyped =
   result = new_nim_node(nnkPrefix)
   add(result, new_ident_node(op.str_val))
   add(result, x)


macro make_infix(x, y: typed, op: string): untyped =
   result = new_nim_node(nnkInfix)
   add(result, new_ident_node(op.str_val))
   add(result, x)
   add(result, y)


template unary_sign(n: PNode, context: AstContext, kind: TokenKind, size: int, op: string): Token =
   init(result)
   let tok = evaluate_constant_expression(n, context, kind, size)
   result.kind = kind
   result.size = size

   case kind
   of TkIntLit, TkUIntLit:
      result.base = Base2
      when op == "+":
         result.literal = tok.literal
         result.inumber = tok.inumber
      else:
         from_gmp_int(result, make_prefix(to_gmp_int(tok), op))
   of TkRealLit:
      result.fnumber = make_prefix(tok.fnumber, op)
      result.literal = $result.fnumber
   of AmbiguousTokens:
      set_ambiguous(result)
   else:
      raise new_evaluation_error("Unary operator '$1' cannot yield kind '$2'.", op, $kind)
   result


proc binary_negation(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   init(result)
   let tok = evaluate_constant_expression(n, context, kind, size)
   result.kind = kind
   result.size = size

   case kind
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
      raise new_evaluation_error("Bitwise negation cannot yield kind '$1'.", $kind)


proc logical_negation(n: PNode, context: AstContext): Token =
   init(result)
   # The operand is self-determined in a logical negation.
   let tok = evaluate_constant_expression(n, context)
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
      set_ambiguous(result)
   else:
      raise new_evaluation_error("Logical negation cannot parse kind '$1'.", $tok.kind)


template unary_reduction(n: PNode, context: AstContext, op: string): Token =
   init(result)
   let tok = evaluate_constant_expression(n, context)
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
      set_ambiguous(result)
   else:
      raise new_evaluation_error("Unary reduction cannot parse kind '$1'.", $tok.kind)
   result


proc evaluate_constant_prefix(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   template invert(result: Token) =
      if result.kind == TkUIntLit:
         result.inumber = 1 - ord(result.inumber == 1)
         result.literal = $result.inumber

   init(result)
   let op_idx = find_first_index(n, NkIdentifier)
   let e_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   if op_idx < 0 or e_idx < 0:
      raise new_evaluation_error("Invalid infix node.")

   let e = n.sons[e_idx]
   let op = n.sons[op_idx].identifier.s
   case op
   of "+":
      result = unary_sign(e, context, kind, size, "+")
   of "-":
      result = unary_sign(e, context, kind, size, "-")
   of "~":
      result = binary_negation(e, context, kind, size)
   of "!":
      result = logical_negation(e, context)
   of "&":
      result = unary_reduction(e, context, "and")
   of "|":
      result = unary_reduction(e, context, "or")
   of "^":
      result = unary_reduction(e, context, "xor")
   of "~&":
      result = unary_reduction(e, context, "and")
      invert(result)
   of "~|":
      result = unary_reduction(e, context, "or")
      invert(result)
   of "~^", "^~":
      result = unary_reduction(e, context, "xor")
      invert(result)
   else:
      raise new_evaluation_error("Prefix operator '$1' not implemented.", op)


template infix_operation(x, y: PNode, context: AstContext, kind: TokenKind, size: int, iop, fop: string): Token =
   init(result)
   let xtok = evaluate_constant_expression(x, context, kind, size)
   let ytok = evaluate_constant_expression(y, context, kind, size)
   result.kind = kind
   result.size = size

   case kind
   of TkIntLit, TkUIntLit:
      let ytok_int = to_gmp_int(ytok)
      if iop == "div" and is_zero(ytok_int):
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
   of AmbiguousTokens:
      set_ambiguous(result)
   else:
      raise new_evaluation_error("Infix operation '$1'/'$2' cannot yield kind '$3'.", iop, fop, $result.kind)
   result


template infix_operation(x, y: PNode, context: AstContext, kind: TokenKind, size: int, op: string): Token =
   infix_operation(x, y, context, kind, size, op, op)


proc modulo(x, y: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   init(result)
   let xtok = evaluate_constant_expression(x, context, kind, size)
   let ytok = evaluate_constant_expression(y, context, kind, size)
   result.kind = kind
   result.size = size

   let ytok_int = to_gmp_int(ytok)
   case kind
   of IntegerTokens:
      if kind in AmbiguousTokens or is_zero(ytok_int):
         set_ambiguous(result)
      else:
         # The modulo operation always takes the sign of the first operand. This
         # is exactly how GMP's mod operation behaves so we just use it directly.
         result.base = Base2
         from_gmp_int(result, to_gmp_int(xtok) mod ytok_int)
   else:
      raise new_evaluation_error("Modulo operation not allowed for kind '$1'.", $result.kind)


proc power(x, y: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   init(result)
   let xtok = evaluate_constant_expression(x, context, kind, size)
   # The second operand is always self-determined, so we don't pass the
   # context's kind and size when evaluating this operand.
   let ytok = evaluate_constant_expression(y, context)

   if kind in AmbiguousTokens:
      result.kind = kind
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
      result.kind = kind
      result.size = size
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
         elif ytok.inumber == 0:
            from_gmp_int(result, new_int(1))
         else:
            set_ambiguous(result)
            result.base = Base10
      elif xtok_int == 1:
         from_gmp_int(result, new_int(1))

   else:
      raise new_evaluation_error("Power operation not allowed for kind '$1'.", $result.kind)


template logical_operation(x, y: PNode, context: AstContext, op: string): Token =
   init(result)
   # The operands are self-determined in a logical operation.
   let xtok = evaluate_constant_expression(x, context)
   let ytok = evaluate_constant_expression(y, context)
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
      set_ambiguous(result)
   else:
      result.base = Base2
      from_gmp_int(result, make_infix(xres, yres, op))
   result


template relational_operation(x, y: PNode, context: AstContext, op: string, allow_ambiguous: bool = false): Token =
   init(result)
   # Operands are sized to max(x, y).
   let xprop = determine_kind_and_size(x, context)
   let yprop = determine_kind_and_size(y, context)
   let kind = determine_expression_kind(xprop.kind, yprop.kind)
   let size = max(xprop.size, yprop.size)
   let xtok = evaluate_constant_expression(x, context, kind, size)
   let ytok = evaluate_constant_expression(y, context, kind, size)
   result.base = Base2
   result.kind = TkUIntLit
   result.size = 1

   case kind
   of TkIntLit, TkUIntLit:
      result.inumber = ord(make_infix(to_gmp_int(xtok), to_gmp_int(ytok), op))
      result.literal = $result.inumber
   of TkRealLit:
      result.inumber = ord(make_infix(xtok.fnumber, ytok.fnumber, op))
      result.literal = $result.inumber
   of AmbiguousTokens:
      if allow_ambiguous:
         let xliteral = to_binary_literal(xtok)
         let yliteral = to_binary_literal(ytok)
         result.inumber = ord(make_infix(xliteral, yliteral, op))
         result.literal = $result.inumber
      else:
         set_ambiguous(result)
         result.base = Base10
   else:
      raise new_evaluation_error("Relational operator '$1' cannot parse kind '$2'.", op, $kind)
   result


proc evaluate_constant_infix(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   let op_idx = find_first_index(n, NkIdentifier)
   let lhs_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if op_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid infix node.")

   let lhs = n.sons[lhs_idx]
   let rhs = n.sons[rhs_idx]
   let op = n.sons[op_idx].identifier.s
   case op
   of "+":
      result = infix_operation(lhs, rhs, context, kind, size, "+")
   of "-":
      result = infix_operation(lhs, rhs, context, kind, size, "-")
   of "/":
      result = infix_operation(lhs, rhs, context, kind, size, "div", "/")
   of "*":
      result = infix_operation(lhs, rhs, context, kind, size, "*")
   of "%":
      result = modulo(lhs, rhs, context, kind, size)
   of "**":
      result = power(lhs, rhs, context, kind, size)
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


proc evaluate_constant_function_call(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   # FIXME: Implement
   raise new_evaluation_error("Not implemented")


proc evaluate_constant_identifier(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   # To evaluate a constant identifier we look up its declaration in the context
   # and evaluate what we find.
   let (declaration, _, expression, _) = find_declaration(context, n.identifier)
   if is_nil(declaration):
      raise new_evaluation_error("Failed to find the declaration of identifier '$1'.", n.identifier)
   if is_nil(expression):
      raise new_evaluation_error("The declaration of '$1' does not contain an expression.", n.identifier)
   result = evaluate_constant_expression(expression, context, kind, size)


proc evaluate_constant_multiple_concat(n: PNode, context: AstContext, kind: TokenKind, size: int,
                                       allow_zero: bool): Token =
   init(result)
   let constant_idx = find_first_index(n, ExpressionTypes)
   let concat_idx = find_first_index(n, NkConstantConcat, constant_idx + 1)
   if constant_idx < 0 or concat_idx < 0:
      raise new_evaluation_error("Invalid multiple concatenation node.")

   # The multiplier is self-determined and so is the concatenation. The
   # multiplier has to be nonnegative and not ambiguous. We also assume that the
   # multiplier fits in an int.
   let constant_tok = evaluate_constant_expression(n.sons[constant_idx], context)
   if constant_tok.kind in AmbiguousTokens:
      raise new_evaluation_error("Replication constant cannot be ambiguous.")
   let constant = via_gmp_int(constant_tok)
   if constant < 0:
      raise new_evaluation_error("Replication constant cannot be negative.")
   elif constant == 0:
      if allow_zero:
         result.kind = TkInvalid
         result.size = 0
         return
      else:
         raise new_evaluation_error("Replication with zero is not allowed in this context.")

   let concat_tok = evaluate_constant_expression(n.sons[concat_idx], context)
   for i in 0..<constant:
      add(result.literal, concat_tok.literal)

   result.kind = kind
   result.size = len(result.literal)
   result.base = Base2
   result = convert(result, kind, size)


proc evaluate_constant_concat(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   # In constant concatenation, each son is expected to be a constant
   # expression. We work with the literal value, reading the expressions from
   # left to right, concatenating the literal value as we go. All the
   # expressions are self determined.
   init(result)
   result.kind = kind
   result.base = Base2
   result.size = size

   var idx = -1
   var valid = false
   while true:
      idx = find_first_index(n, ExpressionTypes, idx + 1)
      if idx < 0:
         break
      valid = true
      # FIXME: Add infrastructure to propagate allow_zero = true from evaluate_constant_concat().
      let tok = evaluate_constant_expression(n.sons[idx], context)
      add(result.literal, tok.literal)

   if not valid:
      raise new_evaluation_error("A constant concatenation node must contain at least one expression.")

   result.kind = kind
   result.size = size
   result.base = Base2
   result = convert(result, kind, size)


proc parse_range_infix(n: PNode, context: AstContext): tuple[low, high: int] =
   ## Parse the infix node ``n``, allowing the operators ':', '+:' and '-:' in
   ## additional to all the others.
   let op_idx = find_first_index(n, NkIdentifier)
   let lhs_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if op_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid range.")

   let lhs_tok = evaluate_constant_expression(n.sons[lhs_idx], context)
   let rhs_tok = evaluate_constant_expression(n.sons[rhs_idx], context)
   case n.sons[op_idx].identifier.s
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
   let expression = find_first(n, ExpressionTypes)
   if is_nil(expression):
      raise new_evaluation_error("Invalid range.")
   elif expression.kind == NkInfix:
      result = parse_range_infix(expression, context)
   else:
      let tok = evaluate_constant_expression(n, context)
      result.low = via_gmp_int(tok)
      result.high = result.low


proc evaluate_constant_ranged_identifier(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   let id = find_first(n, NkIdentifier)
   let range = find_first(n, NkConstantRangeExpression)
   if is_nil(id) or is_nil(range):
      raise new_evaluation_error("Invalid ranged identifier node.")

   # Evaluating a constant ranged identifier consists of finding the constant
   # value of the identifier, then extracting the bits between the start and
   # stop indexes.
   result = evaluate_constant_expression(id, context)
   let (low, high) = parse_range(range, context)
   if low < 0 or low >= result.size:
      raise new_evaluation_error("Low index '$1' out of range for identifier '$2'.", low, id.identifier.s)
   elif high < 0 or high >= result.size:
      raise new_evaluation_error("High index '$1' out of range for identifier '$2'.", high, id.identifier.s)

   result.literal = result.literal[^(high + 1)..^(low + 1)]
   result = convert(result, kind, size)


proc evaluate_constant_system_function_call(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   # FIXME: Implement
   raise new_evaluation_error("Not implemented")


proc evaluate_constant_conditional_expression(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   init(result)
   let cond_idx = find_first_index(n, ExpressionTypes)
   let lhs_idx = find_first_index(n, ExpressionTypes, cond_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if cond_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid infix node.")

   # The condition is always self-determined.
   let cond_tok = evaluate_constant_expression(n.sons[cond_idx], context)
   # FIXME: There's something about the operands being zero-extended, regardless
   # of the sign of the surronding expression. That's not how it works currently.
   let rhs_tok = evaluate_constant_expression(n.sons[rhs_idx], context, kind, size)
   let lhs_tok = evaluate_constant_expression(n.sons[lhs_idx], context, kind, size)
   if cond_tok.kind in AmbiguousTokens:
      result.base = Base2
      result.kind = kind
      result.size = size
      if rhs_tok.kind in RealTokens or lhs_tok.kind in RealTokens:
         from_gmp_int(result, new_int(0))
      else:
         for i in 0..<size:
            if lhs_tok.literal[i] == '0' and rhs_tok.literal[i] == '0':
               add(result.literal, '0')
            elif lhs_tok.literal[i] == '1' and rhs_tok.literal[i] == '1':
               add(result.literal, '1')
            else:
               add(result.literal, 'x')
         if XChars in result.literal:
            set_ambiguous(result)
         extend_or_truncate(result, result.kind, result.size)
   elif is_zero(to_gmp_int(cond_tok)):
      result = rhs_tok
   else:
      result = lhs_tok


proc evaluate_constant_expression(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   ## Evalue the constant expression starting in ``n`` in the given ``context``.
   ## The result is represented using a Verilog ``Token`` and an
   ## ``EvaluationError`` is raised if the evaluation fails.
   if is_nil(n):
      raise new_evaluation_error("Invalid node (nil).")

   # We begin by determining the expression size and kind (signed/unsigned/real).
   let (lkind, lsize) = if kind == TkInvalid:
      determine_kind_and_size(n, context)
   else:
      (kind, size)

   case n.kind
   of NkPrefix:
      result = evaluate_constant_prefix(n, context, lkind, lsize)
   of NkInfix:
      result = evaluate_constant_infix(n, context, lkind, lsize)
   of NkConstantFunctionCall:
      result = evaluate_constant_function_call(n, context, lkind, lsize)
   of NkIdentifier:
      result = evaluate_constant_identifier(n, context, lkind, lsize)
   of NkConstantMultipleConcat:
      result = evaluate_constant_multiple_concat(n, context, lkind, lsize, allow_zero = false)
   of NkConstantConcat:
      result = evaluate_constant_concat(n, context, lkind, lsize)
   of NkRangedIdentifier:
      result = evaluate_constant_ranged_identifier(n, context, lkind, lsize)
   of NkConstantSystemFunctionCall:
      result = evaluate_constant_system_function_call(n, context, lkind, lsize)
   of NkParenthesis:
      result = evaluate_constant_expression(find_first(n, ExpressionTypes), context, lkind, lsize)
   of NkConstantConditionalExpression:
      result = evaluate_constant_conditional_expression(n, context, lkind, lsize)
   of NkStrLit:
      init(result)
      result.kind = TkStrLit
      result.literal = n.s
   of NkRealLit:
      init(result)
      result.kind = TkRealLit
      result.fnumber = n.fnumber
      result.literal = n.fraw
   of IntegerTypes:
      init(result)
      result.kind = TokenKind(ord(TkIntLit) + ord(n.kind) - ord(NkIntLit))
      result.literal = n.iraw
      result.base = n.base
      result.size = if n.size < 0: INTEGER_BITS else: n.size
      # When we reach a primitive integer token, we convert the token into the
      # propagated kind and size. If the expression is signed, the token is sign
      # extended. If the integer is part of a real expression, we convert the
      # token to real after sign extending it as a self-determined operand.
      case lkind
      of TkRealLit:
         result = convert(result, result.kind, result.size)
         result.fnumber = to_float(new_rat(to_gmp_int(result)))
         result.literal = $result.fnumber
         result.kind = TkRealLit
         result.size = -1
      of IntegerTokens:
         result = convert(result, lkind, lsize)
      of TkAmbRealLit:
         discard
      else:
         raise new_evaluation_error("Cannot convert a primitive integer token to kind '$1'.", lkind)
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
      if x == TkAmbUIntLit or y == TkAmbUIntLit:
         result = TkAmbUIntLit
      else:
         result = TkUIntLit
   elif x in SignedTokens and x in SignedTokens:
      # If both operands are signed, the result is signed. If any operand is
      # ambiguous, the result is also ambiguous.
      if x == TkAmbIntLit or y == TkAmbIntLit:
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

   case n.sons[op_idx].identifier.s
   of "+", "-", "~":
      result = determine_kind_and_size(n.sons[expr_idx], context)
   of "&", "~&", "|", "~|", "^", "~^", "^~", "!":
      result.size = 1
      result.kind = TkUIntLit
   else:
      raise new_evaluation_error("Invalid prefix operator '$1'.", n.sons[op_idx].identifier.s)


proc determine_kind_and_size_infix(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   let op_idx = find_first_index(n, NkIdentifier)
   let lhs_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if op_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid infix node.")

   let lhs = determine_kind_and_size(n.sons[lhs_idx], context)
   let rhs = determine_kind_and_size(n.sons[rhs_idx], context)
   let op = n.sons[op_idx].identifier.s
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
      # FIXME: Unsized integer literals are not allowed in constant concatenations. We
      # have to capture those here because once determine_kind_and_size() is
      # called, they assume a size of INTEGER_BITS.
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

   let constant_tok = evaluate_constant_expression(n.sons[constant_idx], context)
   let (kind, size) = determine_kind_and_size_concat(n.sons[concat_idx], context)
   result.size = via_gmp_int(constant_tok) * size
   result.kind = kind


proc determine_kind_and_size_ranged_identifier(n: PNode, context: AstContext): tuple[kind: TokenKind, size: int] =
   let id = find_first(n, NkIdentifier)
   let range = find_first(n, NkConstantRangeExpression)
   if is_nil(id) or is_nil(range):
      raise new_evaluation_error("Invalid ranged identifier node.")

   let tok = evaluate_constant_expression(id, context)
   let (low, high) = parse_range(range, context)
   if low < 0 or low > tok.size:
      raise new_evaluation_error("Low index '$1' out of range for identifier '$2'.", low, id.identifier.s)
   elif high < 0 or high > tok.size:
      raise new_evaluation_error("High index '$1' out of range for identifier '$2'.", high, id.identifier.s)

   # The kind of part- or bit-select result is always unsigned, regardless of the operand.
   result.kind = TkUIntLit
   result.size = high - low + 1


proc determine_kind_and_size_system_function_call(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   raise new_evaluation_error("Not implemented")


proc determine_kind_and_size_conditional_expression(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   let condition_idx = find_first_index(n, ExpressionTypes)
   let lhs_idx = find_first_index(n, ExpressionTypes, condition_idx + 1)
   let rhs_idx = find_first_index(n, ExpressionTypes, lhs_idx + 1)
   if condition_idx < 0 or lhs_idx < 0 or rhs_idx < 0:
      raise new_evaluation_error("Invalid conditional expression node.")

   let lhs = determine_kind_and_size(n.sons[lhs_idx], context)
   let rhs = determine_kind_and_size(n.sons[rhs_idx], context)
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
   of NkRangedIdentifier:
      result = determine_kind_and_size_ranged_identifier(n, context)
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
