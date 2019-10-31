import lexbase
import streams
import strutils

import ./identifier

type
   TokenType* = enum
      TkInvalid, TkEndOfFile,
      TkLiteral, TkComment,
      TkSymbol, # begin keywords:
      TkAlways, TkAnd, TkAssign, TkAutomatic,
      TkBegin, TkBuf, TkBufif0, TkBufif1,
      TkCase, TkCasex, TkCasez, TkCell, TkCmos, TkConfig,
      TkDeassign TkDefault, TkDefparam, TkDesign, TkDisable,
      TkEdge, TkEdge0, TkEdge01, TkEdge1, TkEdge10, TkEdgeX TkEdgeZ, TkElse,
      TkEnd, TkEndcase, TkEndconfig, TkEndfunction, TkEndgenerate, TkEndmodule
      TkEndprimitive, TkEndspecify, TkEndtable, TkEndtask, TkEvent,
      TkFor, TkForce, TkForever, TkFork, TkFunction,
      TkGenerate, TkGenvar,
      TkHighz0, TkHighz1,
      TkIf, TkIfnone, TkIncdir, TkInclude, TkInitial, TkInout, TkInput,
      TkInstance, TkInteger,
      TkJoin,
      TkLarge, TkLiblist, TkLibrary, TkLocalparam,
      TkMacromodule, TkMedium, TkModule,
      TkNand, TkNegedge, TkNmos, TkNor, TkNoshowCancelled,
      TkNot, TkNotif0, TkNotif1,
      TkOperator, TkOr, TkOutput,
      TkParameter, TkPathpulse, TkPmos, TkPosedge, TkPrimitive, TkPull0,
      TkPull1, TkPulldown, TkPullup, TkPulsestyleOndetect, TkPulsestyleOnevent,
      TkRcmos, TkReal, TkRealtime, TkReg TkRelease, TkRepeat, TkRnmos, TkRpmos,
      TkRtran, TkRtranif0, TkRtranif1,
      TkScalared, TkShowCancelled, TkSigned, TkSmall, TkSpecify, TkSpecparam,
      TkStrong0, TkStrong1, TkSupply0, TkSupply1,
      TkTable, TkTask, TkTime, TkTran, TkTranif0, TkTranif1, TkTri,
      TkTri0, TkTri1, TkTriand, TkTrior, TkTrireg,
      TkUse
      TkVectored,
      TkWait, TkWand, TkWeak0, TkWeak1, TkWhile, TkWire, TkWor,
      TkXnor, TkXor, # end keywords
      TkComma, TkDot, TkSemicolon,
      TkHash, TkStar, TkForwardSlash,
      TkLparen, TkRparen, TkEquals,
      TkTick,
      TkDollarFullSkew,
      TkDollarHold, TkDollarNochange, TkDollarPeriod, TkDollarRecovery,
      TkDollarRecrem, TkDollarRemoval, TkDollarSetup, TkDollarSetupHold,
      TkDollarSkew, TkDollarTimeSkew, TkDollarWidth

   NumericalBase* = enum
      Base10, Base2, Base8, Base16

   TokenTypes* = set[TokenType]

   Token* = object
      `type`*: TokenType
      ident*: PIdentifier # Identifier
      literal*: string # String literal, also comments
      inumber*: BiggestInt # Integer literal
      fnumber*: BiggestFloat # Floating point literal
      base*: NumericalBase # The numerical base
      line*, col*: int

   Lexer* = object of BaseLexer
      filename*: string
      cache*: IdentifierCache

   LexerError = object of Exception


