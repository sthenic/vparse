import terminal
import strformat
import md5

include ../../src/vparsepkg/module
include ../../src/vparsepkg/parser

var nof_passed = 0
var nof_failed = 0
var passed = false
var cache: ModuleCache


template run_test(title: string, new_cache: bool, body: untyped) =
   passed = false

   if new_cache:
      cache = new_module_cache()

   body

   if passed:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: Modules
-------------------""")


# Run testcases
run_test("Initialize cache", true):
   passed = cache.count == 0


var identifier_cache = new_ident_cache()
var root: PNode = nil

const MODULES_AB = """
module module_a();
endmodule

module module_b();
endmodule
"""

const MODULES_CD = """
   module module_c(
      input wire clk_i
   );

   endmodule

   module module_d(
      output wire data_o
   );
   endmodule
"""


run_test("Add modules", false):
   root = parse_string(MODULES_AB, identifier_cache)
   add_source_file(cache, root, "test", to_md5(MODULES_AB))
   passed = cache.count == 2
   let module_a = get_module(cache, "module_a")
   passed = passed and (module_a.filename == "test")
   passed = passed and (module_a.n.loc == new_location(1, 1, 0))
   let module_b = get_module(cache, "module_b")
   passed = passed and (module_b.filename == "test")
   passed = passed and (module_b.n.loc == new_location(1, 4, 0))


run_test("Add modules from another file", false):
   root = parse_string(MODULES_CD, identifier_cache)
   add_source_file(cache, root, "test2", to_md5(MODULES_CD))
   passed = cache.count == 4
   let module_c = get_module(cache, "module_c")
   passed = passed and (module_c.filename == "test2")
   passed = passed and (module_c.n.loc == new_location(1, 1, 3))
   let module_d = get_module(cache, "module_d")
   passed = passed and (module_d.filename == "test2")
   passed = passed and (module_d.n.loc == new_location(1, 7, 3))


run_test("Remove module", false):
   remove_source_file(cache, "test")
   passed = cache.count == 2


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
