# Abstract syntax tree and symbol table
import strutils
import json

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
      NkAssignment,
      # Modules A.1.3
      NkSourceText,
      NkModuleDecl,
      # Module parameters and ports A.1.4
      NkModuleParameterPortList, NkListOfPorts, NkListOfPortDeclarations,
      NkPort, NkPortExpression, NkPortReference, NkPortReferenceConcat,
      NkPortDecl, NkVariablePort,
      # Parameter declarations A.2.1.1
      NkLocalparamDecl, NkDefparamDecl, NkParameterDecl, NkSpecparamDecl,
      # Type declarations A.2.1.3
      NkEventDecl, NkGenvarDecl, NkIntegerDecl, NkNetDecl, NkRealDecl,
      NkRealtimeDecl, NkRegDecl, NkTimeDecl,
      # Net and variable types A.2.2.1
      NkNetType,
      # Drive strengths A.2.2.2
      NkDriveStrength, NkChargeStrength,
      # Delays A.2.2.3
      NkDelay,
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
      NkConstantMinTypMaxExpression,
      NkConstantConditionalExpression, NkConstantRangeExpression,
      NkBracketExpression, NkDotExpression,
      # Primaries A.8.4
      NkConstantPrimary,
      # Expression left-side values A.8.5
      NkVariableLvalueConcat,
      # Attributes A.9.1
      NkAttributeInst, NkAttributeSpec, NkAttributeName,
      # AST nodes unused by the parser that exists to provide the test suite
      # with the option to target specific grammars.
      NkConstantExpression, NkHierarchicalIdentifier

   NodeKinds* = set[NodeKind]


const
   IdentifierTypes* = {NkIdentifier, NkAttributeName, NkType, NkDirection, NkNetType}

   HierarchicalIdentifierTypes* = {NkIdentifier, NkBracketExpression, NkDotExpression}

   LvalueTypes* = HierarchicalIdentifierTypes + {NkVariableLvalueConcat}

   IntegerTypes* =
      {NkIntLit, NkUIntLit, NkAmbIntLit, NkAmbUIntLit}

   ErrorTypes* = {NkTokenError, NkTokenErrorSync, NkCritical}

   PrimitiveTypes* =
      ErrorTypes + IdentifierTypes + IntegerTypes +
      {NkRealLit, NkStrLit, NkWildcard, NkComment}

   DeclarationTypes* =
      {NkNetDecl, NkRegDecl, NkPortDecl, NkRealDecl, NkTaskDecl, NkTimeDecl,
       NkEventDecl, NkGenvarDecl, NkModuleDecl, NkIntegerDecl, NkDefparamDecl,
       NkFunctionDecl, NkRealtimeDecl, NkParameterDecl, NkSpecparamDecl,
       NkLocalparamDecl, NkModuleParameterPortList, NkListOfPortDeclarations,
       NkListOfPorts, NkTaskFunctionPortDecl, NkModuleInstance}

   ConcatenationTypes* =
      {NkConstantConcat, NkConstantMultipleConcat, NkPortReferenceConcat,
       NkVariableLvalueConcat}

   # FIXME: Add NkDotExpression?
   ExpressionTypes* =
      IntegerTypes + {NkRealLit, NkPrefix, NkInfix, NkConstantFunctionCall,
      NkIdentifier, NkBracketExpression, NkConstantMultipleConcat,
      NkConstantConcat, NkConstantSystemFunctionCall, NkParenthesis,
      NkStrLit, NkConstantConditionalExpression}


type
   PNode* = ref TNode
   TNodeSeq* = seq[PNode]
   TNode {.final, acyclic.} = object
      loc*: Location
      case kind*: NodeKind
      of NkStrLit, NkComment:
         s*: string
      of IntegerTypes:
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


template `[]`*(n: PNode, i: int): PNode = n.sons[i]
template `[]=`*(n: PNode, i: int, x: PNode) = n.sons[i] = x
template `[]`*(n: PNode, i: BackwardsIndex): PNode = n[len(n) - int(i)]
template `[]=`*(n: PNode, i: BackwardsIndex, x: PNode) = n[len(n) - int(i)] = x


proc len*(n: PNode): int {.inline.} =
   if is_nil(n):
      result = 0
   else:
      result = len(n.sons)


proc add*(n, son: PNode) =
   add(n.sons, son)


