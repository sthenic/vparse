# Abstract syntax tree and symbol table
import ../lexer/identifier

type
   NodeType* = enum
      NtInvalid, # An invalid node, indicates an error
               # Atoms:
      NtEmpty, # An empty node
      NtIdentifier, # The node is an identifier
      NtSymbol, # the node is a symbol
      NtStrLit, # the node is a string literal
      NtIntLit, # the node is an integer literal
      NtUIntLit, # the node is an unsigned integer literal
      NtAmbIntLit, # the node is an integer literal
      NtAmbUIntLit, # the node is an unsigned integer literal
      NtRealLit, # the node is a real value
                 # end of atoms
      # Attributes A.9.1
      NtAttributeInst,
      NtAttributeSpec,
      NtAttributeName,
      NtModuleDecl, # a module declaration A.1.3
      NtModuleParameterPortList, # A.1.4
      NtListOfPorts,
      NtPort, # a port
      NtPortExpr, # holds one or more port references
      NtPortRef, # a port reference
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

   PNode* = ref TNode
   TNodeSeq* = seq[PNode]
   TNode = object of RootObj
      case `type`*: NodeType
      of NtAttributeName, NtPortIdentifier:
         identifier*: PIdentifier
      else:
         sons*: TNodeSeq

