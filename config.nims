task build, "Compile the application into an executable.":
   withDir("src"):
      exec("nim c -d:release --passC:-flto --passL:-s --gc:markAndSweep vparse")

   rmFile("vparse".toExe)
   mvFile("src/vparse".toExe, "vparse".toExe)
   setCommand "nop"


task tests, "Run the test suite":
   exec("nim lexertests")
   setCommand "nop"


task lexertests, "Run the lexer test suite":
   withDir("tests/lexer"):
      exec("nim c -r tlexer")
   setCommand "nop"


task debug, "Compile the application with debugging trace messages active":
   withDir("src"):
      exec("nim c vparse")

   rmFile("vparse".toExe)
   mvFile("src/vparse".toExe, "vparse".toExe)
   setCommand "nop"

