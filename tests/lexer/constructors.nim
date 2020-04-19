import ../../src/vparsepkg/lexer


template init(t: Token, k: TokenKind, line: uint16, col: int16, file: int32 = 1) =
   init(t)
   t.kind = k
   t.loc = Location(file: file, line: line, col: col)


proc new_token*(kind: TokenKind, line: uint16, col: int16, file: int32 = 1): Token =
   init(result, kind, line, col, file)


proc new_comment*(kind: TokenKind, line: uint16, col: int16, comment: string,
                  file: int32 = 1): Token =
   init(result, kind, line, col, file)
   result.literal = comment


proc new_string_literal*(line: uint16, col: int16, literal: string, file: int32 = 1): Token =
   init(result, TkStrLit, line, col, file)
   result.literal = literal


proc new_fnumber*(kind: TokenKind, line: uint16, col: int16, fnumber: float, literal: string,
                  file: int32 = 1): Token =
   init(result, kind, line, col, file)
   result.fnumber = fnumber
   result.base = Base10
   result.literal = literal


proc new_inumber*(kind: TokenKind, line: uint16, col: int16, inumber: int,
                  base: NumericalBase, size: int, literal: string,
                  file: int32 = 1): Token =
   init(result, kind, line, col, file)
   result.inumber = inumber
   result.base = base
   result.size = size
   result.literal = literal


proc new_identifier*(kind: TokenKind, line: uint16, col: int16, identifier: string,
                     cache: IdentifierCache, file: int32 = 1): Token =
   init(result, kind, line, col, file)
   result.identifier = cache.get_identifier(identifier)


proc new_identifier*(kind: TokenKind, line: uint16, col: int16,
                     identifier, literal: string, cache: IdentifierCache,
                     file: int32 = 1): Token =
   result = new_identifier(kind, line, col, identifier, cache, file)
   result.literal = literal
