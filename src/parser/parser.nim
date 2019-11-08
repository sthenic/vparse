import streams

import ../lexer/lexer
import ../lexer/identifier
import ../utils/log

import ./ast


type
   Parser* = object
      lex: Lexer
      tok: Token


proc open_parser*(p: var Parser, cache: IdentifierCache, filename:
                  string, s: Stream) =
   init(p.tok)
   open_lexer(p.lex, cache, filename, s)


proc close_parser*(p: var Parser) =
   close_lexer(p.lex)


proc get_token*(p: var Parser) =
   get_token(p.lex, p.tok)


proc error(p: Parser, msg: string, args: varargs[string, `$`]) =
   log.error($p.tok.line & ":" & $p.tok.col & " " & msg, args)


proc new_line_info(p: Parser): TLineInfo =
   if p.tok.line < int(high(uint16)):
      result.line = uint16(p.tok.line)
   else:
      result.line = high(uint16)

   if p.tok.col < int(high(int16)):
      result.col = int16(p.tok.col)
   else:
      result.col = -1


proc new_node(`type`: NodeType, p: Parser): PNode =
   result = new_node(`type`, new_line_info(p))


proc parse_attribute_instance(p: var Parser): PNode =
   result = new_node(NtAttributeInst, p)
   # FIXME: Properly handle this, don't just eat past it.
   while p.tok.type notin {TkRparenStar, TkEndOfFile}:
      get_token(p)

   if p.tok.type == TkRparenStar:
      get_token(p)


proc parse_module_declaration(p: var Parser, attributes: seq[PNode]): PNode =
   result = new_node(NtModuleDecl, p)
   if len(attributes) > 0:
      add(result.sons, attributes)

   # FIXME: Properly handle this, don't just eat past it.
   while p.tok.type notin {TkEndmodule, TkEndOfFile}:
      get_token(p)

   if p.tok.type == TkEndmodule:
      get_token(p)


proc assume_source_text(p: var Parser): PNode =
   # Parse source text (A.1.3)
   # Check for attribute instances.
   var attributes: seq[PNode]
   while p.tok.type == TkLparenStar:
      add(attributes, parse_attribute_instance(p))

   case p.tok.type
   of TkModule, TkMacromodule:
      result = parse_module_declaration(p, attributes)
   of TkPrimitive:
      error(p, "Unsupported token '$1'.", p.tok)
      result = new_node(NtEmpty, p)
      get_token(p)
   else:
      error(p, "Unexpected token '$1'.", p.tok)
      result = new_node(NtEmpty, p)
      get_token(p)


proc parse_all*(p: var Parser): PNode =
   result = new_node(NtSourceText, p) # FIXME: Proper init value

   get_token(p)
   while p.tok.type != TkEndOfFile:
      let n = assume_source_text(p)
      # echo "Got node ", n
      if n.type != NtEmpty:
         add(result.sons, n)


proc parse_string*(s: string, cache: IdentifierCache,
                   filename: string = ""):  PNode =
   var p: Parser
   var ss = new_string_stream(s)
   open_parser(p, cache, filename, ss)
   result = parse_all(p)
   close_parser(p)

