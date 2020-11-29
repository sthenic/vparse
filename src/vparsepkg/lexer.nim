import lexbase
import streams
import strutils
import hashes
import macros

import ./identifier
import ./location
export identifier
export location

type
   TokenKind* = enum
      TkInvalid, # begin keywords:
      TkAcceptOn, TkAlias, TkAlways, TkAlwaysComb, TkAlwaysFf, TkAlwaysLatch, TkAnd, TkAssert,
      TkAssign, TkAssume, TkAutomatic,
      TkBefore, TkBegin, TkBind, TkBins, TkBinsof, TkBit, TkBreak, TkBuf, TkBufif0,
      TkBufif1, TkByte,
      TkCase, TkCasex, TkCasez, TkCell, TkChandle, TkChecker, TkClass, TkClocking, TkCmos,
      TkConfig, TkConst, TkConstraint, TkContext, TkContinue, TkCover, TkCovergroup,
      TkCoverpoint, TkCross,
      TkDeassign TkDefault, TkDefparam, TkDesign, TkDisable, TkDist, TkDo,
      TkEdge, TkElse, TkEnd, TkEndcase, TkEndcheker, TkEndclass, TkEndclocking, TkEndconfig,
      TkEndfunction, TkEndgenerate, TkEndgroup, TkEndinterface, TkEndmodule, TkEndpackage,
      TkEndprimitive, TkEndprogram, TkEndproperty, TkEndspecify, TkEndsequence, TkEndtable,
      TkEndtask, TkEnum, TkEvent, TkEventually, TkExpect, TkExport, TkExtends, TkExtern,
      TkFinal, TkFirstMatch, TkFor, TkForce, TkForeach, TkForever, TkFork, TkForkjoin,
      TkFunction,
      TkGenerate, TkGenvar, TkGlobal,
      TkHighz0, TkHighz1,
      TkIf, TkIff, TkIfnone, TkIgnoreBins, TkIllegalBins, TkImplements, TkImplies, TkImport,
      TkIncdir, TkInclude, TkInitial, TkInout, TkInput, TkInside, TkInstance, TkInt, TkInteger,
      TkInterconnect, TkInterface, TkIntersect,
      TkJoin, TkJoinAny, TkJoinNone,
      TkLarge, TkLet, TkLiblist, TkLibrary, TkLocal, TkLocalparam, TkLogic, TkLongint,
      TkMacromodule, TkMatches, TkMedium, TkModport, TkModule,
      TkNand, TkNegedge, TkNettype, TkNew, TkNexttime, TkNmos, TkNor, TkNoshowCancelled,
      TkNot, TkNotif0, TkNotif1, TkNull,
      TkOr, TkOutput,
      TkPackage, TkPacked, TkParameter, TkPmos, TkPosedge, TkPrimitive, TkPriority, TkProgram,
      TkProperty, TkProtected, TkPull0, TkPull1, TkPulldown, TkPullup, TkPulsestyleOndetect,
      TkPulsestyleOnevent, TkPure,
      TkRand, TkRandc, TkRandcase, TkRandsequence, TkRcmos, TkReal, TkRealtime, TkRef, TkReg,
      TkRejectOn, TkRelease, TkRepeat, TkRestrict, TkReturn, TkRnmos, TkRpmos, TkRtran,
      TkRtranif0, TkRtranif1,
      TkSAlways, TkSEventually, TkSNexttime, TkSUntil, TkSUntilWidth, TkScalared,
      TkSequence, TkShortint, TkShortreal, TkShowCancelled, TkSigned, TkSmall, TkSoft,
      TkSolve, TkSpecify, TkSpecparam, TkStatic, TkString, TkStrong, TkStrong0, TkStrong1,
      TkStruct, TkSuper, TkSupply0, TkSupply1, TkSyncAcceptOn, TkSyncRejectOn,
      TkTable, TkTagged, TkTask, TkThis, TkThroughput, TkTime, TkTimeprecision, TkTimeunit,
      TkTran, TkTranif0, TkTranif1, TkTri, TkTri0, TkTri1, TkTriand, TkTrior, TkTrireg,
      TkType, TkTypedef,
      TkUnion, TkUnique, TkUnique0, TkUnsigned, TkUntil, TkUntilWidth, TkUntyped, TkUse, TkUwire,
      TkVar, TkVectored, TkVirtual, TkVoid,
      TkWait, TkWaitOrder, TkWand, TkWeak, TkWeak0, TkWeak1, TkWhile, TkWildcard,
      TkWire, TkWidth, TkWithin, TkWor,
      TkXnor, TkXor, # end keywords, begin special characters:
      TkBackslash, TkComma, TkDot, TkQuestionMark, TkSemicolon, TkColon, TkAt,
      TkHash, TkLparen, TkRparen, TkLbracket, TkRbracket, TkLbrace, TkRbrace,
      TkLparenStar, TkRparenStar, TkPlusColon, TkMinusColon, TkRightArrow,
      TkEquals, # end special characters
      TkSymbol, TkOperator, TkStrLit,
      TkIntLit, TkUIntLit,
      TkAmbIntLit, TkAmbUIntLit, # Ambiguous literals
      TkRealLit, TkAmbRealLit,
      TkDirective, TkDollar, TkComment, TkBlockComment, TkError, TkEndOfFile

   NumericalBase* = enum
      Base10, Base2, Base8, Base16

   TokenKinds* = set[TokenKind]

   Token* = object
      kind*: TokenKind
      identifier*: PIdentifier # Identifier
      literal*: string # String literal, also comments
      fnumber*: BiggestFloat # Floating point literal
      base*: NumericalBase # The numerical base
      size*: int # The size field of number
      loc*: Location

   Lexer* = object of BaseLexer
      filename*: string
      cache*: IdentifierCache
      file*: int


