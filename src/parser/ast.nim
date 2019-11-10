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
      # Modules A.1.3
      NtSourceText,
      NtModuleDecl,
      NtModuleIdentifier,
      NtModuleParameterPortList, # A.1.4
      NtListOfPorts,
      NtPort, # a port
      NtPortRef, # a port reference
      NtPortRefConcat, # a concatenation of port references with '{}'
      NtPortIdentifier, # a port identifier
      # Parameter declarations A.2.1.1
      NtLocalparamDecl, NtParameterDecl, NtSpecparamDecl,
      # Port declarations A.2.1.2
      NtInoutDecl, NtInputDecl, NtOutputDecl,
      # Type declarations A.2.1.3
      NtEventDecl, NtGenvarDecl, NtIntegerDecl, NtNetDecl, NtRealDecl,
      NtRealtimeDecl, NtRegDecl, NtTimeDecl,
      # Declaration assignments A.2.4
      NtParamAssignment,
      # Declaration ranges A.2.5
      NtRange,
      # Net and variable types A.2.2.1
      # Concatenations A.8.1
      NtConstantConcat, NtConstantMultipleConcat,
      # Function calls A.8.2
      NtConstantFunctionCall,
      # Expressions A.8.3
      NtConstantExpression, NtConstantMinTypMaxExpression,
      # Primaries A.8.4
      NtConstantPrimary,
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
       NtFunctionIdentifier, NtGenvarIdentifier}
   IntegerTypes =
      {NtIntLit, NtUIntLit, NtAmbIntLit, NtAmbUIntLit}


type
   PNode* = ref TNode
   TNodeSeq* = seq[PNode]
   TNode = object of RootObj
      info: TLineInfo
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
         msg*: string
      else:
         sons*: TNodeSeq

   TLineInfo* = object
      line*: uint16
      col*: int16


proc pretty*(n: PNode, indent: int = 0): string =
   if n == nil:
      return
   result = spaces(indent) & $n.type &
            format("($1:$2)", n.info.line + 1, n.info.col + 1)
   case n.type
   of IdentifierTypes:
      add(result, ": " & $n.identifier.s & "\n")
   of IntegerTypes:
      add(result, format(": $1 (raw: '$2', base: $3, size: $4)\n",
                         n.inumber, n.iraw, n.base, n.size))
   of NtRealLit:
      add(result, format(": $1 (raw: '$2')\n", n.fnumber, n.fraw))
   of NtError:
      add(result, format(": $1\n", n.msg))
   else:
      add(result, "\n")
      var sons_str = ""
      for s in n.sons:
         add(sons_str, pretty(s, indent + 2))

      add(result, sons_str)


proc new_node*(`type`: NodeType, info: TLineInfo): PNode =
   result = PNode(`type`: type, info: info)


proc new_identifier_node*(`type`: NodeType, identifier: PIdentifier,
                          info: TLineInfo): PNode =
   result = new_node(`type`, info)
   result.identifier = identifier


proc new_inumber_node*(`type`: NodeType, inumber: BiggestInt, raw: string,
                       base: NumericalBase, size: int, info: TLineInfo): PNode =
   result = new_node(`type`, info)
   result.inumber = inumber
   result.iraw = raw
   result.base = base
   result.size = size


proc new_fnumber_node*(`type`: NodeType, fnumber: BiggestFloat, raw: string,
                       info: TLineInfo): PNode =
   result = new_node(`type`, info)
   result.fnumber = fnumber
   result.fraw = raw


proc new_error_node*(info: TLineInfo, msg: string,
                     args: varargs[string, `$`]): PNode =
   result = new_node(NtError, info)
   result.msg = format(msg, args)
