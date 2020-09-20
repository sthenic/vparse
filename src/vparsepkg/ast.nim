# Abstract syntax tree and symbol table
import strutils
import json
import macros
import math

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
   if n == nil:
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
      if len(n.sons) > 1:
         add(result, ':')
         add(result, $n.sons[1])
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


template evaluate_constant_expression*(n: PNode, context: AstContext): Token =
   evaluate_constant_expression(n, context, TkInvalid, -1)


proc new_evaluation_error(msg: string, args: varargs[string, `$`]): ref EvaluationError =
   new result
   result.msg = format(msg, args)


proc reinterpret(t: var Token) =
   case t.kind
   of TkUIntLit:
      let size = if t.size < 0: INTEGER_BITS else: t.size
      t.inumber = t.inumber and ((1 shl size) - 1)
   of TkIntLit:
      let sign_bit = if t.size > 0: 1 shl (t.size - 1) else: 1 shl (INTEGER_BITS - 1)
      t.inumber = (t.inumber and (sign_bit - 1)) - (t.inumber and sign_bit)
   else:
      discard


proc sign_extend(t: Token, size: int): Token =
   result = t
   reinterpret(result)
   result.size = size


macro make_prefix(x: typed, op: string): untyped =
   result = new_nim_node(nnkPrefix)
   add(result, new_ident_node(op.str_val))
   add(result, x)


template unary(n: PNode, context: AstContext, kind: TokenKind, size: int, op: string): Token =
   init(result)
   let tok = evaluate_constant_expression(n, context, kind, size)
   result.kind = kind
   result.size = size

   case kind
   of TkIntLit, TkUIntLit:
      result.base = Base10
      result.inumber = make_prefix(tok.inumber, op)
      reinterpret(result)
      result.literal = $result.inumber
   of TkRealLit:
      result.fnumber = make_prefix(tok.fnumber, op)
      result.literal = $result.fnumber
   of AmbiguousTokens:
      set_ambiguous(result)
   else:
      raise new_evaluation_error("Unary operator '$1' cannot yield kind '$2'.", op, $kind)
   result


