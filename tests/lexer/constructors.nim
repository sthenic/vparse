import ../../src/vparsepkg/lexer


template init(t: Token, k: TokenKind, loc: Location) =
   init(t)
   t.kind = k
   t.loc = loc


proc loc*(file: int32, line: uint16, col: int16): Location =
   result = Location(file: file, line: line, col: col)


template ni*(x: int): Int = new_int(x)
template ni*(s: string, base: cint = 10): Int = new_int(s, base)


proc new_token*(kind: TokenKind, loc: Location): Token =
   init(result, kind, loc)


proc new_comment*(kind: TokenKind, loc: Location, comment: string): Token =
   init(result, kind, loc)
   result.literal = comment


proc new_string_literal*(loc: Location, literal: string): Token =
   init(result, TkStrLit, loc)
   result.literal = literal


proc new_fnumber*(kind: TokenKind, loc: Location, fnumber: float, literal: string): Token =
   init(result, kind, loc)
   result.fnumber = fnumber
   result.base = Base10
   result.literal = literal


proc new_inumber*(kind: TokenKind, loc: Location, inumber: Int,
                  base: NumericalBase, size: int, literal: string): Token =
   init(result, kind, loc)
   result.inumber = inumber
   result.base = base
   result.size = size
   result.literal = literal


proc new_identifier*(kind: TokenKind, loc: Location, identifier: string,
                     cache: IdentifierCache): Token =
   init(result, kind, loc)
   result.identifier = cache.get_identifier(identifier)


proc new_identifier*(kind: TokenKind, loc: Location,
                     identifier, literal: string, cache: IdentifierCache): Token =
   result = new_identifier(kind, loc, identifier, cache)
   result.literal = literal
