# Abstract syntax tree and symbol table
import strutils

import ../lexer/lexer
import ../lexer/identifier


type
   NodeType* = enum
      NtInvalid, # An invalid node, indicates an error
      NtError, # An error node
      # Atoms
      NtEmpty, # An empty node
      NtIdentifier, # The node is an identifier
      NtSymbol, # the node is a symbol
      NtStrLit, # the node is a string literal
      NtIntLit, # the node is an integer literal
      NtUIntLit, # the node is an unsigned integer literal
      NtAmbIntLit, # the node is an integer literal
      NtAmbUIntLit, # the node is an unsigned integer literal
      NtRealLit, # the node is a real value
      NtType,
      NtPrefix,
      NtInfix,
      NtParenthesis,
      NtDirection,
      NtWildcard, # Symbolizes a '*' in an event expression.
      # Custom node types
      NtRangedIdentifier, # FIXME: Still useful? Same as NtArrayIdentifier?
      NtArrayIdentifer,
      NtAssignment,
      # Modules A.1.3
      NtSourceText,
      NtModuleDecl,
      NtModuleIdentifier,
      # Module parameters and ports A.1.4
      NtModuleParameterPortList, NtListOfPorts, NtListOfPortDeclarations,
      NtPort, NtPortExpression, NtPortReference, NtPortReferenceConcat,
      NtPortIdentifier, NtPortDecl, NtVariablePort,
      # Parameter declarations A.2.1.1
      NtLocalparamDecl, NtDefparamDecl, NtParameterDecl, NtSpecparamDecl,
      # Port declarations A.2.1.2
      NtInoutDecl, NtInputDecl, NtOutputDecl, # FIXME: Remove if unused
      # Type declarations A.2.1.3
      NtEventDecl, NtGenvarDecl, NtIntegerDecl, NtNetDecl, NtRealDecl,
      NtRealtimeDecl, NtRegDecl, NtTimeDecl,
      # Net and variable types A.2.2.1
      NtNetType,
      # Drive strengths A.2.2.2
      NtDriveStrength, NtChargeStrength,
      # Delays A.2.2.3
      NtDelay,
      # Declaration assignments A.2.4
      NtParamAssignment, NtNetDeclAssignment,
      # Declaration ranges A.2.5
      NtRange,
      # Function declarations A.2.6
      NtFunctionDecl,
      # Task declarations A.2.7
      NtTaskDecl,
      # Generate construct A.4.2
      NtGenerateRegion, NtLoopGenerate, NtGenerateBlock,
      # Procedural blocks and assignments A.6.2
      NtContinuousAssignment, NtBlockingAssignment, NtNonblockingAssignment,
      NtProceduralContinuousAssignment, NtInitial, NtAlways,
      # Parallel and sequential blocks A.6.3
      NtParBlock, NtSeqBlock,
      # Statements A.6.4
      NtTaskEnable, NtSystemTaskEnable,
      # Timing control statements A.6.5
      NtEventControl, NtEventExpression, NtRepeat, NtWait,
      NtProceduralTimingControl, NtEventTrigger, NtDisable,
      # Conditional statements A.6.6
      NtIf,
      # Case statements A.6.7
      NtCase, NtCasez, NtCasex, NtCaseItem,
      # Looping statements A.6.8
      NtForever, NtWhile, NtFor,
      # Specify section A.7.1
      NtSpecifyBlock,
      # Concatenations A.8.1
      NtConstantConcat, NtConstantMultipleConcat,
      # Function calls A.8.2
      NtConstantFunctionCall,
      NtConstantSystemFunctionCall,
      # Expressions A.8.3
      NtConstantExpression, NtConstantMinTypMaxExpression,
      NtConstantConditionalExpression, NtConstantRangeExpression,
      # Primaries A.8.4
      NtConstantPrimary,
      # Expression left-side values A.8.5
      NtVariableLvalue,
      NtVariableLvalueConcat,
      # Operators A.8.6
      NtUnaryOperator, NtBinaryOperator,
      # Attributes A.9.1
      NtAttributeInst, NtAttributeSpec, NtAttributeName,
      # Identifiers A.9.3
      NtParameterIdentifier, NtSpecparamIdentifier, NtFunctionIdentifier,
      NtGenvarIdentifier,

   NodeTypes* = set[NodeType]


const
   IdentifierTypes =
      {NtIdentifier, NtAttributeName, NtModuleIdentifier, NtPortIdentifier,
       NtParameterIdentifier, NtSpecparamIdentifier, NtType,
       NtFunctionIdentifier, NtGenvarIdentifier, NtDirection, NtNetType,
       NtAttributeName}
   IntegerTypes =
      {NtIntLit, NtUIntLit, NtAmbIntLit, NtAmbUIntLit}

   OperatorTypes = {NtUnaryOperator, NtBinaryOperator}

