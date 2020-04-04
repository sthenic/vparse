import ../../src/vparsepkg/lexer


template init(t: Token, k: TokenKind, line, col: int) =
   init(t)
   t.line = line
   t.col = col
   t.kind = k


proc new_token*(kind: TokenKind, line, col: int): Token =
   init(result, kind, line, col)


proc new_comment*(kind: TokenKind, line, col: int, comment: string): Token =
   init(result, kind, line, col)
   result.literal = comment


proc new_string_literal*(line, col: int, literal: string): Token =
   init(result, TkStrLit, line, col)
   result.literal = literal


proc new_fnumber*(kind: TokenKind, line, col: int, fnumber: float, literal: string): Token =
   init(result, kind, line, col)
   result.fnumber = fnumber
   result.base = Base10
   result.literal = literal


proc new_inumber*(kind: TokenKind, line, col: int, inumber: int,
                  base: NumericalBase, size: int, literal: string): Token =
   init(result, kind, line, col)
   result.inumber = inumber
   result.base = base
   result.size = size
   result.literal = literal


proc new_identifier*(kind: TokenKind, line, col: int, identifier: string,
                     cache: IdentifierCache): Token =
   init(result, kind, line, col)
   result.identifier = cache.get_identifier(identifier)


proc new_identifier*(kind: TokenKind, line, col: int,
                     identifier, literal: string, cache: IdentifierCache): Token =
   result = new_identifier(kind, line, col, identifier, cache)
   result.literal = literal