const
   DecimalChars*: set[char] = {'0'..'9'}
   ZChars*: set[char] = {'z', 'Z', '?'}
   XChars*: set[char] = {'x', 'X'}
   BinaryChars*: set[char] = {'0', '1'}
   OctalChars*: set[char] = {'0'..'7'}
   HexChars*: set[char] = {'0'..'9', 'a'..'f', 'A'..'F'}
   SymChars*: set[char] = {'0'..'9', 'a'..'z', 'A'..'Z', '_', '$'}
   SymStartChars*: set[char] = {'a'..'z', 'A'..'Z', '_'}
   OpChars*: set[char] = {'+', '-', '!', '~', '&', '|', '^', '*', '/', '%', '=',
                          '<', '>', ':'}
   SpaceChars*: set[char] = {' ', '\t'}
   UnaryOperators* = ["+", "-", "!", "~", "&", "~&", "|", "~|", "^", "~^", "^~"]
   BinaryOperators* = ["+", "-", "*", "/", "%", "==", "!=", "===", "!==", "&&",
                       "||", "**", "<", "<=", ">", ">=", "&", "|", "^", "^~",
                       "~^", ">>", "<<", ">>>", "<<<"]
   Operators* = ["+", "-", "!", "~", "&", "~&", "|", "~|", "^", "~^", "^~", "*",
                 "/", "%", "==", "!=", "===", "!==", "&&", "||", "**", "<", "<=",
                 ">", ">=", ">>", "<<", ">>>", "<<<", "+:", "-:", "->", "=", ":"]

   SignedTokens* = {TkIntLit, TkAmbIntLit}
   UnsignedTokens* = {TkUIntLit, TkAmbUIntLit}
   RealTokens* = {TkRealLit, TkAmbRealLit}
   AmbiguousTokens* = {TkAmbIntLit, TkAmbUIntLit, TkAmbRealLit}
   IntegerTokens* = SignedTokens + UnsignedTokens
   NumberTokens* = IntegerTokens + RealTokens
   NetTypeTokens* = {TkSupply0, TkSupply1, TkTri, TkTriand, TkTrior, TkTri0,
                     TkTri1, TkWire, TkWand, TkWor}
   GateSwitchTypeTokens* = {TkCmos, TkRcmos,
                            TkBufif0, TkBufif1, TkNotif0, TkNotif1,
                            TkNmos, TkPmos, TkRnmos, TkRpmos,
                            TkAnd, TkNand, TkOr, TkNor, TkXor, TkXnor,
                            TkBuf, TkNot,
                            TkTranif0, TkTranif1,
                            TkRtranif0, TkRtranif1,
                            TkTran, TkRtran}
   DriveStrength0Tokens* = {TkSupply0, TkStrong0, TkPull0, TkWeak0}
   DriveStrength1Tokens* = {TkSupply1, TkStrong1, TkPull1, TkWeak1}
   DriveStrengthTokens* = DriveStrength0Tokens + DriveStrength1Tokens + {TkHighz0, TkHighz1}
   ChargeStrengthTokens* = {TkSmall, TkMedium, TkLarge}
   DeclarationTokens* = {TkReg, TkInteger, TkTime, TkReal, TkRealtime, TkEvent,
                         TkLocalparam, TkParameter}
   StatementTokens* = {TkCase, TkCasex, TkCasez, TkIf, TkDisable, TkRightArrow,
                       TkForever, TkRepeat, TkWhile, TkFor, TkFork, TkBegin,
                       TkAssign, TkDeassign, TkForce, TkRelease, TkHash,
                       TkAt, TkDollar, TkWait, TkSymbol, TkLbrace}
   PrimaryTokens* = NumberTokens + {TkSymbol, TkLbrace, TkLparen, TkStrLit, TkOperator}
   ExpressionTokens* = PrimaryTokens

   TokenKindToStr*: array[TokenKind, string] = [
      "Invalid",
      "accept_on", "alias", "always", "always_comb", "always_ff", "always_latch", "and", "assert",
      "assign", "assume", "automatic",
      "before", "begin", "bind", "bins", "binsof", "bit", "break", "buf", "bufif0",
      "bufif1", "byte",
      "case", "casex", "casez", "cell", "chandle", "checker", "class", "clocking", "cmos",
      "config", "const", "constraint", "context", "continue", "cover", "covergroup",
      "coverpoint", "cross",
      "deassign", "default", "defparam", "design", "disable", "dist", "do",
      "edge", "else", "end", "endcase", "endchecker", "endclass", "endclocking", "endconfig",
      "endfunction", "endgenerate", "endgroup", "endinterface", "endmodule", "endpackage",
      "endprimitive", "endprogram", "endproperty", "endspecify", "endsequence", "endtable",
      "endtask", "enum", "event", "eventually", "expect", "export", "extends", "extern",
      "final", "first_match", "for", "force", "foreach", "forever", "fork", "forkjoin",
      "function",
      "generate", "genvar", "global",
      "highz0", "highz1",
      "if", "iff", "ifnone", "ignore_bins", "illegal_bins", "implements", "implies", "import",
      "incdir", "include", "initial", "inout", "input", "inside", "instance", "int", "integer",
      "interconnect", "interface", "intersect",
      "join", "join_any", "join_none",
      "large", "let", "liblist", "library", "local", "localparam", "logic", "longint",
      "macromodule", "matches", "medium", "modport", "module",
      "nand", "negedge", "nettype", "new", "nexttime", "nmos", "nor", "noshowcancelled",
      "not", "notif0", "notif1", "null",
      "or", "output",
      "package", "packed", "parameter", "pmos", "posedge", "primitive", "priority", "program",
      "property", "protected", "pull0", "pull1", "pulldown", "pullup", "pulsestyle_ondetect",
      "pulsestyle_onevent", "pure",
      "rand", "randc", "randcase", "randsequence", "rcmos", "real", "realtime", "ref", "reg",
      "reject_on", "release", "repeat", "restrict", "return", "rnmos", "rpmos", "rtran",
      "rtranif0", "rtranif1",
      "s_always", "s_eventually", "s_nexttime", "s_until", "s_until_with", "scalared",
      "sequence", "shortint", "shortreal", "showcancelled", "signed", "small", "soft",
      "solve", "specify", "specparam", "static", "string", "strong", "strong0", "strong1",
      "struct", "super", "supply0", "supply1", "sync_accept_on", "sync_reject_on",
      "table", "tagged", "task", "this", "throughout", "time", "timeprecision", "timeunit",
      "tran", "tranif0", "tranif1", "tri", "tri0", "tri1", "triand", "trior", "trireg",
      "type", "typedef",
      "union", "unique", "unique0", "unsigned", "until", "until_with", "untyped", "use", "uwire",
      "var", "vectored", "virtual", "void",
      "wait", "wait_order", "wand", "weak", "weak0", "weak1", "while", "wildcard",
      "wire", "with", "within", "wor",
      "xnor", "xor",
      "\\", ",", ".", "?", ";", ":", "@", "#", "(", ")", "[", "]", "{", "}",
      "(*", "*)", "+:", "-:", "->", "=",
      "Symbol", "Operator", "StrLit",
      "IntLit", "UIntLit",
      "AmbIntLit", "AmbUIntLit",
      "RealLit", "AmbRealLit",
      "Directive", "Dollar", "One-line comment", "Block comment", "Error", "[EOF]"
   ]

   Directives* = [
      "begin_keywords", "celldefine", "default_nettype", "define", "else",
      "elsif", "end_keywords", "endcelldefine", "endif", "ifdef", "ifndef",
      "include", "line", "nounconnected_drive", "pragma", "resetall",
      "timescale", "unconnected_drive", "undef"
   ]


