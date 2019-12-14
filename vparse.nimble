version = "0.1.0"
author = "Marcus Eriksson"
description = "A Verilog IEEE 1364-2005 lexer and parser."
license = "MIT"

skip_dirs = @["tests"]

requires "nim >= 1.0.0"

task tests, "Run the test suite":
   exec("nim lexertests")
   exec("nim parsertests")

task lexertests, "Run the lexer test suite":
   withDir("tests/lexer"):
      exec("nim c -r tidentifier")
      exec("nim c -r tlexer")

task parsertests, "Run the parser test suite":
   withDir("tests/parser"):
      exec("nim c -r tconstantexpression")
      exec("nim c -r tportlist")
      exec("nim c -r tportdeclarations")
      exec("nim c -r tparameterportlist")
      exec("nim c -r tvariabledeclaration")
      exec("nim c -r teventdeclaration")
      exec("nim c -r tblockingnonblockingassignment")
      exec("nim c -r tnetdeclaration")
