version = "0.2.2"
author = "Marcus Eriksson"
description = "A Verilog IEEE 1364-2005 parser library."
src_dir = "src"
bin = @["vparse"]
install_ext = @["nim"]
license = "MIT"

skip_dirs = @["tests"]

requires "nim >= 1.4.0"
requires "nimpy >= 0.1.0"
requires "bignum >= 1.0.4"


task tracebuild, "":
   exec("nim c --hints:off -d:danger -d:trace --gc:orc src/vparse")
   mv_file("src/vparse".to_exe, "vparse".to_exe)


task build_pylib, "Build the Python bindings":
   when defined(windows):
      exec("nim c --hints:off --threads:on --app:lib -d:pylib -d:release --out:vparse.pyd src/vparse.nim")
   else:
      exec("nim c --hints:off --threads:on --app:lib -d:pylib --out:vparse.so src/vparse.nim")


task test, "Run the test suite":
   exec("nimble lexertests")
   exec("nimble preprocessortests")
   exec("nimble parsertests")
   exec("nimble asttests")
   exec("nimble expressiontests")
   exec("nimble graphtests")


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
      exec("nim c --hints:off -r thierarchicalidentifier")


task asttests, "Run the AST test suite":
   with_dir("tests/ast"):
      exec("nim c --hints:off -r tast")
      exec("nim c --hints:off -r tastop")


task expressiontests, "Run the expression test suite":
   with_dir("tests/expression"):
      exec("nim c --hints:off -r texpressioneval")
      exec("nim c --hints:off -r texpressionkindsize")


task graphtests, "Run the graph test suite":
   with_dir("tests/graph"):
      exec("nim c --hints:off -r tgraph")
