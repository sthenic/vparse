version = "0.1.0"
author = "Marcus Eriksson"
description = "A Verilog IEEE 1364-2005 lexer and parser."
src_dir = "src"
bin = @["vparse"]
install_ext = @["nim"]
license = "MIT"

skip_dirs = @["tests"]

requires "nim >= 1.2.4"
requires "nimpy >= 0.1.0"


task build_pylib, "Build the Python bindings":
   when defined(windows):
      exec("nim c --hints:off --threads:on --app:lib -d:lib -d:release --out:vparse.pyd src/vparse.nim")
   else:
      exec("nim c --hints:off --threads:on --app:lib -d:pylib --out:vparse.so src/vparse.nim")


task test, "Run the test suite":
   exec("nimble lexertests")
   exec("nimble preprocessortests")
   exec("nimble parsertests")


task lexertests, "Run the lexer test suite":
   with_dir("tests/lexer"):
      exec("nim c --hints:off -r tidentifier")
      exec("nim c --hints:off -r tlexer")


task preprocessortests, "Run the preprocessor test suite":
   with_dir("tests/preprocessor"):
      exec("nim c --hints:off -r tpreprocessor")


task parsertests, "Run the parser test suite":
   with_dir("tests/parser"):
      exec("nim c --hints:off -r tconstantexpression")
      exec("nim c --hints:off -r tportlist")
      exec("nim c --hints:off -r tportdeclarations")
      exec("nim c --hints:off -r tparameterportlist")
      exec("nim c --hints:off -r tvariabledeclaration")
      exec("nim c --hints:off -r teventdeclaration")
      exec("nim c --hints:off -r tblockingnonblockingassignment")
      exec("nim c --hints:off -r tnetdeclaration")
      exec("nim c --hints:off -r tdirective")