type
   PNode* = ref TNode
   TNodeSeq* = seq[PNode]
   TNode = object of RootObj
      info*: TLineInfo
      case `type`*: NodeType
      of NtStrLit:
         s*: string
      of NtIntLit, NtUIntLit, NtAmbIntLit, NtAmbUIntLit:
         inumber*: BiggestInt
         iraw*: string
         base*: NumericalBase
         size*: int
      of NtRealLit:
         fnumber*: BiggestFloat
         fraw*: string
      of IdentifierTypes:
         identifier*: PIdentifier
      of NtError:
         msg*: string # TODO: Combine w/ NtStrLit?
      of OperatorTypes:
         # FIXME: Unused right now
         op*: string
      of NtWildcard:
         discard
      else:
         sons*: TNodeSeq

   TLineInfo* = object
      line*: uint16
      col*: int16


proc pretty*(n: PNode, indent: int = 0): string =
   if n == nil:
      return
   result = spaces(indent) & $n.type &
            format("($1:$2)", n.info.line, n.info.col + 1)
   case n.type
   of IdentifierTypes:
      add(result, ": " & $n.identifier.s & "\n")
   of IntegerTypes:
      add(result, format(": $1 (raw: '$2', base: $3, size: $4)\n",
                         n.inumber, n.iraw, n.base, n.size))
   of NtRealLit:
      add(result, format(": $1 (raw: '$2')\n", n.fnumber, n.fraw))
   of OperatorTypes:
      # FIXME: Unused right now
      add(result, format(": $1\n", n.op))
   of NtError:
      add(result, format(": $1\n", n.msg))
   of NtStrLit:
      add(result, format(": $1\n", n.s))
   of NtWildcard:
      add(result, "\n")
   else:
      add(result, "\n")
      var sons_str = ""
      for s in n.sons:
         add(sons_str, pretty(s, indent + 2))

      add(result, sons_str)


proc `==`*(x, y: PNode): bool =
   if is_nil(x) or is_nil(y):
      return false

   if x.info != y.info:
      return false

   if x.type != y.type:
      return false

   case x.type
   of IdentifierTypes:
      result = x.identifier.s == y.identifier.s
   of IntegerTypes:
      result = x.inumber == y.inumber and x.iraw == y.iraw and
               x.base == y.base and x.size == y.size
   of NtRealLit:
      result = x.fnumber == y.fnumber
   of OperatorTypes:
      # FIXME: Unused right now
      result = x.op == y.op
   of NtStrLit:
      result = x.s == y.s
   of NtError, NtWildcard:
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

   if x.info != y.info:
      echo "Line info differs:\n", pretty(x, indent), pretty(y, indent)
      return

   if x.type != y.type:
      echo "Type differs:\n", pretty(x, indent), pretty(y, indent)
      return

   case x.type
   of IdentifierTypes, IntegerTypes, NtRealLit, OperatorTypes, NtError,
      NtStrLit, NtWildcard:
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


proc new_line_info*(line: uint16, col: int16): TLineInfo =
   result.line = line
   result.col = col


proc new_node*(`type`: NodeType, info: TLineInfo): PNode =
   result = PNode(`type`: type, info: info)


proc new_node*(`type`: NodeType, info: TLineInfo, sons: seq[PNode]): PNode =
   result = new_node(`type`, info)
   result.sons = sons


proc new_identifier_node*(`type`: NodeType, info: TLineInfo,
                          identifier: PIdentifier): PNode =
   result = new_node(`type`, info)
   result.identifier = identifier


proc new_inumber_node*(`type`: NodeType, info: TLineInfo, inumber: BiggestInt,
                       raw: string, base: NumericalBase, size: int): PNode =
   result = new_node(`type`, info)
   result.inumber = inumber
   result.iraw = raw
   result.base = base
   result.size = size


proc new_fnumber_node*(`type`: NodeType, info: TLineInfo, fnumber: BiggestFloat,
                       raw: string): PNode =
   result = new_node(`type`, info)
   result.fnumber = fnumber
   result.fraw = raw


proc new_str_lit_node*(info: TLineInfo, s: string): PNode =
   result = new_node(NtStrLit, info)
   result.s = s


proc new_error_node*(info: TLineInfo, msg: string,
                     args: varargs[string, `$`]): PNode =
   result = new_node(NtError, info)
   result.msg = format(msg, args)