proc pretty*(n: PNode, indent: int = 0): string =
   if is_nil(n):
      return
   result = spaces(indent) & $n.kind & $n.loc
   case n.kind
   of IdentifierTypes:
      add(result, ": " & $n.identifier.s & "\n")
   of IntegerTypes:
      add(result, format(": '$1' (base: $2, size: $3)\n", n.iraw, n.base, n.size))
   of NkRealLit:
      add(result, format(": $1 (raw: '$2')\n", n.fnumber, n.fraw))
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
      result = x.iraw == y.iraw and x.base == y.base and x.size == y.size
   of NkRealLit:
      result = x.fnumber == y.fnumber
   of NkStrLit, NkComment:
      result = x.s == y.s
   of ErrorTypes, NkWildcard:
      return true
   else:
      if len(x) != len(y):
         return false

      result = true
      for i in 0..<len(x):
         if x[i] != y[i]:
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
   of IdentifierTypes, IntegerTypes, NkRealLit, ErrorTypes, NkStrLit, NkWildcard:
      if x != y:
         echo "Node contents differs:\n", pretty(x, indent), pretty(y, indent)
         return
   else:
      if len(x) != len(y):
         let str = format("Length of subtree differs, LHS($1), RHS($2):\n",
                          len(x), len(y))
         echo str, pretty(x, indent), pretty(y, indent)
         return

      for i in 0..<len(x):
         detailed_compare(x[i], y[i])


proc has_errors*(n: PNode): bool =
   ## Returns ``true`` if the AST starting with the node ``n`` contains errors.
   case n.kind
   of ErrorTypes:
      return true
   of PrimitiveTypes - ErrorTypes:
      return false
   else:
      for i in 0..<len(n):
         if has_errors(n[i]):
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


proc new_inumber_node*(kind: NodeKind, loc: Location, raw: string,
                       base: NumericalBase, size: int): PNode =
   result = new_node(kind, loc)
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
   if n.kind notin PrimitiveTypes and start < len(n):
      for i in start..high(n.sons):
         if n[i].kind in kinds:
            return n[i]


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
   if n.kind notin PrimitiveTypes and start < len(n):
      for i in start..high(n.sons):
         if n[i].kind in kinds:
            return i


template find_first_index*(n: PNode, kind: NodeKind, start: Natural = 0): int =
   ## Return the index of the first son in ``n`` whose kind is ``kind``.
   ## If a matching node cannot be found, ``-1`` is returned. The search
   ## begins at ``start``.
   find_first_index(n, {kind}, start)


template walk_sons_common(n: PNode, kinds: NodeKinds, start: Natural = 0) =
   if n.kind notin PrimitiveTypes and start < len(n):
      for i in start..high(n.sons):
         if n[i].kind in kinds:
            yield n[i]


template walk_sons_common_index(n: PNode, kinds: NodeKinds, start: Natural = 0) =
   if n.kind notin PrimitiveTypes and start < len(n):
      var idx = 0
      for i in start..high(n.sons):
         if n[i].kind in kinds:
            yield (idx, n[i])
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
   ## Walk the sons in ``n`` between indexes ``start`` and ``stop``. If ``stop``
   ## is omitted, the iterator continues until the last son has been returned.
   if n.kind notin PrimitiveTypes:
      var lstop = stop
      var lstart = start
      if stop < 0 or stop > high(n.sons):
         lstop = high(n.sons)
      for i in lstart..lstop:
         yield n[i]


iterator walk_port_list*(n: PNode): PNode {.inline.} =
   ## Walk the nodes in the port list of module ``n``. That list may either be a
   ## 'list of port declarations', for which this iterator yields ``NkPortDecl``
   ## nodes, or a 'list of ports', in which case ``NkPort`` nodes are yielded
   ## instead. A module declaration can only ever use one of these syntaxes.
   let list = find_first(n, {NkListOfPortDeclarations, NkListOfPorts})
   if not is_nil(list):
      for port in walk_sons(list, {NkPortDecl, NkPort}):
         yield port


iterator walk_port_references*(n: PNode): PNode {.inline.} =
   ## Walk the port references of a module. Port references only exists if the
   ## module uses a 'list of ports' to describe its interface and puts the actual
   ## port declarations within the module body. The node ``n`` is expected to be
   ## a ``NkModuleDecl``.
   for port in walk_port_list(n):
      if port.kind != NkPort:
         continue

      let port_ref_concat = find_first(port, NkPortReferenceConcat)
      if not is_nil(port_ref_concat):
         for port_ref in walk_sons(port_ref_concat, NkPortReference):
            yield port_ref
         continue

      let port_ref = find_first(port, NkPortReference)
      if not is_nil(port_ref):
         yield port_ref


iterator walk_nodes_starting_with*(nodes: openarray[PNode], prefix: string): PNode =
   for n in nodes:
      if n.kind in IdentifierTypes and starts_with(n.identifier.s, prefix):
         yield n


