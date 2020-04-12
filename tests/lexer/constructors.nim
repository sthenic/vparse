import ../../src/vparsepkg/lexer


template init(t: Token, k: TokenKind, line, col: int, file_index: int = 0) =
   init(t)
   t.line = line
   t.col = col
   t.kind = k
   t.file_index = file_index


proc new_token*(kind: TokenKind, line, col: int, file_index: int = 0): Token =
   init(result, kind, line, col, file_index)


proc new_comment*(kind: TokenKind, line, col: int, comment: string,
                  file_index: int = 0): Token =
   init(result, kind, line, col, file_index)
   result.literal = comment


proc new_string_literal*(line, col: int, literal: string, file_index: int = 0): Token =
   init(result, TkStrLit, line, col, file_index)
   result.literal = literal


proc new_fnumber*(kind: TokenKind, line, col: int, fnumber: float, literal: string,
                  file_index: int = 0): Token =
   init(result, kind, line, col, file_index)
   result.fnumber = fnumber
   result.base = Base10
   result.literal = literal


proc new_inumber*(kind: TokenKind, line, col: int, inumber: int,
                  base: NumericalBase, size: int, literal: string,
                  file_index: int = 0): Token =
   init(result, kind, line, col, file_index)
   result.inumber = inumber
   result.base = base
   result.size = size
   result.literal = literal


proc new_identifier*(kind: TokenKind, line, col: int, identifier: string,
                     cache: IdentifierCache, file_index: int = 0): Token =
   init(result, kind, line, col, file_index)
   result.identifier = cache.get_identifier(identifier)


proc new_identifier*(kind: TokenKind, line, col: int,
                     identifier, literal: string, cache: IdentifierCache,
                     file_index: int = 0): Token =
   result = new_identifier(kind, line, col, identifier, cache, file_index)
   result.literal = literal
