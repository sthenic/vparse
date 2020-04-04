version = "0.1.0"
author = "Marcus Eriksson"
description = "A Verilog IEEE 1364-2005 lexer and parser."
src_dir = "src"
bin = @["vparse"]
install_ext = @["nim"]
license = "MIT"

skip_dirs = @["tests"]

requires "nim >= 1.2.0"

task test, "Run the test suite":
   exec("nimble lexertests")
   exec("nimble parsertests")

task lexertests, "Run the lexer test suite":
   withDir("tests/lexer"):
      exec("nim c --hints:off -r tidentifier")
      exec("nim c --hints:off -r tlexer")

task parsertests, "Run the parser test suite":
   withDir("tests/parser"):
      exec("nim c --hints:off -r tconstantexpression")
      exec("nim c --hints:off -r tportlist")
      exec("nim c --hints:off -r tportdeclarations")
      exec("nim c --hints:off -r tparameterportlist")
      exec("nim c --hints:off -r tvariabledeclaration")
      exec("nim c --hints:off -r teventdeclaration")
      exec("nim c --hints:off -r tblockingnonblockingassignment")
      exec("nim c --hints:off -r tnetdeclaration")