proc `$`*(kind: TokenKind): string =
   if ord(kind) < ord(TkSymbol):
      result = "'" & TokenKindToStr[kind] & "'"
   else:
      result = TokenKindToStr[kind]


proc `$`*(kinds: set[TokenKind]): string =
   var i = 0
   for kind in kinds:
      if i > 0:
         add(result, ", ")
      add(result, $kind)
      inc(i)


proc raw*(t: Token): string =
   ## Convert the token into its source code representation.
   case t.kind
   of TkSymbol, TkOperator:
      result = t.identifier.s
   of TkDirective:
      result = "`" & t.identifier.s & t.literal
   of IntegerTokens:
      result = t.literal
   of TkStrLit:
      result = '"' & t.literal & '"'
   of TkComment, TkBlockComment:
      result = t.literal
   else:
      result = TokenKindToStr[t.kind]


proc `$`*(t: Token): string =
   result = "'" & raw(t) & "'"


proc to_int*(base: NumericalBase): int =
   case base
   of Base10:
      result = 10
   of Base2:
      result = 2
   of Base8:
      result = 8
   of Base16:
      result = 16


proc pretty*(t: Token): string =
   result = format("($1:$2:$3: ", t.loc.file, t.loc.line, t.loc.col + 1)
   add(result, "kind: " & $t.kind)
   add(result, ", identifier: " & $t.identifier)
   add(result, ", literal: \"" & t.literal & "\"")
   add(result, ", fnumber: " & $t.fnumber)
   add(result, ", base: " & $t.base)
   add(result, ", size: " & $t.size)
   add(result, ")")


