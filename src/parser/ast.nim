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
      NtModuleDecl, #
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

   PNode* = ref TNode
   TNodeSeq* = seq[PNode]
   TNode = object of RootObj
      info: TLineInfo
      case `type`*: NodeType
      of NtAttributeName, NtPortIdentifier:
         identifier*: PIdentifier
      else:
         sons*: TNodeSeq

   TLineInfo* = object
      line*: uint16
      col*: int16


proc pretty*(x: PNode, indent: int = 0): string =
   result = spaces(indent) & $x.type & "\n"
   var sons_str = ""
   for s in x.sons:
      add(sons_str, pretty(s, indent + 2))

   add(result, sons_str)


proc new_node*(`type`: NodeType, info: TLineInfo): PNode =
   new(result)
   result.type = `type`
   result.info = info
