# Abstract syntax tree and symbol table
import strutils

import ../lexer/identifier


type
   NodeType* = enum
      NtInvalid, # An invalid node, indicates an error
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
      NtConstantExpr, # a constant expression
      NtRangeExpr, # a range expression
      # Parameter declarations A.2.1.1
      NtLocalparamDecl,
      NtParameterDecl,
      NtSpecparamDecl,
      # Port declarations A.2.1.2
      NtInoutDecl,
      NtInputDecl,
      NtOutputDecl,
      # Type declarations A.2.1.3
      NtEventDecl,
      NtGenvarDecl,
      NtIntegerDecl,
      NtNetDecl,
      NtRealDecl,
      NtRealtimeDecl,
      NtRegDecl,
      NtTimeDecl,
      # Net and variable types A.2.2.1
      # Attributes A.9.1
      NtAttributeInst,
      NtAttributeSpec,
      NtAttributeName,

   NodeTypes* = set[NodeType]

const
   IdentifierTypes: NodeTypes =
      {NtAttributeName, NtModuleIdentifier, NtPortIdentifier}

type
   PNode* = ref TNode
   TNodeSeq* = seq[PNode]
   TNode = object of RootObj
      info: TLineInfo
      case `type`*: NodeType
      of IdentifierTypes:
         identifier*: PIdentifier
      else:
         sons*: TNodeSeq

   TLineInfo* = object
      line*: uint16
      col*: int16


proc pretty*(n: PNode, indent: int = 0): string =
   result = spaces(indent) & $n.type &
            format("($1:$2)", n.info.line + 1, n.info.col + 1)
   case n.type
   of IdentifierTypes:
      add(result, ": " & $n.identifier.s & "\n")
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