const
   NumChars*: set[char] = {'0'..'9', 'a'..'f', 'A'..'F', 'x', 'X', 'z', 'Z', '?'}
   SymChars*: set[char] = {'0'..'9', 'a'..'z', 'A'..'Z', '_'}
   SymStartChars*: set[char] = {'a'..'z', 'A'..'Z', '_'}
   OpChars*: set[char] = {'+', '-', '!', '~', '&', '|', '^', '*', '/', '%', '=',
                          '<', '>'}
   SpaceChars*: set[char] = {' ', '\t'}

   SpecialWords = ["",
      "always", "and", "assign", "automatic",
      "begin", "buf", "bufif0", "bufif1",
      "case", "casex", "casez", "cell", "cmos", "config",
      "deassign", "default", "defparam", "design", "disable",
      "edge", "edge0", "edge01", "edge1", "edge10", "edgex", "edgez", "else",
      "end", "endcase", "endconfig", "endfunction", "endgenerate", "endmodule",
      "endprimitive", "endspecify", "endtable", "endtask", "event",
      "for", "force", "forever", "fork", "function",
      "generate", "genvar",
      "highz0", "highz1",
      "if", "ifnone", "incdir", "include", "initial", "inout", "input",
      "instance", "integer",
      "join",
      "large", "liblist", "library", "localparam",
      "macromodule", "medium", "module",
      "nand", "negedge", "nmos", "nor", "noshowcancelled",
      "not", "notif0", "notif1",
      "operator", "or", "output",
      "parameter", "pathpulse", "pmos", "posedge", "primitive", "pull0",
      "pull1", "pulldown", "pullup", "pulsestyleondetect", "pulsestyleonevent",
      "rcmos", "real", "realtime", "reg", "release", "repeat", "rnmos", "rpmos",
      "rtran", "rtranif0", "rtranif1",
      "scalared", "showcancelled", "signed", "small", "specify", "specparam",
      "strong0", "strong1", "supply0", "supply1",
      "table", "task", "time", "tran", "tranif0", "tranif1", "tri",
      "tri0", "tri1", "triand", "trior", "trireg",
      "use",
      "vectored",
      "wait", "wand", "weak0", "weak1", "while", "wire", "wor",
      "xnor", "xor"
   ]

   TokenTypeToStr*: array[TokenType, string] = [
      "Invalid", "[EOF]", "Literal", "Comment", "Symbol",
      "always", "and", "assign", "automatic",
      "begin", "buf", "bufif0", "bufif1",
      "case", "casex", "casez", "cell", "cmos", "config",
      "deassign", "default", "defparam", "design", "disable",
      "edge", "edge0", "edge01", "edge1", "edge10", "edgex", "edgez", "else",
      "end", "endcase", "endconfig", "endfunction", "endgenerate", "endmodule",
      "endprimitive", "endspecify", "endtable", "endtask", "event",
      "for", "force", "forever", "fork", "function",
      "generate", "genvar",
      "highz0", "highz1",
      "if", "ifnone", "incdir", "include", "initial", "inout", "input",
      "instance", "integer",
      "join",
      "large", "liblist", "library", "localparam",
      "macromodule", "medium", "module",
      "nand", "negedge", "nmos", "nor", "noshowcancelled",
      "not", "notif0", "notif1",
      "operator", "or", "output",
      "parameter", "pathpulse", "pmos", "posedge", "primitive", "pull0",
      "pull1", "pulldown", "pullup", "pulsestyleondetect", "pulsestyleonevent",
      "rcmos", "real", "realtime", "reg", "release", "repeat", "rnmos", "rpmos",
      "rtran", "rtranif0", "rtranif1",
      "scalared", "showcancelled", "signed", "small", "specify", "specparam",
      "strong0", "strong1", "supply0", "supply1",
      "table", "task", "time", "tran", "tranif0", "tranif1", "tri",
      "tri0", "tri1", "triand", "trior", "trireg",
      "use",
      "vectored",
      "wait", "wand", "weak0", "weak1", "while", "wire", "wor",
      "xnor", "xor",
      ",", ".", ";", "#", "*", "/", "(", ")", "=", "`",
      "$fullskew", "$hold", "$nochange", "$period", "$recovery", "$recrem",
      "$removal", "$setup", "$setuphold", "$skew", "$timeskew", "$width"
   ]


proc new_lexer_error(msg: string, args: varargs[string, `$`]): ref LexerError =
   new(result)
   result.msg = format(msg, args)