proc find_all_identifiers*(n: PNode, context: var AstContext, recursive: bool = false):
      seq[tuple[identifier: PNode, context: AstContext]] =
   ## Find all the identifiers in ``n``, returning a tuple of each identifier
   ## node and its context.
   case n.kind
   of IdentifierTypes:
      if n.identifier.s in SpecialWords:
         return
      add(result, (n, context))
   of PrimitiveTypes - IdentifierTypes:
      discard
   of NkDotExpression:
      for i, s in n.sons:
         if s.kind notin IdentifierTypes:
            add(context, i, n)
            add(result, find_all_identifiers(s, context, recursive))
            discard pop(context)
   else:
      if not recursive:
         return
      for i, s in n.sons:
         add(context, i, n)
         add(result, find_all_identifiers(s, context, recursive))
         discard pop(context)


iterator walk_identifiers*(n: PNode, recursive: bool = false):
      tuple[identifier: PNode, context: AstContext] {.inline.} =
   ## Walk all identifiers in ``n`` (depth first) returning a tuple of the
   ## identifier node and its context.
   var context: AstContext
   for (n, c) in find_all_identifiers(n, context, recursive):
      yield (n, c)


proc check_external_identifier*(context: AstContext): tuple[value: bool, kind: NodeKind] =
   ## Given the ``context`` of an identifier, check if its declaration is an
   ## external object. This proc returns a tuple with the boolean ``value`` and
   ## the ``kind`` of the external symbol:
   ##   - ``NkModuleInstantiation`` for module instances,
   ##   - ``NkNamedPortConnection`` for named module instance port connections; and
   ##   - ``NkNamedParameterAssignment`` for named module instance parameter port assignments.
   ##
   ## If the ``value`` is ``false``, then the ``kind`` is undefined.
   if len(context) == 0:
      return (false, NkInvalid)

   let n = context[^1].n
   case n.kind
   of NkModuleInstantiation:
      result = (true, NkModuleInstantiation)
   of NkNamedPortConnection, NkNamedParameterAssignment:
      # It's only an external identifier if it's the one following the dot
      # character, i.e. if it's the first identifier we find.
      var seen_another_identifier = false
      for i in 0..<context[^1].pos:
         seen_another_identifier = (n.sons[i].kind == NkIdentifier)
      result = (not seen_another_identifier, n.kind)
   else:
      result = (false, NkInvalid)


proc is_external_identifier*(context: AstContext): bool =
   ## Given the ``context`` of an identifier, check if its declaration is an
   ## external object.
   result = check_external_identifier(context).value


proc get_module_name_from_connection*(context: AstContext): PNode =
   ## Assuming the ``context`` points to a named connection in a module instance,
   ## retrieve the module name as an identifier node. If the context is
   ## malformed, the return value is ``nil``.
   result = nil
   if len(context) >= 3:
      result = find_first(context[^3].n, NkIdentifier)


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
   of NkDotExpression:
      # TODO: Lookup of hierarchical identifiers are currently not supported.
      # However, identifiers contained in bracket expressions (could be one of
      # the sons) should still be included. We skip any identifier nodes that
      # are directly in the list of sons to this dot expression node.
      for i, s in n.sons:
         if s.kind notin IdentifierTypes:
            add(context, i, n)
            result = find_identifier(s, loc, context, added_length)
            if not is_nil(result):
               return
            discard pop(context)
   else:
      # TODO: Perhaps we can improve the search here? Skipping entire subtrees
      #       depending on the location of the first node within?
      for i, s in n.sons:
         add(context, i, n)
         result = find_identifier(s, loc, context, added_length)
         if not is_nil(result):
            return
         discard pop(context)


