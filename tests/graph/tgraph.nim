import terminal
import strformat
import strutils
import streams

import ../../src/vparsepkg/graph


type TestException = object of ValueError

var nof_passed = 0
var nof_failed = 0
var g: Graph


proc new_test_exception(msg: string, args: varargs[string, `$`]): ref TestException =
   new result
   result.msg = format(msg, args)


template run_test(title, filename: string, include_paths: openarray[string], body: untyped) =
   let cache = new_ident_cache()
   g = new_graph(cache)
   let fs = new_file_stream(filename)
   if is_nil(fs):
      raise new_test_exception("Failed to open input file '$1'.", filename)
   discard parse(g, fs, filename, include_paths, [])
   try:
      body
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ", fgWhite, "Test '",  title, "'")
      nof_passed += 1
   except TestException as e:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ", fgWhite, "Test '",  title, "'")
      nof_failed += 1
      echo e.msg


template assert_module_exists(g: Graph, name: string) =
   if is_nil(get_module(g, name)):
      raise new_test_exception("AST missing or invalid: '$1'", name)


template assert_module_doesnt_exist(g: Graph, name: string) =
   if not is_nil(get_module(g, name)):
      raise new_test_exception("Module declaration present when it shouldn't be: '$1'", name)

# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: module graphs
-------------------------""")

run_test("Module discovery, all declarations in parent directory", "src/moda.v", []):
   if is_nil(g.root):
      raise new_test_exception("Root node is nil.")
   assert_module_exists(g, "modA")
   assert_module_exists(g, "modB")
   assert_module_exists(g, "modC")
   assert_module_exists(g, "modD")


run_test("Module discovery, declaration outside parent directory", "src/needs_includemod.v", ["src/include"]):
   if is_nil(g.root):
      raise new_test_exception("Root node is nil.")
   assert_module_exists(g, "needs_includemod")
   assert_module_exists(g, "includemod")
   assert_module_doesnt_exist(g, "modA")
   assert_module_doesnt_exist(g, "modB")
   assert_module_doesnt_exist(g, "modC")
   assert_module_doesnt_exist(g, "modD")


# Print summary
styledWriteLine(stdout, styleBright, "\n----- SUMMARY -----")
var test_str = "test"
if nof_passed == 1:
   test_str.add(' ')
else:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_passed:<4} ", test_str,
                fgGreen, " PASSED")

test_str = "test"
if nof_failed == 1:
   test_str.add(' ')
else:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_failed:<4} ", test_str,
                fgRed, " FAILED")

styledWriteLine(stdout, styleBright, "-------------------")

quit(nof_failed)
