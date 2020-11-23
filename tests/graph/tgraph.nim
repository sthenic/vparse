import terminal
import strformat
import strutils
import streams
import os

import ../../src/vparsepkg/graph


type TestException = object of ValueError

var nof_passed = 0
var nof_failed = 0
var g: Graph
var module_cache = new_module_cache()
var locations = new_locations()

proc new_test_exception(msg: string, args: varargs[string, `$`]): ref TestException =
   new result
   result.msg = format(msg, args)


template run_test(title, filename: string, include_paths: openarray[string], clear_cache: bool, body: untyped) =
   let identifier_cache = new_ident_cache()
   if clear_cache:
      module_cache = new_module_cache()
      locations = new_locations()
   g = new_graph(identifier_cache, module_cache, locations)
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

# Restore the file src/modb.v. We'll manipulate its contents in a bit.
let fs = new_file_stream("src/modb.v", fmWrite)
if is_nil(fs):
   echo "Failed to open file src/modb.v"
   quit(-1)

write(fs, """
module modB();

    modD();
    modC();

endmodule
""")
flush(fs)


run_test("Module discovery, all declarations in parent directory", "src/moda.v", [], true):
   if is_nil(g.root):
      raise new_test_exception("Root node is nil.")
   assert_module_exists(g, "modA")
   assert_module_exists(g, "modB")
   assert_module_exists(g, "modC")
   assert_module_exists(g, "modD")


run_test("Module discovery, declaration outside parent directory", "src/needs_includemod.v", ["src/include"], true):
   if is_nil(g.root):
      raise new_test_exception("Root node is nil.")
   assert_module_exists(g, "needs_includemod")
   assert_module_exists(g, "includemod")
   assert_module_doesnt_exist(g, "modA")
   assert_module_doesnt_exist(g, "modB")
   assert_module_doesnt_exist(g, "modC")
   assert_module_doesnt_exist(g, "modD")


run_test("Clean parse of modB", "src/modb.v", [], true):
   if g.module_cache.count != 3:
      raise new_test_exception("Cache contains $1 modules, expected $2.", g.module_cache.count, 4)
   assert_module_exists(g, "modB")
   assert_module_doesnt_exist(g, "foo")

set_position(fs, 0)
write(fs, """
module foo();

    modD();
    modC();

endmodule """)
close(fs)


run_test("Renamed modB -> foo, reparse", "src/modb.v", [], false):
   assert_module_exists(g, "foo")
   assert_module_doesnt_exist(g, "modB")


# Tests for the src2/ directory.
run_test("Include path filter: module graph A", "src2/a/a.v", ["src2/lib"], true):
   # Assert that we can reach modules: A, C, B, D, E but not F and G.
   assert_module_exists(g, "A")
   assert_module_exists(g, "C")
   assert_module_exists(g, "B")
   assert_module_exists(g, "D")
   assert_module_exists(g, "E")
   assert_module_doesnt_exist(g, "F")
   assert_module_doesnt_exist(g, "G")
   # Check the iterator.
   for module in walk_modules(g):
      if module.name in ["F", "G"]:
         raise new_test_exception("Unexpected iterator access to module '$1'.", module.name)


run_test("Include path filter: module graph F", "src2/f/f.v", ["src2/lib"], false):
   # Assert that we can reach modules: F, G, B, D, E but not A and C.
   assert_module_exists(g, "F")
   assert_module_exists(g, "G")
   assert_module_exists(g, "B")
   assert_module_exists(g, "D")
   assert_module_exists(g, "E")
   assert_module_doesnt_exist(g, "A")
   assert_module_doesnt_exist(g, "C")
   # Check the iterator.
   for module in walk_modules(g):
      if module.name in ["A", "C"]:
         raise new_test_exception("Unexpected iterator access to module '$1'.", module.name)


run_test("Include path filter: prepare module H", "src2/h.v", ["src2/**"], true):
   assert_module_exists(g, "H")


run_test("Include path filter w/ '**'", "src2/lib/b.v", ["src2/**"], false):
   # Check that we can reach module H from a module graph located in a
   # subdirectory as long as it's on the include path.
   assert_module_exists(g, "B")
   assert_module_exists(g, "D")
   assert_module_exists(g, "E")
   assert_module_exists(g, "H")


run_test("Walk Verilog files (iterator)", "src/moda.v", ["src/**", "src2/lib", "src2/**"], true):
   # Intentionally overlapping include paths. The iterator should only yield
   # once per unique file.
   var expected_paths = @[
      expand_filename("src/include/includemod.v"),
      expand_filename("src/moda.v"),
      expand_filename("src/modb.v"),
      expand_filename("src/modc.v"),
      expand_filename("src/modd.v"),
      expand_filename("src/needs_includemod.v"),
      expand_filename("src2/lib/b.v"),
      expand_filename("src2/lib/de.v"),
      expand_filename("src2/a/a.v"),
      expand_filename("src2/a/c.v"),
      expand_filename("src2/f/f.v"),
      expand_filename("src2/f/g.v"),
      expand_filename("src2/h.v")
   ]

   for path in walk_verilog_files(g.include_paths):
      if len(expected_paths) == 0:
         raise new_test_exception("Got '$1' but the list of expected paths is empty.", path)
      elif path notin expected_paths:
         raise new_test_exception("Got unexpected path '$1'.", path)
      else:
         del(expected_paths, find(expected_paths, path))

   if len(expected_paths) != 0:
      echo expected_paths
      raise new_test_exception("")


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
