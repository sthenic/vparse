# import algorithm
import terminal
import strformat

include ../../src/lexer/identifier
include ../../src/lexer/special_words

var
   passed = false
   nof_passed = 0
   nof_failed = 0
   msg = ""
   nof_identifiers = 0
   identifier: PIdentifier = nil
   identifier_cache: IdentifierCache


proc initialize_cache() =
   identifier_cache = new_ident_cache()


template run_test(title: string, new_cache: bool, body: untyped) =
   passed = false
   set_len(msg, 0)

   if new_cache:
      initialize_cache()

   body

   if passed:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   else:
      var tail = ""
      if len(msg) > 0:
         tail = " failed:"
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'" & tail)
      if len(msg) > 0:
         echo "    " & msg
      nof_failed += 1


# Run testcases
run_test("Initialize cache", true):
   passed = identifier_cache.nof_identifiers == len(SpecialWords)


# Check that the protected keyword get placed in the first buckets.
for i, word in SpecialWords:
   if i == 0:
      continue
   run_test("Keyword: " & word & "", false):
      # Add the keyword and check that the number of identifiers don't change.
      passed = identifier_cache.get_identifier(word).id < len(SpecialWords)


run_test("New identifier", true):
   nof_identifiers = identifier_cache.nof_identifiers
   identifier = identifier_cache.get_identifier("foo")
   passed = identifier_cache.nof_identifiers == nof_identifiers + 1


run_test("Identifier lookup", false):
   nof_identifiers = identifier_cache.nof_identifiers
   passed = identifier == identifier_cache.get_identifier("foo") and
            nof_identifiers == identifier_cache.nof_identifiers


run_test("Alternate case identifier", false):
   nof_identifiers = identifier_cache.nof_identifiers
   passed = identifier != identifier_cache.get_identifier("Foo") and
            nof_identifiers != identifier_cache.nof_identifiers


run_test("Escaped identifier", false):
   nof_identifiers = identifier_cache.nof_identifiers
   identifier = identifier_cache.get_identifier("\nfoo")
   passed = identifier_cache.nof_identifiers == nof_identifiers + 1


run_test("Escaped identifier lookup", false):
   passed = identifier == identifier_cache.get_identifier("\nfoo")


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