proc pretty*(tokens: openarray[Token]): string =
   for t in tokens:
      add(result, pretty(t) & "\n")


proc detailed_compare*(x, y: Token) =
   const INDENT = 2
   if x.kind != y.kind:
      echo format("Kind differs:\n$1\n$2\n",
                  indent(pretty(x), INDENT), indent(pretty(y), INDENT))
      return

   if x.loc.line != y.loc.line or x.loc.col != y.loc.col:
      echo format("Line info differs:\n$1\n$2\n",
                  indent(pretty(x), INDENT), indent(pretty(y), INDENT))
      return

   if x != y:
      echo format("Contents differ:\n$1\n$2\n",
                  indent(pretty(x), INDENT), indent(pretty(y), INDENT))
      return


proc detailed_compare*(x, y: openarray[Token]) =
   for i in 0..<min(len(x), len(y)):
      detailed_compare(x[i], y[i])

   if len(x) != len(y):
      echo format("Length differs: LHS($1) != RHS($2)", len(x), len(y))


proc init*(t: var Token) =
   t.kind = TkInvalid
   t.identifier = nil
   set_len(t.literal, 0)
   t.fnumber = 0.0
   t.base = Base10
   t.size = -1
   t.loc.file = 0
   t.loc.line = 0
   t.loc.col = 0


proc new_error_token*(loc: Location, msg: string, args: varargs[string, `$`]): Token =
   init(result)
   result.kind = TkError
   result.literal = format(msg, args)
   result.loc = loc


proc is_valid*(t: Token): bool =
   return t.kind != TkInvalid


proc handle_crlf(l: var Lexer, pos: int): int =
   # Refill buffer at end-of-line characters.
   case l.buf[pos]
   of '\c':
      result = lexbase.handle_cr(l, pos)
   of '\L':
      result = lexbase.handle_lf(l, pos)
   else:
      result = pos