proc init*(t: var Token) =
   t.type = TkInvalid
   t.ident = nil
   set_len(t.literal, 0)
   t.inumber = 0
   t.fnumber = 0.0
   t.base = Base10
   t.line = 0
   t.col = 0


proc is_valid*(t: Token): bool =
   return t.type != TkInvalid


proc handle_crlf(l: var Lexer, pos: int): int =
   # Refill buffer at end-of-line characters.
   case l.buf[pos]
   of '\c':
      result = lexbase.handle_cr(l, pos)
   of '\L':
      result = lexbase.handle_lf(l, pos)
   else:
      result = pos


template update_token_position(l: Lexer, tok: var Token) =
   # FIXME: This is wrong when pos is something other than l.bufpos.
   tok.col = get_col_number(l, l.bufpos)
   tok.line = l.lineNumber


proc find_str(a: openarray[string], s: string): int =
   for i in low(a) .. high(a):
      if cmp(a[i], s) == 0:
         return i
   result = -1


proc get_symbol(l: var Lexer, tok: var Token) =
   discard


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
   tok.type = TkComment
   case l.buf[pos]
   of '/':
      # Grab everything until the end of the line.
      inc(pos)
      pos = skip(l, pos)
      update_token_position(l, tok)

      while l.buf[pos] notin lexbase.NewLines + {lexbase.EndOfFile}:
         add(tok.literal, l.buf[pos])
         inc(pos)
      pos = handle_crlf(l, pos)
   of '*':
      # Grab everything until '*/' is encountered, refilling the buffer
      # as we go.
      inc(pos)
      pos = skip(l, pos)
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
      tok.type = TkInvalid
      echo "Invalid token: '", l.buf[pos], "', this should not happen."
      inc(pos)

   l.bufpos = pos


proc handle_forward_slash(l: var Lexer, tok: var Token) =
   # Either we're dealing with the binary operator or a comment.
   if l.buf[l.bufpos + 1] in {'/', '*'}:
      handle_comment(l, tok)
   else:
      # FIXME: Initialize the ident field
      tok.type = TkOperator
      inc(l.bufpos)


proc handle_dollar(l: var Lexer, tok: var Token) =
   tok.type = TkDollarHold
   inc(l.bufpos)


proc handle_literal(l: var Lexer, tok: var Token) =
   tok.type = TkLiteral
   inc(l.bufpos)


proc handle_number(l: var Lexer, tok: var Token) =
   tok.type = TkInteger
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
      tok.type = TkEndOfFile
   of lexbase.NewLines:
      l.bufpos = handle_crlf(l, l.bufpos)
      # TODO: Risk of stack overflow?
      get_token(l, tok)
   of SymStartChars:
      get_symbol(l, tok)
   of ',':
      tok.type = TkComma
      inc(l.bufpos)
   of '.':
      tok.type = TkDot
      inc(l.bufpos)
   of ';':
      tok.type = TkSemicolon
      inc(l.bufpos)
   of '#':
      tok.type = TkSemicolon
      inc(l.bufpos)
   of '*':
      tok.type = TkStar
      inc(l.bufpos)
   of '/':
      handle_forward_slash(l, tok)
   of '(':
      tok.type = TkLparen
      inc(l.bufpos)
   of ')':
      tok.type = TkRparen
      inc(l.bufpos)
   of '=':
      tok.type = TkEquals
      inc(l.bufpos)
   of '`':
      tok.type = TkTick
      inc(l.bufpos)
   of '$':
      handle_dollar(l, tok)
   of '"':
      handle_literal(l, tok)
   of '\'', '0' .. '9':
      handle_number(l, tok)
   else:
      echo "Invalid token: '", c, "'"
      tok.type = TkInvalid
      inc(l.bufpos)


proc open_lexer*(l: var Lexer, filename: string, s: Stream) =
   lexbase.open(l, s)
   l.filename = filename


proc close_lexer*(l: var Lexer) =
   lexbase.close(l)
