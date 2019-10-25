import lexbase
import streams


type
   TokenType* = enum
      Invalid
      EndOfFile
      Literal

   NumericalBase* = enum
      Base10, Base2, Base8, Base16

   TokenTypes* = set[TokenType]

   Token* = object
      `type`*: TokenType
      ident*: string # Identifier, may need its own type
      literal*: string # String literal, also comments
      inumber*: BiggestInt # Integer literal
      fnumber*: BiggestFloat # Floating point literal
      base*: NumericalBase # The numerical base
      line*, col*: int

   Lexer* = object of BaseLexer
      filename: string


proc init*(t: var Token) =
   t.type = Invalid
   set_len(t.ident, 0)
   set_len(t.literal, 0)
   t.inumber = 0
   t.fnumber = 0.0
   t.base = Base10
   t.line = 0
   t.col = 0


proc is_valid*(t: Token): bool =
   return t.type != Invalid


proc handle_crlf(l: var Lexer, pos: int): int =
   # Refill buffer at end-of-line characters.
   case l.buf[l.bufpos]
   of '\c':
      result = lexbase.handle_cr(l, pos)
   of '\L':
      result = lexbase.handle_lf(l, pos)
   else:
      result = pos


template update_token_position(l: Lexer, tok: var Token) =
   tok.col = get_col_number(l, l.bufpos)
   tok.line = l.lineNumber


proc get_token*(l: var Lexer, tok: var Token) =
   # Initialize the token
   init(tok)
   update_token_position(l, tok)

   let c = l.buf[l.bufpos]
   case c
   of lexbase.EndOfFile:
      tok.type = EndOfFile
   of lexbase.NewLines:
      l.bufpos = handle_crlf(l, l.bufpos)
   else:
      echo "Got '", c, "'"
      inc(l.bufpos)


proc open_lexer*(l: var Lexer, filename: string, s: Stream) =
   lexbase.open(l, s)
   l.filename = filename


proc close_lexer*(l: var Lexer) =
   lexbase.close(l)