proc find_identifier_physical*(n: PNode, locs: Locations, loc: Location, context: var AstContext,
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
   of NkPortDecl, NkGenvarDecl:
      # A port or genvar declaration allows a list of identifiers.
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
         for id in walk_sons(s, NkIdentifier):
            if id.identifier.s == identifier.s:
               return (s, id, nil)

   of NkRegDecl, NkIntegerDecl, NkRealDecl, NkRealtimeDecl, NkTimeDecl, NkNetDecl, NkEventDecl:
      for s in n.sons:
         case s.kind
         of NkBracketExpression:
            var id = s
            while id.kind == NkBracketExpression and len(id) > 0:
               id = id[0]
            if id.kind == NkIdentifier and id.identifier.s == identifier.s:
               return (n, id, nil)
         of NkAssignment:
            let id = find_first(s, NkIdentifier)
            if not is_nil(id) and id.identifier.s == identifier.s:
               return (n, id, find_first(s, ExpressionTypes))
         of NkIdentifier:
            if s.identifier.s == identifier.s:
               return (n, s, nil)
         else:
            discard

   of NkParameterDecl, NkLocalparamDecl, NkSpecparamDecl:
      # When we find an NkAssignment node, the first son is expected to be
      # the identifier.
      for s in walk_sons(n, NkAssignment):
         let id_idx = find_first_index(s, NkIdentifier)
         if id_idx >= 0 and s[id_idx].identifier.s == identifier.s:
            return (n, s[id_idx], find_first(s, ExpressionTypes, id_idx + 1))

   of NkModuleDecl, NkModuleInstance:
      let id = find_first(n, NkIdentifier)
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


proc find_port_reference_declaration*(context: AstContext, identifier: PIdentifier):
      tuple[declaration, identifier, expression: PNode, context: AstContextItem] =
   # Traverse the context bottom-up until we find the module declaration.
   # Descend into the body looking for the port declaration, ignoring everything
   # else.
   result.declaration = nil
   result.identifier = nil
   result.expression = nil
   result.context = AstContextItem(n: nil, pos: 0)
   for i in countdown(high(context), 0):
      if context[i].n.kind == NkModuleDecl:
         result.context = context[i]
         break

   # Once we have the module declaration, look through the sons for the matching
   # port declaration, remembering that the port declaration syntax allows for a
   # list of identifiers.
   if not is_nil(result.context.n):
      for declaration in walk_sons(result.context.n, NkPortDecl):
         for id in walk_sons(declaration, NkIdentifier):
            if id.identifier.s == identifier.s:
               result.declaration = declaration
               result.identifier = id
               return


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
      if context_item.n.kind == NkPortReference:
         # Port references are a bit special since they work with a 'delayed'
         # declaration, presumed to appear in the module body. We handle these
         # as a special case.
         return find_port_reference_declaration(context, identifier)
      elif context_item.n.kind notin PrimitiveTypes:
         for pos in countdown(context_item.pos, 0):
            let s = context_item.n[pos]
            if s.kind in DeclarationTypes - {NkDefparamDecl}:
               (result.declaration, result.identifier, result.expression) = find_declaration(s, identifier)
               if not is_nil(result.declaration):
                  if context_item.n.kind in {NkModuleParameterPortList, NkListOfPortDeclarations}:
                     # If the declaration is enclosed in any of the list types,
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
   of NkPortDecl, NkGenvarDecl:
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
         of NkBracketExpression:
            var id = s
            while id.kind == NkBracketExpression and len(id) > 0:
               id = id[0]
            if id.kind == NkIdentifier:
               add(result, (n, id))
         of NkAssignment:
            let id = find_first(s, NkIdentifier)
            add(result, (n, id))
         of NkIdentifier:
            add(result, (n, s))
         else:
            discard

   of NkParameterDecl, NkLocalparamDecl:
      for s in walk_sons(n, NkAssignment):
         let id = find_first(s, NkIdentifier)
         if not is_nil(id):
            add(result, (n, id))

   of NkSpecparamDecl:
      for s in walk_sons(n, NkAssignment):
         let id = find_first(s, NkIdentifier)
         if not is_nil(id):
            add(result, (n, id))

   of NkModuleDecl:
      let idx = find_first_index(n, NkIdentifier)
      if idx > -1:
         add(result, (n, n[idx]))
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
            add(result, find_all_declarations(context_item.n[pos]))


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


iterator walk_module_instantiations*(n: PNode): PNode {.inline.} =
   ## Walk the module instantations contained in the module declaration ``n``.
   ## The node ``n`` is expected to be a ``NkModuleDecl``. This iterator yields
   ## nodes of type ``NkModuleInstantation``.
   if not is_nil(n) and n.kind == NkModuleDecl:
      for inst in find_all_module_instantiations(n):
         yield inst


iterator walk_ports*(n: PNode): tuple[declaration, identifier: PNode] {.inline.} =
   ## Walk the externally visible ports of the module declaration ``n``. If the
   ## module uses port references, this iterator will not yield for the internal
   ## identifiers.
   for port in walk_port_list(n):
      case port.kind
      of NkPortDecl:
         # A port declaration may contain multiple identifiers.
         for id in walk_sons(port, NkIdentifier):
            yield (port, id)
      of NkPort:
         # If we find a port identifier as the first node, that's the name that
         # this port is known by from the outside. Otherwise, we're looking for
         # the first identifier in a port reference, also known as an 'implicit
         # port'. For these ports, we try to find the matching declaration in
         # the module body. Unnamed port reference concatenations are not
         # addressable from the outside.
         let id = find_first(port, NkIdentifier)
         if not is_nil(id):
            yield (port, id)
         else:
            let id = find_first_chain(port, [NkPortReference, NkIdentifier])
            if not is_nil(id):
               for s in walk_sons(n, NkPortDecl):
                  let (declaration, _, _) = find_declaration(s, id.identifier)
                  if not is_nil(declaration):
                     yield (declaration, id)
      else:
         discard


iterator walk_parameters*(n: PNode): tuple[declaration, identifier: PNode] {.inline.} =
   ## Walk all the externally visible parameters of the module declaration ``n``.
   ## The iterator yields a tuple where the declaration node
   ## (``NkParameterDecl``) is paired with the declared identifier
   ## (``NkIdentifier``). Since parameter declaration statements may declare more
   ## than one parameter with the same properties, the same declaration node may
   ## appear more than once, although the identifier is different.
   template yield_parameters(n: PNode) =
      for declaration in walk_sons(n, NkParameterDecl):
         for assignment in walk_sons(declaration, NkAssignment):
            let id = find_first(assignment, NkIdentifier)
            if not is_nil(id):
               yield (declaration, id)

   # Add parameter declarations from the parameter port list. Otherwise, we
   # check the module body for parameter declarations. The two are mutually
   # exclusive according to Section 4.10.1.
   let declarations = find_first(n, NkModuleParameterPortList)
   if not is_nil(declarations):
      yield_parameters(declarations)
   else:
      yield_parameters(n)


proc find_all_lvalues*(n: PNode): seq[PNode] =
   if is_nil(n):
      return

   case n.kind
   of NkIdentifier, NkBracketExpression, NkDotExpression:
      add(result, n)
   of NkVariableLvalueConcat:
      for s in walk_sons(n, LvalueTypes):
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
         for id in walk_sons(n, NkIdentifier):
            add(result, (n, id))

   of NkContinuousAssignment:
      for assignment in walk_sons(n, NkAssignment):
         let lvalue_node = find_first(assignment, LvalueTypes)
         for lvalue in find_all_lvalues(lvalue_node):
            add(result, (n, lvalue))

   of NkProceduralContinuousAssignment, NkBlockingAssignment, NkNonblockingAssignment:
      let lvalue_node = find_first(n, LvalueTypes)
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
            add(result, find_all_drivers(context_item.n[pos]))


proc find_all_ports*(n: PNode): seq[tuple[declaration, identifier: PNode]] =
   ## Find all ports of the module declaration ``n``. See ``walk_ports``.
   for t in walk_ports(n):
      add(result, t)


proc find_all_parameters*(n: PNode): seq[tuple[declaration, identifier: PNode]] =
   ## Find all the parameters of the module declaration ``n``. See ``walk_parameters``.
   for t in walk_parameters(n):
      add(result, t)


# FIXME: This entire thing doesn't work that well with attributes.
proc `$`*(n: PNode): string =
   if n == nil:
      return

   case n.kind:
   of IdentifierTypes:
      result = n.identifier.s

   of NkBracketExpression:
      add(result, $n[0])
      add(result, '[')
      add(result, $n[1])
      add(result, ']')

   of NkDotExpression:
      add(result, $n[0])
      add(result, '.')
      add(result, $n[1])

   of NkConstantRangeExpression:
      add(result, '[')
      add(result, $n[0])
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
      add(result, $n[1])
      add(result, ' ' & $n[0] & ' ')
      add(result, $n[2])

   of NkRange:
      add(result, '[')
      add(result, $n[0])
      add(result, ':')
      add(result, $n[1])
      add(result, ']')

   of NkAssignment, NkBlockingAssignment, NkProceduralContinuousAssignment:
      add(result, $n[0])
      add(result, " = ")
      add(result, $n[1])

   of NkNonblockingAssignment:
      add(result, $n[0])
      add(result, " <= ")
      add(result, $n[1])

   of NkAttributeInst:
      add(result, "(* ")
      for i in countup(0, high(n.sons), 2):
         add(result, format("$1 = $2", n[i], n[i+1]))
      add(result, " *)")

   of NkPort:
      let id = find_first(n, NkIdentifier)
      if not is_nil(id):
         add(result, format(".$1($2)", $id, $n[1]))
      else:
         add(result, $n[0])

   of ErrorTypes, NkExpectError, NkComment:
      discard

   of NkDelay:
      add(result, '#')
      if n[0].kind == NkParenthesis:
         add(result, '(')
         for i, s in n[0].sons:
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
         add(result, n[idx].identifier.s)
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
         if s.kind in {NkIdentifier, NkAssignment, NkAssignment}:
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
      add(result, $n[0])
      add(result, $n[1])
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
