import lexbase
import streams
import strutils
import hashes

import ./identifier

type
   TokenType* = enum
      TkInvalid, # begin keywords:
      TkAlways, TkAnd, TkAssign, TkAutomatic,
      TkBegin, TkBuf, TkBufif0, TkBufif1,
      TkCase, TkCasex, TkCasez, TkCell, TkCmos, TkConfig,
      TkDeassign TkDefault, TkDefparam, TkDesign, TkDisable,
      TkEdge, TkElse,
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
      TkOr, TkOutput,
      TkParameter, TkPmos, TkPosedge, TkPrimitive, TkPull0,
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
      TkXnor, TkXor, # end keywords, begin special characters:
      TkComma, TkDot, TkSemicolon,
      TkHash, TkLparen, TkRparen, TkEquals,
      TkTick, # end special characters, begin dollars:
      TkDollarFullSkew, TkDollarHold, TkDollarNochange, TkDollarPeriod,
      TkDollarRecovery, TkDollarRecrem, TkDollarRemoval, TkDollarSetup,
      TkDollarSetupHold, TkDollarSkew, TkDollarTimeSkew, TkDollarWidth, # end dollars
      TkSymbol, TkOperator, TkStrLit,
      TkDecLit, TkOctLit, TkBinLit, TkHexLit, TkRealLit,
      TkComment, TkEndOfFile

   NumericalBase* = enum
      Base10, Base2, Base8, Base16

   TokenTypes* = set[TokenType]

   Token* = object
      `type`*: TokenType
      identifier*: PIdentifier # Identifier
      literal*: string # String literal, also comments
      inumber*: BiggestInt # Integer literal
      fnumber*: BiggestFloat # Floating point literal
      base*: NumericalBase # The numerical base
      size*: int # The size field of number
      line*, col*: int

   Lexer* = object of BaseLexer
      filename*: string
      cache*: IdentifierCache

   LexerError = object of Exception


const
   DecimalChars*: set[char] = {'0'..'9'}
   ZChars*: set[char] = {'z', 'Z', '?'}
   XChars*: set[char] = {'x', 'X'}
   BinaryChars*: set[char] = {'0', '1'} + ZChars + XChars
   OctalChars*: set[char] = {'0'..'7'} + ZChars + XChars
   HexChars*: set[char] = {'0'..'9', 'a'..'f', 'A'..'F'} + ZChars + XChars
   SymChars*: set[char] = {'0'..'9', 'a'..'z', 'A'..'Z', '_'}
   SymStartChars*: set[char] = {'a'..'z', 'A'..'Z', '_'}
   OpChars*: set[char] = {'+', '-', '!', '~', '&', '|', '^', '*', '/', '%', '=',
                          '<', '>'}
   SpaceChars*: set[char] = {' ', '\t'}

   TokenTypeToStr*: array[TokenType, string] = [
      "Invalid",
      "always", "and", "assign", "automatic",
      "begin", "buf", "bufif0", "bufif1",
      "case", "casex", "casez", "cell", "cmos", "config",
      "deassign", "default", "defparam", "design", "disable",
      "edge", "else",
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
      "or", "output",
      "parameter", "pmos", "posedge", "primitive", "pull0",
      "pull1", "pulldown", "pullup", "pulsestyle_ondetect", "pulsestyle_onevent",
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
      ",", ".", ";", "#", "(", ")", "=", "`",
      "$fullskew", "$hold", "$nochange", "$period", "$recovery", "$recrem",
      "$removal", "$setup", "$setuphold", "$skew", "$timeskew", "$width",
      "TkSymbol", "TkOperator", "TkStrLit",
      "TkDecLit", "TkOctLit", "TkBinLit", "TkHexLit", "TkRealLit",
      "TkComment", "[EOF]"
   ]


proc new_lexer_error(msg: string, args: varargs[string, `$`]): ref LexerError =
   new(result)
   result.msg = format(msg, args)


proc init*(t: var Token) =
   t.type = TkInvalid
   t.identifier = nil
   set_len(t.literal, 0)
   t.inumber = 0
   t.fnumber = 0.0
   t.base = Base10
   t.size = 0
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


proc handle_operator(l: var Lexer, tok: var Token) =
   var pos = l.bufpos
   var h: Hash = 0
   while true:
      let c = l.buf[pos]
      if c notin OpChars:
         break
      h = h !& ord(c)
      inc(pos)
   h = !$h

   update_token_position(l, tok)
   tok.identifier =
      get_identifier(l.cache, addr(l.buf[l.bufpos]), pos - l.bufpos, h)

   if tok.identifier.id < ord(TkComma) or tok.identifier.id > ord(TkTick):
      # Generic operator
      tok.type = TkOperator
   else:
      # Operator identified by a special token id.
      tok.type = TokenType(tok.identifier.id)
   l.bufpos = pos


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
      tok.type = TkEquals
      inc(l.bufpos)


proc handle_dollar(l: var Lexer, tok: var Token) =
   tok.type = TkDollarHold
   inc(l.bufpos)


proc handle_literal(l: var Lexer, tok: var Token) =
   tok.type = TkStrLit
   inc(l.bufpos)


proc get_base(l: var Lexer, tok: var Token) =
   if l.buf[l.bufpos] == '\'':
      if l.buf[l.bufpos + 1] in {'s', 'S'}:
         inc(l.bufpos, 2)
      else:
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
         tok.type = TkInvalid

      inc(l.bufpos)
   else:
      # If there's no base in the buffer, assume base 10.
      tok.base = Base10


# Forward declaration
proc handle_number(l: var Lexer, tok: var Token)

proc handle_real_and_decimal(l: var Lexer, tok: var Token) =
   # We're reading a base 10 number, but this may be the size field of a number
   # with another base. We also have to handle X- and Z-digits separately.
   tok.type = TkDecLit
   let c = l.buf[l.bufpos]
   if c in XChars + ZChars:
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
      of '.', 'e', 'E', '+', '-':
         tok.type = TkRealLit
         add(tok.literal, c)
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

   if tok.type == TkRealLit:
      tok.fnumber = parse_float(tok.literal)
   else:
      tok.inumber = parse_int(tok.literal)

proc handle_binary(l: var Lexer, tok: var Token) =
   discard


proc handle_octal(l: var Lexer, tok: var Token) =
   discard


proc handle_hex(l: var Lexer, tok: var Token) =
   discard


proc handle_number(l: var Lexer, tok: var Token) =
   # Attempt to read the base from the buffer.
   get_base(l, tok)

   case tok.base
   of Base2:
      handle_binary(l, tok)
   of Base8:
      handle_octal(l, tok)
   of Base16:
      handle_hex(l, tok)
   of Base10:
      handle_real_and_decimal(l, tok)


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
   of '/':
      handle_forward_slash(l, tok)
   of '=':
      handle_equals(l, tok)
   of '$':
      handle_dollar(l, tok)
   of '"':
      handle_literal(l, tok)
   of '\'', '0'..'9':
      handle_number(l, tok)
   else:
      if c in OpChars:
         handle_operator(l, tok)
      else:
         echo "Invalid token: '", c, "'"
         tok.type = TkInvalid
         inc(l.bufpos)


proc open_lexer*(l: var Lexer, filename: string, s: Stream) =
   lexbase.open(l, s)
   l.filename = filename
   l.cache = new_ident_cache()


proc close_lexer*(l: var Lexer) =
   lexbase.close(l)