proc get_binary_precedence*(tok: Token): int =
   ## Return the precedence of binary operators.
   case tok.kind
   of TkOperator:
      let str = tok.identifier.s
      if str == "**":
         return 12
      elif str in ["*", "/", "%"]:
         return 11
      elif str in ["+", "-"]:
         return 10
      elif str in ["<<", ">>", "<<<", ">>>"]:
         return 9
      elif str in ["<", "<=", ">", ">="]:
         return 8
      elif str in ["==", "!=", "===", "!=="]:
         return 7
      elif str == "&":
         return 6
      elif str in ["^", "^~", "~^"]:
         return 5
      elif str == "|":
         return 4
      elif str == "&&":
         return 3
      elif str == "||":
         return 2
      else:
         # This is how the expression parsing handles unary operators.
         return -10
   of TkQuestionMark:
      return 1
   else:
      # This is how the expression parsing breaks on an unrecognized character.
      return -10


template update_token_position(l: Lexer, tok: var Token) =
   # FIXME: This is wrong when pos is something other than l.bufpos.
   tok.loc = new_location(l.file, l.lineNumber, get_col_number(l, l.bufpos))


proc skip(l: var Lexer, pos: int): int =
   result = pos
   while l.buf[result] in SpaceChars and
         l.buf[result] notin lexbase.Newlines + {lexbase.EndOfFile}:
      inc(result)


proc handle_comment(l: var Lexer, tok: var Token) =
   # A comment begins w/ two characters: '//' or '/*'. We skip over the first
   # slash and use the other character to determine how we treat the buffer from
   # that point on.
   var pos = l.bufpos + 1
   case l.buf[pos]
   of '/':
      tok.kind = TkComment
      # Grab everything until the end of the line.
      inc(pos)
      update_token_position(l, tok)

      while l.buf[pos] notin lexbase.NewLines + {lexbase.EndOfFile}:
         add(tok.literal, l.buf[pos])
         inc(pos)
      pos = handle_crlf(l, pos)
      tok.literal = strip(tok.literal)
   of '*':
      # Grab everything until '*/' is encountered, refilling the buffer
      # as we go.
      tok.kind = TkBlockComment
      inc(pos)
      update_token_position(l, tok)

      while true:
         if l.buf[pos] == lexbase.EndOfFile:
            break
         elif l.buf[pos] in lexbase.NewLines:
            pos = handle_crlf(l, pos)
            add(tok.literal, "\n")
         elif l.buf[pos] == '*' and l.buf[pos + 1] == '/':
            inc(pos, 2)
            break
         else:
            add(tok.literal, l.buf[pos])
            inc(pos)

      tok.literal = strip(tok.literal)
   else:
      tok.kind = TkInvalid
      echo "Invalid token: '", l.buf[pos], "', this should not happen."
      inc(pos)

   l.bufpos = pos


proc handle_identifier(l: var Lexer, tok: var Token, char_set: set[char]) =
   var pos = l.bufpos
   var h: Hash = 0
   while true:
      let c = l.buf[pos]
      if c notin char_set:
         break
      h = h !& ord(c)
      inc(pos)
   h = !$h

   tok.identifier = get_identifier(l.cache, addr(l.buf[l.bufpos]), pos - l.bufpos, h)
   l.bufpos = pos


proc handle_symbol(l: var Lexer, tok: var Token) =
   handle_identifier(l, tok, SymChars)

   if tok.identifier.id > ord(TkInvalid) and tok.identifier.id < ord(TkBackslash):
      tok.kind = TokenKind(tok.identifier.id)
   else:
      tok.kind = TkSymbol


proc handle_operator(l: var Lexer, tok: var Token) =
   # Since Verilog is insensitive to whitespace for the most part, we might be
   # put in a position where two operators appear 'as one'. For example 'a|~b'
   # is legal Verilog and should be parsed as 'a | ~b'. Greedily eating away at
   # the character stream until a nonoperator token is encountered would result
   # in the three tokens 'a |~ b'. Thus, we have to adopt a more careful
   # strategy, selecting the largest group of consecutive operator characters
   # that constitute a legal Verilog operator. We still want to lex '<<<' as one
   # operator token and not stop at '<<' just because that's legal too. As
   # always, we have to do this in a way that leaves the buffer cursor pointing
   # at the first token after the operator we decide to remove from the buffer.
   var pos = l.bufpos
   var h: Hash = 0
   var op = new_string_of_cap(3)
   while true:
      let c = l.buf[pos]
      if c notin OpChars or op & c notin Operators:
         break
      h = h !& ord(c)
      add(op, c)
      inc(pos)
   h = !$h

   tok.identifier = get_identifier(l.cache, addr(l.buf[l.bufpos]), pos - l.bufpos, h)
   l.bufpos = pos

   if tok.identifier.id < ord(TkBackslash) or tok.identifier.id > ord(TkEquals):
      # Generic operator
      tok.kind = TkOperator
   else:
      # Operator identified by a special token id.
      tok.kind = TokenKind(tok.identifier.id)


