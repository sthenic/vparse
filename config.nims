task tests, "Run the test suite":
   exec("nim lexertests")
   exec("nim parsertests")
   setCommand "nop"


task lexertests, "Run the lexer test suite":
   withDir("tests/lexer"):
      exec("nim c -r tidentifier")
      exec("nim c -r tlexer")
   setCommand "nop"


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
   setCommand "nop"
