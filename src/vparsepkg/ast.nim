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
      NkParamAssignment, NkNetDeclAssignment,
      # Declaration ranges A.2.5
      NkRange,
      # Function declarations A.2.6
      NkFunctionDecl,
      # Task declarations A.2.7
      NkTaskDecl,
      # Module instantiation A.4.1
      NkModuleInstantiation, NkParameterValueAssignment, NkModuleInstance,
      NkPortConnection,
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
   IdentifierTypes =
      {NkIdentifier, NkAttributeName, NkModuleIdentifier, NkPortIdentifier,
       NkParameterIdentifier, NkSpecparamIdentifier, NkType,
       NkFunctionIdentifier, NkGenvarIdentifier, NkDirection, NkNetType,
       NkAttributeName}
   IntegerTypes =
      {NkIntLit, NkUIntLit, NkAmbIntLit, NkAmbUIntLit}

   # FIXME: Unused right now
   OperatorTypes = {NkUnaryOperator, NkBinaryOperator}

   ErrorTypes = {NkTokenError, NkTokenErrorSync, NkCritical}

type
   PNode* = ref TNode
   TNodeSeq* = seq[PNode]
   TNode = object of RootObj
      loc*: Location
      case kind*: NodeKind
      of NkStrLit:
         s*: string
      of NkIntLit, NkUIntLit, NkAmbIntLit, NkAmbUIntLit:
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
   of NkStrLit:
      add(result, format(": $1\n", n.s))
   of NkWildcard:
      add(result, "\n")
   else:
      add(result, "\n")
      var sons_str = ""
      for s in n.sons:
         add(sons_str, pretty(s, indent + 2))

      add(result, sons_str)


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
   of NkStrLit:
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
   of NkStrLit:
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
   of IdentifierTypes, IntegerTypes, NkRealLit, OperatorTypes, NkStrLit, NkWildcard:
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


proc new_error_node*(kind: NodeKind, loc: Location, raw, msg: string,
                     args: varargs[string, `$`]): PNode =
   result = new_node(kind, loc)
   result.msg = format(msg, args)
   result.eraw = raw