proc handle_forward_slash(l: var Lexer, tok: var Token) =
   # Either we're dealing with the binary operator or a comment.
   if l.buf[l.bufpos + 1] in {'/', '*'}:
      handle_comment(l, tok)
   else:
      handle_operator(l, tok)


proc handle_equals(l: var Lexer, tok: var Token) =
   # Either we're dealing with an operator or the assignment token.
   if l.buf[l.bufpos + 1] == '=':
      handle_operator(l, tok)
   else:
      update_token_position(l, tok)
      tok.kind = TkEquals
      inc(l.bufpos)


proc handle_string(l: var Lexer, tok: var Token) =
   tok.kind = TkStrLit
   inc(l.bufpos)

   # Grab everything from the buffer except newlines.
   while true:
      let c = l.buf[l.bufpos]
      case c
      of lexbase.Newlines + {lexbase.EndOfFile}:
         tok.kind = TkInvalid
         set_len(tok.literal, 0)
         break
      of '"':
         # String literal ends.
         inc(l.bufpos)
         break
      else:
         add(tok.literal, c)
         inc(l.bufpos)


proc get_base(l: var Lexer, tok: var Token) =
   if l.buf[l.bufpos] == '\'':
      if l.buf[l.bufpos + 1] in {'s', 'S'}:
         # Signed designator included in the base format.
         tok.kind = TkIntLit
         inc(l.bufpos, 2)
      else:
         # Base format w/o a signed designator, assume unsigned.
         tok.kind = TkUIntLit
         inc(l.bufpos, 1)

      case l.buf[l.bufpos]
      of 'd', 'D':
         tok.base = Base10
      of 'b', 'B':
         tok.base = Base2
      of 'o', 'O':
         tok.base = Base8
      of 'h', 'H':
         tok.base = Base16
      else:
         # Unexpected character, set the token as invalid.
         tok.kind = TkInvalid
         inc(l.bufpos)
         return

      # Spaces are allowed after the base format.
      inc(l.bufpos)
      l.bufpos = skip(l, l.bufpos)

   else:
      # If there's no base format in the buffer, assume base 10 and signed
      # until we have more information.
      tok.kind = TkIntLit
      tok.base = Base10


proc set_ambiguous*(kind: var TokenKind) =
   case kind
   of TkIntLit:
      kind = TkAmbIntLit
   of TkUIntLit:
      kind = TkAmbUIntLit
   of TkRealLit:
      kind = TkAmbRealLit
   of {TkAmbIntLit, TkAmbUIntLit, TkAmbRealLit}:
      discard
   else:
      kind = TkInvalid


proc set_unsigned*(kind: var TokenKind) =
   case kind
   of TkIntLit, TkUIntLit:
      kind = TkUIntLit
   of TkAmbIntLit, TkAmbUIntLit:
      kind = TkAmbUIntLit
   else:
      kind = TkInvalid


proc set_signed*(kind: var TokenKind) =
   case kind
   of TkIntLit, TkUIntLit:
      kind = TkIntLit
   of TkAmbIntLit, TkAmbUIntLit:
      kind = TkAmbIntLit
   else:
      kind = TkInvalid


# Forward declaration
proc handle_number(l: var Lexer, tok: var Token)


template eat_char(l: var Lexer, tok: var Token) =
   add(tok.literal, l.buf[l.bufpos])
   inc(l.bufpos)


template eat_decimal_number(l: var Lexer, tok: var Token) =
   while true:
      let c = l.buf[l.bufpos]
      case c
      of DecimalChars:
         add(tok.literal, c)
      of '_':
         discard
      else:
         break
      inc(l.bufpos)