proc negate(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   init(result)
   let tok = evaluate_constant_expression(n, context, kind, size)
   result.kind = kind
   result.size = size

   case kind
   of TkIntLit, TkUIntLit:
      result.base = Base10
      result.inumber = not tok.inumber
      reinterpret(result)
      result.literal = $result.inumber
   of TkAmbIntLit, TkAmbUIntLit:
      # For ambiguous values we have to work with the literal value. We can
      # handle all numeric bases as base 16 since the lexer has ensured that the
      # token we get is on the correct format. Other than 'dx, 'dz etc.,
      # ambiguous decimal literals consisting of multiple digitis in are not
      # legal syntax.
      set_len(result.literal, 0)
      result.base = tok.base
      let mask = case tok.base
         of Base2:
            0x1
         of Base8:
            0x7
         of Base16:
            0xF
         of Base10:
            0

      for c in tok.literal:
         case c
         of HexChars:
            let val = not parse_hex_int($c) and mask
            add(result.literal, to_hex(val, 1))
         of ZChars, XChars:
            add(result.literal, 'x')
         else:
            raise new_evaluation_error("Invalid literal character '$1'.", c)
   else:
      raise new_evaluation_error("Bitwise negation cannot yield kind '$1'.", $kind)


proc evaluate_constant_prefix(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   init(result)
   let op_idx = find_first_index(n, NkIdentifier)
   let e_idx = find_first_index(n, ExpressionTypes, op_idx + 1)
   if op_idx < 0 or e_idx < 0:
      raise new_evaluation_error("Invalid infix node.")

   let e = n.sons[e_idx]
   let op = n.sons[op_idx].identifier.s
   case op
   of "+":
      result = unary(e, context, kind, size, "+")
   of "-":
      result = unary(e, context, kind, size, "-")
   of "~":
      result = negate(e, context, kind, size)
   else:
      raise new_evaluation_error("Prefix operator '$1' not implemented.", op)


macro make_infix(x, y: typed, op: string): untyped =
   result = new_nim_node(nnkInfix)
   add(result, new_ident_node(op.str_val))
   add(result, x)
   add(result, y)


template infix_operation(x, y: PNode, context: AstContext, kind: TokenKind, size: int, iop, fop: string): Token =
   init(result)
   let xtok = evaluate_constant_expression(x, context, kind, size)
   let ytok = evaluate_constant_expression(y, context, kind, size)
   result.kind = kind
   result.size = size

   case kind
   of TkIntLit, TkUIntLit:
      if iop == "div" and ytok.inumber == 0:
         set_ambiguous(result)
      else:
         result.base = Base10
         result.inumber = make_infix(xtok.inumber, ytok.inumber, iop)
         # We have to be prepared to reinterpret the result of an integer operation
         # to deal with overflow, underflow and truncation.
         reinterpret(result)
         result.literal = $result.inumber
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
   # The modulo operation always takes the sign of the first operand.
   result.kind = xtok.kind
   result.size = size

   case kind
   of IntegerTokens:
      if kind in AmbiguousTokens or ytok.inumber == 0:
         set_ambiguous(result)
      else:
         result.base = Base10
         result.inumber = xtok.inumber mod ytok.inumber
         reinterpret(result)
         result.literal = $result.inumber
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
      if (xtok.fnumber == 0.0 and ytok.inumber < 0) or (xtok.fnumber < 0):
         set_ambiguous(result)
      else:
         result.fnumber = pow(xtok.fnumber, to_biggest_float(ytok.inumber))
         result.literal = $result.fnumber

   elif ytok.kind == TkRealLit:
      result.kind = TkRealLit
      result.size = -1
      if xtok.inumber < 0:
         set_ambiguous(result)
      else:
         result.fnumber = pow(to_biggest_float(xtok.inumber), ytok.fnumber)
         result.literal = $result.fnumber

   elif xtok.kind in IntegerTokens and ytok.kind in IntegerTokens:
      result.kind = kind
      result.size = size
      result.base = Base10

      if xtok.inumber < -1 or xtok.inumber > 1:
         if ytok.inumber > 0:
            result.inumber = xtok.inumber ^ ytok.inumber
         elif ytok.inumber == 0:
            result.inumber = 1
         else:
            result.inumber = 0
      elif xtok.inumber == -1:
         if ytok.inumber == 0:
            result.inumber = 1
         elif (ytok.inumber mod 2) == 0:
            result.inumber = 1
         else:
            result.inumber = -1
      elif xtok.inumber == 0:
         if ytok.inumber > 0:
            result.inumber = 0
         elif ytok.inumber == 0:
            result.inumber = 1
         else:
            set_ambiguous(result)
      elif xtok.inumber == 1:
         result.inumber = 1

      reinterpret(result)
      if result.kind notin AmbiguousTokens:
         result.literal = $result.inumber

   else:
      raise new_evaluation_error("Power operation not allowed for kind '$1'.", $result.kind)


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
   # FIXME: apply size and kind to what we get?


proc evaluate_constant_multiple_concat(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   # FIXME: Implement
   raise new_evaluation_error("Not implemented")


proc evaluate_constant_concat(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   # FIXME: Implement
   raise new_evaluation_error("Not implemented")


proc evaluate_constant_ranged_identifier(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   # FIXME: Implement
   raise new_evaluation_error("Not implemented")


proc evaluate_constant_system_function_call(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   # FIXME: Implement
   raise new_evaluation_error("Not implemented")


proc evaluate_constant_conditional_expression(n: PNode, context: AstContext, kind: TokenKind, size: int): Token =
   # FIXME: Implement
   raise new_evaluation_error("Not implemented")


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
      result = evaluate_constant_multiple_concat(n, context, lkind, lsize)
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
      result.inumber = n.inumber
      result.literal = n.iraw
      result.base = n.base
      result.size = n.size
      # If this integer is part of a real expression we convert the token to
      # real after sign extending it as a self-determined operand. Otherwise, we
      # sign extend the integer in the expression's full context.
      if lkind == TkRealLit:
         result = sign_extend(result, n.size)
         result.kind = TkRealLit
         result.fnumber = to_biggest_float(result.inumber)
         result.literal = $result.fnumber
         result.size = -1
      else:
         # FIXME: Kind conversion too?
         result = sign_extend(result, lsize)
   else:
      raise new_evaluation_error("The node '$1' is not an expression.", n.kind)


template determine_expression_kind(x, y: TokenKind): TokenKind =
   if x == TkRealLit or y == TkRealLit:
      # If any operand is real, the result is real. If any operand is
      # ambiguous (containing X or Z), the result is also ambiguous.
      if x in AmbiguousTokens or y in AmbiguousTokens:
         TkAmbRealLit
      else:
         TkRealLit
   elif x in UnsignedTokens or y in UnsignedTokens:
      # If any operand is unsigned, the result is unsigned. If any operand is
      # ambiguous (containing X or Z), the result is also ambiguous.
      if x == TkAmbUIntLit or y == TkAmbUIntLit:
         TkAmbUIntLit
      else:
         TkUIntLit
   elif x in SignedTokens and x in SignedTokens:
      # If both operands are signed, the result is signed. If any operand is
      # ambiguous, the result is also ambiguous.
      if x == TkAmbIntLit or y == TkAmbIntLit:
         TkAmbIntLit
      else:
         TkIntLit
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


proc determine_kind_and_size_concat(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   for s in walk_sons(n, ExpressionTypes):
      let (_, size) = determine_kind_and_size(s, context)
      inc(result.size, size)


proc determine_kind_and_size_multiple_concat(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   let factor_idx = find_first_index(n, ExpressionTypes)
   let concat_idx = find_first_index(n, NkConstantConcat, factor_idx + 1)
   if factor_idx < 0 or concat_idx < 0:
      raise new_evaluation_error("Invalid multiple concatenation node.")

   let factor = evaluate_constant_expression(n.sons[factor_idx], context)
   let (_, size) = determine_kind_and_size_concat(n.sons[concat_idx], context)
   result.size = int(factor.inumber) * size


proc determine_kind_and_size_ranged_identifier(n: PNode, context: AstContext):
      tuple[kind: TokenKind, size: int] =
   result.kind = TkUIntLit
   let range = find_first(n, NkConstantRangeExpression)
   if is_nil(range):
      raise new_evaluation_error("Invalid ranged identifier node.")

   let first_idx = find_first_index(range, ExpressionTypes)
   let second_idx = find_first_index(range, ExpressionTypes, first_idx +  1)
   let infix_idx = find_first_index(range, NkInfix)
   if infix_idx >= 0:
      let infix = range.sons[infix_idx]
      let infix_op_idx = find_first_index(infix, NkIdentifier)
      let infix_first_idx = find_first_index(infix, ExpressionTypes, infix_op_idx + 1)
      let infix_second_idx = find_first_index(infix, ExpressionTypes, infix_first_idx + 1)
      if infix_op_idx < 0 or infix_first_idx < 0 or infix_second_idx < 0:
         raise new_evaluation_error("bInvalid ranged identifier node.")
      result.size = int(evaluate_constant_expression(infix.sons[infix_second_idx], context).inumber)
   elif first_idx >= 0:
      if second_idx >= 0:
         let first = evaluate_constant_expression(range.sons[first_idx], context)
         let second = evaluate_constant_expression(range.sons[second_idx], context)
         result.size = int(first.inumber - second.inumber) + 1
         if result.size < 0 or
               first.kind in RealTokens + AmbiguousTokens or
               second.kind in RealTokens + AmbiguousTokens:
            raise new_evaluation_error("aInvalid ranged identifier node.")
      else:
         result.size = 1
   else:
      raise new_evaluation_error("cInvalid ranged identifier node.")


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
      result.kind = TokenKind(ord(TkIntLit) + ord(n.kind) - ord(NkIntLit))
      if n.size > 0:
         result.size = n.size
      else:
         result.size = INTEGER_BITS
   else:
      raise new_evaluation_error("The node '$1' is not an expression.", n.kind)