proc handle_suspected_real(l: var Lexer, tok: var Token) =
   # Assume invalid until we have more information.
   tok.kind = TkInvalid

   # Expect either '.' or {'e', 'E'}, both of which have to be followed by an
   # unsigned number.
   if l.buf[l.bufpos] == '.':
      eat_char(l, tok)

      # The next character must be a digit.
      if l.buf[l.bufpos] notin DecimalChars:
         tok.kind = TkInvalid
         return

      eat_decimal_number(l, tok)
      tok.kind = TkRealLit


   if l.buf[l.bufpos] in {'e', 'E'}:
      eat_char(l, tok)

      # The next character is either a digit or a sign character.
      let c = l.buf[l.bufpos]
      case c
      of DecimalChars:
         eat_char(l, tok)
      of {'+', '-'}:
         eat_char(l, tok)

         # The next character must be a digit.
         if l.buf[l.bufpos] notin DecimalChars:
            tok.kind = TkInvalid
            return
      else:
         tok.kind = TkInvalid
         return

      eat_decimal_number(l, tok)
      tok.kind = TkRealLit

   if tok.kind == TkRealLit:
      tok.fnumber = parse_float(tok.literal)


proc handle_real_and_decimal(l: var Lexer, tok: var Token) =
   # We're reading a base 10 number, but this may be the size field of a number
   # with another base. We also have to handle X- and Z-digits separately.
   let c = l.buf[l.bufpos]
   if c in XChars + ZChars:
      set_ambiguous(tok.kind)
      tok.literal = $to_lower_ascii(c)
      if l.buf[l.bufpos + 1] == '_':
         inc(l.bufpos, 2)
      else:
         inc(l.bufpos, 1)
      return

   while true:
      let c = l.buf[l.bufpos]
      case c
      of DecimalChars:
         add(tok.literal, c)
      of '_':
         discard
      of '.', 'e', 'E':
         handle_suspected_real(l, tok)
         return
      else:
         # First character that's not part of the number. Check if it's the
         # start of a base specifier, in which case what we've been grabbing
         # from the buffer up until now has been the size field.
         # TODO: What about a zero base? Invalid?
         if c == '\'':
            tok.size = parse_int(tok.literal)
            set_len(tok.literal, 0)
            handle_number(l, tok)
            return
         break
      inc(l.bufpos)

   if len(tok.literal) == 0:
      tok.kind = TkInvalid
      return


proc handle_binary(l: var Lexer, tok: var Token) =
   # If this proc is called, we know that we only have to handle a binary value
   # and not any size or base specifier.
   while true:
      let c = l.buf[l.bufpos]
      case c
      of BinaryChars:
         add(tok.literal, c)
      of XChars + ZChars:
         set_ambiguous(tok.kind)
         add(tok.literal, to_lower_ascii(c))
      of '_':
         discard
      else:
         break

      inc(l.bufpos)

   if len(tok.literal) == 0:
      tok.kind = TkInvalid
      return


proc handle_octal(l: var Lexer, tok: var Token) =
   # If this proc is called, we know that we only have to handle an octal value
   # and not any size or base specifier.
   while true:
      let c = l.buf[l.bufpos]
      case c
      of OctalChars:
         add(tok.literal, c)
      of '_':
         discard
      of XChars + ZChars:
         set_ambiguous(tok.kind)
         add(tok.literal, to_lower_ascii(c))
      else:
         break

      inc(l.bufpos)

   if len(tok.literal) == 0:
      tok.kind = TkInvalid
      return


proc handle_hex(l: var Lexer, tok: var Token) =
   # If this proc is called, we know that we only have to handle a hexadecimal
   # value and not any size or base specifier.
   while true:
      let c = l.buf[l.bufpos]
      case c
      of HexChars:
         add(tok.literal, c)
      of '_':
         discard
      of XChars + ZChars:
         set_ambiguous(tok.kind)
         add(tok.literal, to_lower_ascii(c))
      else:
         break

      inc(l.bufpos)

   if len(tok.literal) == 0:
      tok.kind = TkInvalid
      return


proc handle_number(l: var Lexer, tok: var Token) =
   # Attempt to read the base from the buffer.
   get_base(l, tok)
   if tok.kind == TkInvalid:
      return

   case tok.base
   of Base2:
      handle_binary(l, tok)
   of Base8:
      handle_octal(l, tok)
   of Base16:
      handle_hex(l, tok)
   of Base10:
      handle_real_and_decimal(l, tok)


proc eat_directive_line(l: var Lexer, tok: var Token) =
   var pos = l.bufpos
   while l.buf[pos] notin lexbase.Newlines + {lexbase.EndOfFile}:
      add(tok.literal, l.buf[pos])
      inc(pos)
   l.bufpos = pos


proc eat_directive_arguments(l: var Lexer, tok: var Token) =
   # We stop if either of these conditions are met:
   #   - we encounter EOF; or
   #   - we encounter a closing parenthesis and the count is zero.
   var count = 0
   while true:
      case l.buf[l.bufpos]
      of lexbase.EndOfFile:
         break
      of lexbase.NewLines:
         l.bufpos = handle_crlf(l, l.bufpos)
      of ')':
         add(tok.literal, ')')
         dec(count)
         inc(l.bufpos)
         if count == 0:
            break
      of '(':
         add(tok.literal, '(')
         inc(count)
         inc(l.bufpos)
      else:
         add(tok.literal, l.buf[l.bufpos])
         inc(l.bufpos)


proc get_token*(l: var Lexer, tok: var Token) =
   # Skip until there is a token in the buffer.
   l.bufpos = skip(l, l.bufpos)

   # Initialize the token and update the position.
   init(tok)
   update_token_position(l, tok)

   let c = l.buf[l.bufpos]
   case c
   of lexbase.EndOfFile:
      tok.kind = TkEndOfFile
   of lexbase.NewLines:
      l.bufpos = handle_crlf(l, l.bufpos)
      # TODO: Risk of stack overflow?
      get_token(l, tok)
   of SymStartChars:
      handle_symbol(l, tok)
   of '/':
      handle_forward_slash(l, tok)
   of '=':
      handle_equals(l, tok)
   of '$':
      tok.kind = TkDollar
      inc(l.bufpos)
      handle_identifier(l, tok, SymChars)
   of '"':
      handle_string(l, tok)
   of '\'', '0'..'9':
      handle_number(l, tok)
   of '\\':
      tok.kind = TkBackslash
      inc(l.bufpos)
   of ',':
      tok.kind = TkComma
      inc(l.bufpos)
   of '.':
      tok.kind = TkDot
      inc(l.bufpos)
   of '?':
      tok.kind = TkQuestionMark
      inc(l.bufpos)
   of ';':
      tok.kind = TkSemicolon
      inc(l.bufpos)
   of '@':
      tok.kind = TkAt
      inc(l.bufpos)
   of '#':
      tok.kind = TkHash
      inc(l.bufpos)
   of '(':
      if l.buf[l.bufpos + 1] == '*':
         tok.kind = TkLparenStar
         inc(l.bufpos, 2)
      else:
         tok.kind = TkLparen
         inc(l.bufpos, 1)
   of '*':
      if l.buf[l.bufpos + 1] == ')':
         tok.kind = TkRparenStar
         inc(l.bufpos, 2)
      else:
         handle_operator(l, tok)
   of ')':
      tok.kind = TkRparen
      inc(l.bufpos)
   of '[':
      tok.kind = TkLbracket
      inc(l.bufpos)
   of ']':
      tok.kind = TkRbracket
      inc(l.bufpos)
   of '{':
      tok.kind = TkLbrace
      inc(l.bufpos)
   of '}':
      tok.kind = TkRbrace
      inc(l.bufpos)
   of '`':
      inc(l.bufpos)
      tok.kind = TkDirective
      handle_identifier(l, tok, SymChars)
   else:
      if c in OpChars:
         handle_operator(l, tok)
      else:
         tok.kind = TkInvalid
         inc(l.bufpos)


proc open_lexer*(l: var Lexer, cache: IdentifierCache, s: Stream,
                 filename: string, file: int) =
   lexbase.open(l, s)
   # FIXME: The filename is unused, remove?
   l.filename = filename
   l.cache = cache
   l.file = file


proc close_lexer*(l: var Lexer) =
   lexbase.close(l)


proc get_all_tokens*(l: var Lexer): seq[Token] =
   var tok: Token
   while true:
      get_token(l, tok)
      if tok.kind == TkEndOfFile:
         break
      add(result, tok)
